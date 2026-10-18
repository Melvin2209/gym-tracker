import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/workout_repository.dart';
import '../../services/sync/sync_controller.dart';
import '../exercises/exercise_picker.dart';
import '../history/workout_detail_screen.dart';
import 'exercise_card.dart';
import 'rest_timer_bar.dart';
import 'rest_timer_controller.dart';
import 'workout_providers.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    return detail.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (detail) => detail == null
          ? const Scaffold(body: SizedBox.shrink())
          : _ActiveWorkoutView(detail: detail),
    );
  }
}

class _ActiveWorkoutView extends ConsumerWidget {
  const _ActiveWorkoutView({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workout = detail.workout;
    final entries = detail.entries;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final name = await showTextPrompt(
              context,
              title: 'Rename workout',
              initial: workout.name,
            );
            if (name != null) await ref.read(workoutRepositoryProvider).rename(workout.id, name);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workout.name),
              _ElapsedText(startedAt: workout.startedAt),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'discard' &&
                  await confirm(
                    context,
                    title: 'Discard workout?',
                    message: 'All sets logged in this workout will be lost.',
                    action: 'Discard',
                  )) {
                await ref.read(restTimerProvider.notifier).skip();
                await ref.read(workoutRepositoryProvider).delete(workout.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('finish-workout'),
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: detail.setCount == 0 ? null : () => _finish(context, ref),
              child: const Text('Finish'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
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
                  label: 'Volume',
                  value: formatVolume(detail.volume),
                  icon: Icons.bar_chart_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Exercises',
                  value: '${entries.where((e) => e.sets.isNotEmpty).length}/${entries.length}',
                  icon: Icons.fitness_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: EmptyState(
                icon: Icons.add_circle_outline,
                title: 'Empty workout',
                message: 'Add your first exercise to start logging sets.',
              ),
            ),
          for (final (i, entry) in entries.indexed) ...[
            ExerciseCard(
              key: ValueKey(entry.slot.id),
              entry: entry,
              nextExerciseName: entries.elementAtOrNull(i + 1)?.exercise.name,
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            key: const Key('add-exercise'),
            onPressed: () async {
              final exercise = await pickExercise(context);
              if (exercise == null) return;
              final rest = ref.read(settingsProvider).value?.defaultRestSeconds ?? 120;
              await ref
                  .read(workoutRepositoryProvider)
                  .addExercise(workout.id, exercise.id, restSeconds: rest);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: tap a logged set to edit it. Weights are prefilled from your last session.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      bottomNavigationBar: const RestTimerBar(),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final pending = detail.entries.where((e) => e.sets.isEmpty).length;
    final ok = await confirm(
      context,
      title: 'Finish workout?',
      message: pending == 0
          ? 'Great session! It will be saved to your history.'
          : '$pending exercise${pending == 1 ? '' : 's'} without sets will be skipped.',
      action: 'Finish',
    );
    if (!ok) return;
    await ref.read(restTimerProvider.notifier).skip();
    await ref.read(workoutRepositoryProvider).finish(detail.workout.id);
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    if (context.mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => WorkoutDetailScreen(workoutId: detail.workout.id, justFinished: true),
        ),
      );
    }
  }
}

class _ElapsedText extends ConsumerStatefulWidget {
  const _ElapsedText({required this.startedAt});

  final DateTime startedAt;

  @override
  ConsumerState<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends ConsumerState<_ElapsedText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = ref.read(clockProvider)().difference(widget.startedAt);
    return Text(
      formatClock(elapsed.isNegative ? Duration.zero : elapsed),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
