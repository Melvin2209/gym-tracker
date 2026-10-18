import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets/common.dart';
import '../../data/db/app_database.dart';
import '../../domain/logged_set.dart';
import '../../domain/personal_records.dart';
import '../../domain/progression.dart';
import '../exercises/exercise_picker.dart';
import '../workout/workout_providers.dart';
import 'exercise_detail_screen.dart';
import 'progress_chart.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _query = '';
  MuscleGroup? _group;

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final history = ref.watch(allHistoryProvider).value ?? const {};
    final theme = Theme.of(context);

    final matching = exercises.where(
      (e) =>
          e.name.toLowerCase().contains(_query.toLowerCase()) &&
          (_group == null || e.muscleGroup == _group),
    );
    final trained = [
      for (final e in matching)
        if (history[e.id]?.isNotEmpty ?? false) (exercise: e, sets: history[e.id]!),
    ]..sort((a, b) => _lastDate(b.sets).compareTo(_lastDate(a.sets)));
    final untrained = [
      for (final e in matching)
        if (history[e.id]?.isEmpty ?? true) e,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'New exercise',
            icon: const Icon(Icons.add),
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => const CreateExerciseDialog()),
          ),
        ],
      ),
      body: CustomScrollView(
        key: const Key('progress-list'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search exercises',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final g in [null, ...MuscleGroup.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g?.label ?? 'All'),
                        selected: _group == g,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trained.isEmpty && _query.isEmpty && _group == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.show_chart,
                  title: 'Your progress lives here',
                  message: 'Finish a workout to see charts, estimated 1RM and personal records per exercise.',
                ),
              ),
            ),
          if (trained.isNotEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: SectionHeader('Trained')),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: trained.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _TrainedTile(exercise: trained[i].exercise, sets: trained[i].sets),
            ),
          ),
          if (untrained.isNotEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: SectionHeader('Library')),
            ),
          SliverList.builder(
            itemCount: untrained.length,
            itemBuilder: (context, i) {
              final e = untrained[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: MuscleBadge(e.muscleGroup, size: 36),
                title: Text(e.name),
                subtitle: Text(e.muscleGroup.label),
                trailing: Text('Not trained yet', style: theme.textTheme.labelSmall),
                onTap: () => _open(context, e.id),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  static DateTime _lastDate(List<LoggedSet> sets) =>
      sets.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);
}

void _open(BuildContext context, String id) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => ExerciseDetailScreen(exerciseId: id)),
);

class _TrainedTile extends StatelessWidget {
  const _TrainedTile({required this.exercise, required this.sets});

  final Exercise exercise;
  final List<LoggedSet> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sessions = Progression.sessions(sets);
    final records = PersonalRecords.fromSets(sets);
    final trend = Progression.trend(sessions, ProgressMetric.estimatedOneRepMax);
    final recent = sessions.length > 8 ? sessions.sublist(sessions.length - 8) : sessions;

    return Card(
      child: InkWell(
        onTap: () => _open(context, exercise.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              MuscleBadge(exercise.muscleGroup),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'e1RM ${formatEstimate(records.bestE1rm!.value)} · ${formatRelativeDay(sessions.last.date)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Sparkline(values: [for (final s in recent) s.bestE1rm]),
                  if (trend != null)
                    Text(
                      '${trend >= 0 ? '▲' : '▼'} ${(trend.abs() * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: trend >= 0 ? const Color(0xFF2EB872) : scheme.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
