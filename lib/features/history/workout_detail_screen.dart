import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/logged_set.dart';
import '../../domain/one_rep_max.dart';
import '../../domain/personal_records.dart';
import '../workout/workout_providers.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId, this.justFinished = false});

  final String workoutId;
  final bool justFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId)).value;
    final history = ref.watch(allHistoryProvider).value ?? const {};
    final theme = Theme.of(context);
    if (detail == null) return const Scaffold(body: SizedBox.shrink());

    final prsByExercise = {
      for (final entry in detail.entries)
        entry.exercise.id: PersonalRecords.forWorkout(
          history[entry.exercise.id] ?? const <LoggedSet>[],
          workoutId,
        ),
    };
    final prCount = prsByExercise.values.fold(0, (sum, m) => sum + m.length);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(justFinished ? 'Workout complete' : detail.workout.name),
        actions: [
          if (!justFinished)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(
                  context,
                  title: 'Delete workout?',
                  message: 'This cannot be undone.',
                )) {
                  await ref.read(workoutRepositoryProvider).delete(workoutId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (justFinished) _Celebration(name: detail.workout.name, prCount: prCount),
          if (!justFinished)
            Text(
              '${formatDay(detail.workout.startedAt)} · ${TimeOfDay.fromDateTime(detail.workout.startedAt).format(context)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Duration',
                  value: formatDuration(detail.duration(now)),
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Volume',
                  value: formatVolume(detail.volume),
                  icon: Icons.bar_chart_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Sets',
                  value: '${detail.setCount}',
                  icon: Icons.layers_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Records',
                  value: '$prCount',
                  icon: Icons.emoji_events_outlined,
                  highlight: prCount > 0,
                ),
              ),
            ],
          ),
          for (final entry in detail.entries)
            if (entry.sets.isNotEmpty)
              _EntrySummary(
                entry: entry,
                prs: prsByExercise[entry.exercise.id]!,
                history: history[entry.exercise.id] ?? const [],
              ),
          if (justFinished) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ],
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.name, required this.prCount});

  final String name;
  final int prCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, const Color(0xFFFFB300), 0.55)!],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, size: 44, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  prCount == 0
                      ? 'Session saved. Consistency builds strength.'
                      : 'You set $prCount new personal record${prCount == 1 ? '' : 's'}!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntrySummary extends StatelessWidget {
  const _EntrySummary({required this.entry, required this.prs, required this.history});

  final WorkoutEntry entry;
  final Map<int, Set<PrType>> prs;
  final List<LoggedSet> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prTypesBySetId = {
      for (final MapEntry(:key, :value) in prs.entries) history[key].id: value,
    };
    final best = entry.sets
        .map((s) => OneRepMax.estimate(s.weight, s.reps, rpe: s.rpe))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MuscleBadge(entry.exercise.muscleGroup, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.exercise.name, style: theme.textTheme.titleMedium)),
                  Text(
                    'e1RM ${formatEstimate(best)}',
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final (i, s) in entry.sets.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: '${formatWeight(s.weight)} × ${s.reps}',
                            children: [
                              if (s.rpe != null)
                                TextSpan(
                                  text: '  @ ${formatRpe(s.rpe)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontFeatures: tabular,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (prTypesBySetId[s.id] case final types?)
                        PrChip(
                          label: types.contains(PrType.estimatedOneRepMax)
                              ? 'e1RM PR'
                              : types.first.label,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
