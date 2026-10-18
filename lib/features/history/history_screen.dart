import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/workout_repository.dart';
import '../workout/workout_providers.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No workouts yet',
              message: 'Finished workouts show up here with their volume and records.',
            );
          }
          final byMonth = groupBy(
            workouts,
            (WorkoutSummary w) => DateFormat('MMMM yyyy').format(w.workout.startedAt),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final MapEntry(key: month, value: items) in byMonth.entries) ...[
                SectionHeader(
                  month,
                  trailing: Text(
                    '${items.length} workout${items.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                for (final w in items) ...[
                  WorkoutSummaryCard(summary: w),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class WorkoutSummaryCard extends StatelessWidget {
  const WorkoutSummaryCard({super.key, required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final w = summary.workout;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => WorkoutDetailScreen(workoutId: w.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE').format(w.startedAt).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${w.startedAt.day}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      summary.exerciseNames.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      children: [
                        _Meta(Icons.schedule, formatDuration(summary.duration)),
                        _Meta(Icons.layers_outlined, '${summary.setCount} sets'),
                        _Meta(Icons.bar_chart_rounded, formatVolume(summary.volume)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color)),
      ],
    );
  }
}
