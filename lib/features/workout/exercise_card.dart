import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/logged_set.dart';
import '../../domain/one_rep_max.dart';
import '../../domain/personal_records.dart';
import 'rest_timer_controller.dart';
import 'set_input.dart';
import 'workout_providers.dart';

/// One exercise of the active workout: logged sets plus the quick entry row.
class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({super.key, required this.entry, this.nextExerciseName});

  final WorkoutEntry entry;
  final String? nextExerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slot = entry.slot;
    final args = (exerciseId: slot.exerciseId, workoutId: slot.workoutId);
    final previousAsync = ref.watch(previousSetsProvider(args));
    final previous = previousAsync.value ?? const [];
    final records = ref.watch(recordsBeforeProvider(args));
    final prs = _prsPerSet(records);

    final sets = entry.sets;
    final last = sets.lastOrNull;
    final prevForNext = previous.elementAtOrNull(sets.length) ?? previous.lastOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MuscleBadge(entry.exercise.muscleGroup, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.exercise.name, style: theme.textTheme.titleMedium),
                      Text(
                        '${sets.length}/${slot.targetSets} sets · ${slot.targetReps} reps · '
                        '${formatClock(Duration(seconds: slot.restSeconds))} rest',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'remove' &&
                        await confirm(
                          context,
                          title: 'Remove ${entry.exercise.name}?',
                          message: 'Its sets will be removed from this workout.',
                          action: 'Remove',
                        )) {
                      await ref.read(workoutRepositoryProvider).removeExercise(slot.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove exercise')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (sets.isNotEmpty || previous.isNotEmpty) const _Header(),
            for (final (i, set) in sets.indexed)
              _LoggedSetRow(
                set: set,
                number: i + 1,
                previous: previous.elementAtOrNull(i),
                prs: prs[i] ?? const {},
              ),
            SetInputRow(
              // Rebuilt once the previous session is loaded so it can prefill.
              key: ValueKey('${slot.id}-${sets.length}-${previousAsync.hasValue}'),
              setNumber: sets.length + 1,
              initialWeight: last?.weight ?? prevForNext?.weight,
              initialReps: last?.reps ?? prevForNext?.reps ?? slot.targetReps,
              initialRpe: last?.rpe,
              hint: prevForNext == null ? null : formatWeight(prevForNext.weight, unit: false),
              onLog: (weight, reps, rpe) async {
                await ref
                    .read(workoutRepositoryProvider)
                    .logSet(slot, weight: weight, reps: reps, rpe: rpe);
                final done = sets.length + 1 >= slot.targetSets;
                await ref
                    .read(restTimerProvider.notifier)
                    .start(
                      Duration(seconds: slot.restSeconds),
                      nextUp: done
                          ? nextExerciseName
                          : '${entry.exercise.name} · set ${sets.length + 2}',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<int, Set<PrType>> _prsPerSet(PersonalRecords before) {
    var records = before;
    final result = <int, Set<PrType>>{};
    for (final (i, s) in entry.sets.indexed) {
      final logged = LoggedSet(
        weight: s.weight,
        reps: s.reps,
        rpe: s.rpe,
        date: s.completedAt,
        workoutId: s.workoutId,
      );
      if (!before.isEmpty) {
        final broken = records.brokenBy(logged);
        if (broken.isNotEmpty) result[i] = broken;
      }
      records = records.add(logged);
    }
    return result;
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: SetColumns.index,
            child: Text('SET', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: Text('PREV', style: style)),
          Expanded(flex: 3, child: Text('KG × REPS', style: style)),
          SizedBox(
            width: SetColumns.rpe,
            child: Text('RPE', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: SetColumns.action),
        ],
      ),
    );
  }
}

class _LoggedSetRow extends ConsumerWidget {
  const _LoggedSetRow({
    required this.set,
    required this.number,
    required this.previous,
    required this.prs,
  });

  final WorkoutSet set;
  final int number;
  final WorkoutSet? previous;
  final Set<PrType> prs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: tabular,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => EditSetSheet(set: set),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: SetColumns.index,
              child: Text(
                '$number',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: Text(
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                previous == null
                    ? '—'
                    : '${formatWeight(previous!.weight, unit: false)}×${previous!.reps}',
                style: muted,
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${formatWeight(set.weight, unit: false)} × ${set.reps}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular),
                    ),
                  ),
                  if (prs.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Personal record',
                      child: Icon(Icons.emoji_events, size: 18, color: Colors.amber.shade600),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: SetColumns.rpe,
              child: Text(
                formatRpe(set.rpe).isEmpty ? '–' : formatRpe(set.rpe),
                textAlign: TextAlign.center,
                style: muted,
              ),
            ),
            SizedBox(
              width: SetColumns.action,
              child: Icon(Icons.check_circle_rounded, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class EditSetSheet extends ConsumerStatefulWidget {
  const EditSetSheet({super.key, required this.set});

  final WorkoutSet set;

  @override
  ConsumerState<EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends ConsumerState<EditSetSheet> {
  late final _weight = TextEditingController(text: formatWeight(widget.set.weight, unit: false));
  late final _reps = TextEditingController(text: '${widget.set.reps}');
  late double? _rpe = widget.set.rpe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = parseWeight(_weight.text) ?? 0;
    final reps = int.tryParse(_reps.text) ?? 0;
    final e1rm = OneRepMax.estimate(weight, reps, rpe: _rpe);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit set', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('RPE', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in [null, ...rpeValues])
                ChoiceChip(
                  label: Text(v == null ? '–' : formatRpe(v)),
                  selected: _rpe == v,
                  onSelected: (_) => setState(() => _rpe = v),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Estimated 1RM: ${formatEstimate(e1rm)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(workoutRepositoryProvider).deleteSet(widget.set.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: reps > 0
                      ? () async {
                          await ref
                              .read(workoutRepositoryProvider)
                              .updateSet(widget.set.id, weight: weight, reps: reps, rpe: _rpe);
                          if (context.mounted) Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
