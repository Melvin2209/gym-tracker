import 'dart:math';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'seed.dart';

/// Fills the database with a realistic training history: [weeks] weeks of the
/// starter Push / Pull / Legs program, with steady progression and some noise.
///
/// Used for screenshots, tests, and the "Load demo data" option.
Future<void> insertDemoHistory(
  AppDatabase db, {
  required DateTime now,
  int weeks = 10,
  int seed = 7,
}) async {
  final random = Random(seed);
  // Starting working weights (kg) and weekly increments.
  const start = {
    'ex-bench-press': (70.0, 1.25),
    'ex-ohp': (42.5, 0.6),
    'ex-incline-db-press': (24.0, 0.5),
    'ex-lateral-raise': (8.0, 0.2),
    'ex-triceps-pushdown': (25.0, 0.6),
    'ex-deadlift': (110.0, 2.5),
    'ex-pull-up': (0.0, 0.5),
    'ex-barbell-row': (60.0, 1.25),
    'ex-face-pull': (17.5, 0.4),
    'ex-barbell-curl': (30.0, 0.5),
    'ex-squat': (90.0, 2.5),
    'ex-rdl': (80.0, 1.8),
    'ex-leg-press': (140.0, 4.0),
    'ex-leg-curl': (35.0, 0.8),
    'ex-calf-raise': (60.0, 1.2),
  };
  double round(double kg, double step) => (kg / step).round() * step;

  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final firstMonday = monday.subtract(Duration(days: 7 * (weeks - 1)));

  await db.batch((b) {
    for (var week = 0; week < weeks; week++) {
      for (final (dayIndex, day) in starterProgram.days.indexed) {
        // Mon / Wed / Fri at around 6pm.
        final startedAt = firstMonday.add(
          Duration(days: week * 7 + dayIndex * 2, hours: 18, minutes: random.nextInt(40)),
        );
        if (!startedAt.isBefore(now.subtract(const Duration(hours: 2)))) continue;
        // Skip the odd session, like real life.
        if (week > 0 && week < weeks - 2 && random.nextDouble() < 0.08) continue;

        final workoutId = 'demo-w$week-d$dayIndex';
        // Children are queued so the workout row is inserted first.
        final children = <void Function()>[];
        var clock = startedAt.add(const Duration(minutes: 5));
        for (final (position, (exerciseId, targetSets, targetReps, rest))
            in day.exercises.indexed) {
          final slotId = '$workoutId-e$position';
          children.add(
            () => b.insert(
              db.workoutExercises,
              WorkoutExercisesCompanion.insert(
                id: Value(slotId),
                workoutId: workoutId,
                exerciseId: exerciseId,
                position: position,
                targetSets: Value(targetSets),
                targetReps: Value(targetReps),
                restSeconds: Value(rest),
                updatedAt: Value(startedAt),
              ),
              mode: InsertMode.insertOrIgnore,
            ),
          );
          final (base, perWeek) = start[exerciseId]!;
          // Deload every 5th week.
          final deload = week % 5 == 3 ? 0.9 : 1.0;
          final step = base >= 40 ? 2.5 : 1.0;
          final weight = round((base + perWeek * week) * deload, step);
          for (var s = 0; s < targetSets; s++) {
            final reps = max(1, targetReps + (s == 0 ? 1 : 0) - (s >= 2 ? random.nextInt(2) : 0));
            final rpe = deload < 1 ? 6.5 : min(10.0, 7.0 + s * 0.5 + random.nextInt(2) * 0.5);
            clock = clock.add(Duration(seconds: rest + 40 + random.nextInt(30)));
            final completedAt = clock;
            children.add(
              () => b.insert(
                db.workoutSets,
                WorkoutSetsCompanion.insert(
                  id: Value('$slotId-s$s'),
                  workoutExerciseId: slotId,
                  workoutId: workoutId,
                  exerciseId: exerciseId,
                  setIndex: s,
                  weight: weight,
                  reps: reps,
                  rpe: Value(rpe),
                  completedAt: completedAt,
                  updatedAt: Value(completedAt),
                ),
                mode: InsertMode.insertOrIgnore,
              ),
            );
          }
        }
        b.insert(
          db.workouts,
          WorkoutsCompanion.insert(
            id: Value(workoutId),
            name: day.name,
            programDayId: Value(day.id),
            startedAt: startedAt,
            finishedAt: Value(clock.add(const Duration(minutes: 3))),
            updatedAt: Value(clock),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        for (final insert in children) {
          insert();
        }
      }
    }
  });
}
