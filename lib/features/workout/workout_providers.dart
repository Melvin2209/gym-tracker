import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/program_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/logged_set.dart';
import '../../domain/personal_records.dart';

final activeWorkoutProvider = StreamProvider<Workout?>(
  (ref) => ref.watch(workoutRepositoryProvider).watchActive(),
);

final workoutDetailProvider = StreamProvider.family<WorkoutDetail?, String>(
  (ref, id) => ref.watch(workoutRepositoryProvider).watchDetail(id),
);

final workoutHistoryProvider = StreamProvider<List<WorkoutSummary>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchHistory(),
);

final programsProvider = StreamProvider<List<ProgramDetail>>(
  (ref) => ref.watch(programRepositoryProvider).watchPrograms(),
);

final exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

/// Sets of the previous session of an exercise, used as hints when logging.
final previousSetsProvider = FutureProvider.autoDispose
    .family<List<WorkoutSet>, ({String exerciseId, String workoutId})>(
      (ref, args) => ref
          .watch(workoutRepositoryProvider)
          .previousSets(args.exerciseId, excludingWorkoutId: args.workoutId),
    );

/// Every set from finished workouts, grouped by exercise.
final allHistoryProvider = StreamProvider<Map<String, List<LoggedSet>>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAllHistory(),
);

final exerciseHistoryProvider = StreamProvider.family<List<LoggedSet>, String>(
  (ref, exerciseId) => ref.watch(exerciseRepositoryProvider).watchHistory(exerciseId),
);

/// Records set in finished workouts other than [workoutId], so the sets of
/// the current workout can be compared against them.
final recordsBeforeProvider = Provider.autoDispose
    .family<PersonalRecords, ({String exerciseId, String workoutId})>((ref, args) {
      final history = ref.watch(allHistoryProvider).value?[args.exerciseId] ?? const [];
      return PersonalRecords.fromSets(history.where((s) => s.workoutId != args.workoutId));
    });

/// Summary numbers for the home screen.
final weeklyStatsProvider = Provider<({int workouts, double volume, int sets})>((ref) {
  final history = ref.watch(workoutHistoryProvider).value ?? const [];
  final now = ref.watch(clockProvider)();
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final thisWeek = history.where((w) => !w.workout.startedAt.isBefore(weekStart));
  return (
    workouts: thisWeek.length,
    volume: thisWeek.fold(0, (sum, w) => sum + w.volume),
    sets: thisWeek.fold(0, (sum, w) => sum + w.setCount),
  );
});
