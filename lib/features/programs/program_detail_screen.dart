import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/program_repository.dart';
import '../exercises/exercise_picker.dart';
import '../workout/train_screen.dart';
import '../workout/workout_providers.dart';

final _programProvider = StreamProvider.autoDispose.family<ProgramDetail?, String>(
  (ref, id) => ref.watch(programRepositoryProvider).watchProgram(id),
);

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_programProvider(programId)).value;
    final repo = ref.read(programRepositoryProvider);
    if (detail == null) return const Scaffold(body: SizedBox.shrink());
    final program = detail.program;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'rename':
                  final name = await showTextPrompt(
                    context,
                    title: 'Rename program',
                    initial: program.name,
                  );
                  if (name != null) await repo.updateProgram(program.id, name: name);
                case 'describe':
                  final text = await showTextPrompt(
                    context,
                    title: 'Description',
                    initial: program.description,
                  );
                  if (text != null) await repo.updateProgram(program.id, description: text);
                case 'delete':
                  if (await confirm(
                    context,
                    title: 'Delete ${program.name}?',
                    message: 'Your workout history is kept.',
                  )) {
                    await repo.deleteProgram(program.id);
                    if (context.mounted) Navigator.pop(context);
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'describe', child: Text('Edit description')),
              PopupMenuItem(value: 'delete', child: Text('Delete program')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-day',
        onPressed: () async {
          final name = await showTextPrompt(
            context,
            title: 'New day',
            hint: 'e.g. Upper A',
            action: 'Add',
          );
          if (name != null) await repo.addDay(program.id, name);
        },
        icon: const Icon(Icons.add),
        label: const Text('Day'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (program.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                program.description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          if (detail.days.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.view_day_outlined,
                title: 'No training days',
                message: 'Add a day, then the exercises you perform on it.',
              ),
            ),
          for (final day in detail.days) ...[_DayCard(day: day), const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.day});

  final ProgramDayDetail day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(programRepositoryProvider);
    final active = ref.watch(activeWorkoutProvider).value;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text(day.day.name, style: theme.textTheme.titleLarge)),
                if (active == null && day.exercises.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final id = await ref
                          .read(workoutRepositoryProvider)
                          .start(programDayId: day.day.id);
                      if (context.mounted) await openWorkout(context, id);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'rename') {
                      final name = await showTextPrompt(
                        context,
                        title: 'Rename day',
                        initial: day.day.name,
                      );
                      if (name != null) await repo.renameDay(day.day.id, name);
                    } else if (action == 'delete' &&
                        await confirm(
                          context,
                          title: 'Delete ${day.day.name}?',
                          message: 'Its exercises will be removed.',
                        )) {
                      await repo.deleteDay(day.day.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete day')),
                  ],
                ),
              ],
            ),
          ),
          for (final (i, e) in day.exercises.indexed)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              leading: MuscleBadge(e.exercise.muscleGroup, size: 36),
              title: Text(e.exercise.name),
              subtitle: Text(
                '${e.item.targetSets} × ${e.item.targetReps} · ${formatClock(Duration(seconds: e.item.restSeconds))} rest',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move up',
                    visualDensity: VisualDensity.compact,
                    onPressed: i == 0 ? null : () => repo.moveExercise(day.day.id, e.item.id, -1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    visualDensity: VisualDensity.compact,
                    onPressed: i == day.exercises.length - 1
                        ? null
                        : () => repo.moveExercise(day.day.id, e.item.id, 1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => _TargetSheet(item: e.item, exercise: e.exercise),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                final exercise = await pickExercise(context);
                if (exercise == null) return;
                final rest = ref.read(settingsProvider).value?.defaultRestSeconds ?? 120;
                await repo.addExercise(day.day.id, exercise.id, restSeconds: rest);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet({required this.item, required this.exercise});

  final ProgramExercise item;
  final Exercise exercise;

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  late int _sets = widget.item.targetSets;
  late int _reps = widget.item.targetReps;
  late int _rest = widget.item.restSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.read(programRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.exercise.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _Stepper(
            label: 'Sets',
            value: '$_sets',
            onChanged: (d) => setState(() => _sets = (_sets + d).clamp(1, 20)),
          ),
          _Stepper(
            label: 'Reps',
            value: '$_reps',
            onChanged: (d) => setState(() => _reps = (_reps + d).clamp(1, 100)),
          ),
          _Stepper(
            label: 'Rest',
            value: formatClock(Duration(seconds: _rest)),
            onChanged: (d) => setState(() => _rest = (_rest + d * 15).clamp(0, 900)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await repo.removeExercise(widget.item.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await repo.updateExercise(
                      widget.item.id,
                      sets: _sets,
                      reps: _reps,
                      restSeconds: _rest,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
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

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
          IconButton.outlined(onPressed: () => onChanged(-1), icon: const Icon(Icons.remove)),
          SizedBox(
            width: 72,
            child: Text(value, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          ),
          IconButton.outlined(onPressed: () => onChanged(1), icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}
