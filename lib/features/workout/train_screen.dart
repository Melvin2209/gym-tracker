import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/program_repository.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'active_workout_screen.dart';
import 'workout_providers.dart';

/// Home tab: resume or start a workout.
class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = ref.watch(activeWorkoutProvider).value;
    final programs = ref.watch(programsProvider).value ?? const [];
    final history = ref.watch(workoutHistoryProvider).value ?? const [];
    final stats = ref.watch(weeklyStatsProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDay(now).toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(_greeting(now), style: theme.textTheme.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _WeekCard(workouts: stats.workouts, sets: stats.sets, volume: stats.volume),
          const SizedBox(height: 16),
          if (active != null)
            _ActiveCard(workout: active)
          else
            FilledButton.icon(
              key: const Key('start-empty'),
              onPressed: () => _start(context, ref),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start empty workout'),
            ),
          if (active == null && programs.isNotEmpty) ...[
            const SectionHeader('Start from a program'),
            for (final program in programs)
              if (program.days.isNotEmpty) ...[
                _ProgramDays(
                  program: program,
                  onStart: (day) => _start(context, ref, day: day),
                ),
                const SizedBox(height: 12),
              ],
          ],
          if (history.isNotEmpty) ...[
            const SectionHeader('Last workout'),
            WorkoutSummaryCard(summary: history.first),
          ],
        ],
      ),
    );
  }

  static String _greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  Future<void> _start(BuildContext context, WidgetRef ref, {ProgramDay? day}) async {
    final id = await ref.read(workoutRepositoryProvider).start(programDayId: day?.id);
    if (context.mounted) await openWorkout(context, id);
  }
}

Future<void> openWorkout(BuildContext context, String workoutId) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => ActiveWorkoutScreen(workoutId: workoutId)),
);

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.workouts, required this.sets, required this.volume});

  final int workouts;
  final int sets;
  final double volume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onGradient = Colors.white.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, const Color(0xFFB0186B), 0.5)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: theme.textTheme.labelMedium?.copyWith(
              color: onGradient,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BigNumber(value: '$workouts', label: workouts == 1 ? 'workout' : 'workouts'),
              _BigNumber(value: '$sets', label: 'sets'),
              _BigNumber(value: formatVolume(volume), label: 'volume'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigNumber extends StatelessWidget {
  const _BigNumber({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = ref.watch(workoutDetailProvider(workout.id)).value;
    final elapsed = ref.watch(clockProvider)().difference(workout.startedAt);
    return Card(
      color: scheme.primary.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () => openWorkout(context, workout.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In progress · ${workout.name}', style: theme.textTheme.titleMedium),
                    Text(
                      '${formatDuration(elapsed)} · ${detail?.setCount ?? 0} sets logged',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                onPressed: () => openWorkout(context, workout.id),
                child: const Text('Resume'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramDays extends StatelessWidget {
  const _ProgramDays({required this.program, required this.onStart});

  final ProgramDetail program;
  final ValueChanged<ProgramDay> onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(program.program.name, style: theme.textTheme.titleMedium),
          ),
          for (final day in program.days)
            ListTile(
              key: Key('start-day-${day.day.id}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(day.day.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                day.exercises.map((e) => e.exercise.name).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton.filledTonal(
                tooltip: 'Start ${day.day.name}',
                onPressed: day.exercises.isEmpty ? null : () => onStart(day.day),
                icon: Icon(Icons.play_arrow_rounded, color: scheme.primary),
              ),
              onTap: day.exercises.isEmpty ? null : () => onStart(day.day),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
