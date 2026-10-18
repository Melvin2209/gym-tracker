import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/one_rep_max.dart';
import '../../domain/personal_records.dart';
import '../../domain/progression.dart';
import '../workout/workout_providers.dart';
import 'progress_chart.dart';

final _exerciseProvider = StreamProvider.autoDispose.family(
  (ref, String id) => ref.watch(exerciseRepositoryProvider).watch(id),
);

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  ProgressMetric _metric = ProgressMetric.estimatedOneRepMax;

  @override
  Widget build(BuildContext context) {
    final exercise = ref.watch(_exerciseProvider(widget.exerciseId)).value;
    final sets = ref.watch(exerciseHistoryProvider(widget.exerciseId)).value ?? const [];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (exercise == null) return const Scaffold(body: SizedBox.shrink());

    final sessions = Progression.sessions(sets);
    final records = PersonalRecords.fromSets(sets);
    final trend = Progression.trend(sessions, _metric);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          if (exercise.isCustom)
            IconButton(
              tooltip: 'Delete exercise',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(
                  context,
                  title: 'Delete ${exercise.name}?',
                  message: 'Past workouts keep their sets.',
                )) {
                  await ref.read(exerciseRepositoryProvider).delete(exercise.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        key: const Key('exercise-detail-list'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              MuscleBadge(exercise.muscleGroup, size: 28),
              const SizedBox(width: 8),
              Text(
                '${exercise.muscleGroup.label} · ${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.show_chart,
                title: 'No data yet',
                message: 'Log this exercise in a workout to track its progress.',
              ),
            )
          else ...[
            const SectionHeader('Personal records'),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Est. 1RM',
                    value: formatEstimate(records.bestE1rm!.value),
                    icon: Icons.emoji_events_outlined,
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Heaviest',
                    value: '${formatWeight(records.heaviest!.weight)} × ${records.heaviest!.reps}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Best set',
                    value: formatVolume(records.bestVolumeSet!.volume),
                  ),
                ),
              ],
            ),
            SectionHeader(
              'Progression',
              trailing: trend == null
                  ? null
                  : Text(
                      '${trend >= 0 ? '+' : ''}${(trend * 100).toStringAsFixed(1)}% in 4 weeks',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: trend >= 0 ? const Color(0xFF2EB872) : scheme.error,
                      ),
                    ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 8),
                      child: SegmentedButton<ProgressMetric>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          for (final m in ProgressMetric.values)
                            ButtonSegment(value: m, label: Text(m.label)),
                        ],
                        selected: {_metric},
                        onSelectionChanged: (s) => setState(() => _metric = s.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ProgressChart(sessions: sessions, metric: _metric),
                  ],
                ),
              ),
            ),
            const SectionHeader('Rep maxes'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final reps in [1, 3, 5, 8, 10, 12])
                      _TableRow(
                        left: '$reps RM',
                        middle: records.repMaxes[reps] == null
                            ? '—'
                            : formatWeight(records.repMaxes[reps]!.weight),
                        right:
                            'est. ${formatWeight(_round(OneRepMax.weightForReps(records.bestE1rm!.value, reps)))}',
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Estimates use the Epley formula. Sets logged with an RPE count the reps you had left '
                '(e.g. 5 reps @ RPE 8 ≈ a 7-rep max).',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SectionHeader('Recent sessions'),
            for (final s in sessions.reversed.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(formatDay(s.date)),
                    subtitle: Text(
                      s.sets
                          .map((x) => '${formatWeight(x.weight, unit: false)}×${x.reps}')
                          .join('  '),
                      style: const TextStyle(fontFeatures: tabular),
                    ),
                    trailing: Text(
                      formatEstimate(s.bestE1rm),
                      style: theme.textTheme.titleSmall?.copyWith(fontFeatures: tabular),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Rounds to the nearest 2.5 kg, the smallest common plate jump.
  static double _round(double kg) => (kg / 2.5).round() * 2.5;
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.left, required this.middle, required this.right});

  final String left;
  final String middle;
  final String right;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(left, style: theme.textTheme.titleSmall)),
          Expanded(
            child: Text(middle, style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: tabular)),
          ),
          Text(
            right,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
