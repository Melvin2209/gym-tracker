import 'package:drift/drift.dart';

import '../../domain/logged_set.dart';
import '../db/app_database.dart';

class ExerciseRepository {
  ExerciseRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<Exercise>> watchAll() {
    final query = _db.select(_db.exercises)
      ..where((e) => e.deleted.equals(false))
      ..orderBy([(e) => OrderingTerm(expression: e.name.collate(Collate.noCase))]);
    return query.watch();
  }

  Stream<Exercise?> watch(String id) =>
      (_db.select(_db.exercises)..where((e) => e.id.equals(id))).watchSingleOrNull();

  Future<String> create({
    required String name,
    required MuscleGroup muscleGroup,
    required Equipment equipment,
  }) async {
    final id = newId();
    await _db
        .into(_db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: Value(id),
            name: name.trim(),
            muscleGroup: muscleGroup,
            equipment: equipment,
            isCustom: const Value(true),
            updatedAt: Value(_now()),
          ),
        );
    return id;
  }

  Future<void> delete(String id) => (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
      .write(ExercisesCompanion(deleted: const Value(true), updatedAt: Value(_now())));

  /// Every set ever logged for [exerciseId] in a finished workout.
  Stream<List<LoggedSet>> watchHistory(String exerciseId) {
    final query =
        _db.select(_db.workoutSets).join([
            innerJoin(_db.workouts, _db.workouts.id.equalsExp(_db.workoutSets.workoutId)),
          ])
          ..where(
            _db.workoutSets.exerciseId.equals(exerciseId) &
                _db.workoutSets.deleted.equals(false) &
                _db.workouts.deleted.equals(false) &
                _db.workouts.finishedAt.isNotNull(),
          )
          ..orderBy([OrderingTerm.asc(_db.workoutSets.completedAt)]);
    return query.watch().map(
      (rows) => [for (final row in rows) _toLogged(row.readTable(_db.workoutSets))],
    );
  }

  /// Sets of every finished workout, grouped by exercise id.
  Stream<Map<String, List<LoggedSet>>> watchAllHistory() {
    final query =
        _db.select(_db.workoutSets).join([
          innerJoin(_db.workouts, _db.workouts.id.equalsExp(_db.workoutSets.workoutId)),
        ])..where(
          _db.workoutSets.deleted.equals(false) &
              _db.workouts.deleted.equals(false) &
              _db.workouts.finishedAt.isNotNull(),
        );
    return query.watch().map((rows) {
      final result = <String, List<LoggedSet>>{};
      for (final row in rows) {
        final set = row.readTable(_db.workoutSets);
        result.putIfAbsent(set.exerciseId, () => []).add(_toLogged(set));
      }
      return result;
    });
  }

  static LoggedSet _toLogged(WorkoutSet s) => LoggedSet(
    weight: s.weight,
    reps: s.reps,
    rpe: s.rpe,
    date: s.completedAt,
    workoutId: s.workoutId,
    id: s.id,
  );
}
