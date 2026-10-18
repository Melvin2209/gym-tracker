import 'package:collection/collection.dart';

import 'logged_set.dart';
import 'one_rep_max.dart';

enum ProgressMetric {
  estimatedOneRepMax('e1RM', 'kg'),
  topWeight('Top set', 'kg'),
  volume('Volume', 'kg'),
  totalReps('Reps', 'reps');

  const ProgressMetric(this.label, this.unit);
  final String label;
  final String unit;
}

/// Aggregated performance of one exercise during one workout.
class SessionSummary {
  const SessionSummary({required this.workoutId, required this.date, required this.sets});

  final String workoutId;
  final DateTime date;
  final List<LoggedSet> sets;

  double get bestE1rm => sets
      .map((s) => OneRepMax.estimate(s.weight, s.reps, rpe: s.rpe))
      .fold(0, (a, b) => a > b ? a : b);

  LoggedSet get topSet => sets.reduce(
    (a, b) => b.weight > a.weight || (b.weight == a.weight && b.reps > a.reps) ? b : a,
  );

  double get volume => sets.fold(0, (sum, s) => sum + s.volume);
  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  double value(ProgressMetric metric) => switch (metric) {
    ProgressMetric.estimatedOneRepMax => bestE1rm,
    ProgressMetric.topWeight => topSet.weight,
    ProgressMetric.volume => volume,
    ProgressMetric.totalReps => totalReps.toDouble(),
  };
}

abstract final class Progression {
  /// Groups sets per workout, oldest session first.
  static List<SessionSummary> sessions(Iterable<LoggedSet> sets) {
    final byWorkout = groupBy(sets, (LoggedSet s) => s.workoutId);
    return [
      for (final entry in byWorkout.entries)
        SessionSummary(
          workoutId: entry.key,
          date: entry.value.map((s) => s.date).min,
          sets: entry.value,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Relative change of [metric] between the first and last session within
  /// [window] of the latest session, or null without enough data.
  static double? trend(
    List<SessionSummary> sessions,
    ProgressMetric metric, {
    Duration window = const Duration(days: 28),
  }) {
    if (sessions.length < 2) return null;
    final last = sessions.last;
    final from = last.date.subtract(window);
    final first = sessions.firstWhere((s) => !s.date.isBefore(from));
    if (identical(first, last)) return null;
    final start = first.value(metric);
    if (start == 0) return null;
    return (last.value(metric) - start) / start;
  }
}
