import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    Programs,
    ProgramDays,
    ProgramExercises,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'gym_tracker'));

  /// Set to false in tests that want an empty database.
  static bool seedOnCreate = true;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      if (seedOnCreate) await seedDefaults();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Seeded rows get a fixed timestamp so that every device holds the exact
  /// same version and any user edit wins during sync.
  static final seedTimestamp = DateTime.utc(2024);

  Future<void> seedDefaults() async {
    final seeded = Value(seedTimestamp);
    await batch((b) {
      b.insertAll(exercises, [
        for (final (id, name, group, equipment) in defaultExercises)
          ExercisesCompanion.insert(
            id: Value(id),
            name: name,
            muscleGroup: group,
            equipment: equipment,
            updatedAt: seeded,
          ),
      ], mode: InsertMode.insertOrIgnore);
      final p = starterProgram;
      b.insert(
        programs,
        ProgramsCompanion.insert(
          id: Value(p.id),
          name: p.name,
          description: Value(p.description),
          createdAt: seeded,
          updatedAt: seeded,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      for (final (i, day) in p.days.indexed) {
        b.insert(
          programDays,
          ProgramDaysCompanion.insert(
            id: Value(day.id),
            programId: p.id,
            name: day.name,
            position: i,
            updatedAt: seeded,
          ),
          mode: InsertMode.insertOrIgnore,
        );
        for (final (j, (exerciseId, sets, reps, rest)) in day.exercises.indexed) {
          b.insert(
            programExercises,
            ProgramExercisesCompanion.insert(
              id: Value('${day.id}-$j'),
              dayId: day.id,
              exerciseId: exerciseId,
              position: j,
              targetSets: Value(sets),
              targetReps: Value(reps),
              restSeconds: Value(rest),
              updatedAt: seeded,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }
}
