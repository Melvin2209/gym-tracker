import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'watch.dart';

class WorkoutDetail {
  const WorkoutDetail({required this.workout, required this.entries});

  final Workout workout;
  final List<WorkoutEntry> entries;

  Iterable<WorkoutSet> get allSets => entries.expand((e) => e.sets);
  int get setCount => allSets.length;
  double get volume => allSets.fold(0, (sum, s) => sum + s.weight * s.reps);
  Duration duration(DateTime now) => (workout.finishedAt ?? now).difference(workout.startedAt);
}

class WorkoutEntry {
  const WorkoutEntry({required this.slot, required this.exercise, required this.sets});

  final WorkoutExercise slot;
  final Exercise exercise;
  final List<WorkoutSet> sets;
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.workout,
    required this.setCount,
    required this.volume,
    required this.exerciseNames,
  });

  final Workout workout;
  final int setCount;
  final double volume;
  final List<String> exerciseNames;

  Duration get duration => (workout.finishedAt ?? workout.startedAt).difference(workout.startedAt);
}

class WorkoutRepository {
  WorkoutRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  late final List<TableInfo<Table, Object?>> _tables = [
    _db.workouts,
    _db.workoutExercises,
    _db.workoutSets,
    _db.exercises,
  ];

  Stream<Workout?> watchActive() =>
      (_db.select(_db.workouts)
            ..where((w) => w.finishedAt.isNull() & w.deleted.equals(false))
            ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
            ..limit(1))
          .watchSingleOrNull();

  Stream<WorkoutDetail?> watchDetail(String workoutId) =>
      watchTables(_db, _tables, () => getDetail(workoutId));

  Future<WorkoutDetail?> getDetail(String workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId) & w.deleted.equals(false))).getSingleOrNull();
    if (workout == null) return null;

    final slots =
        await (_db.select(_db.workoutExercises).join([
                innerJoin(
                  _db.exercises,
                  _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
                ),
              ])
              ..where(
                _db.workoutExercises.workoutId.equals(workoutId) &
                    _db.workoutExercises.deleted.equals(false),
              )
              ..orderBy([OrderingTerm.asc(_db.workoutExercises.position)]))
            .get();
    final sets =
        await (_db.select(_db.workoutSets)
              ..where((s) => s.workoutId.equals(workoutId) & s.deleted.equals(false))
              ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
            .get();
    final setsBySlot = groupBy(sets, (WorkoutSet s) => s.workoutExerciseId);

    return WorkoutDetail(
      workout: workout,
      entries: [
        for (final row in slots)
          WorkoutEntry(
            slot: row.readTable(_db.workoutExercises),
            exercise: row.readTable(_db.exercises),
            sets: setsBySlot[row.readTable(_db.workoutExercises).id] ?? const [],
          ),
      ],
    );
  }

  /// Finished workouts, most recent first.
  Stream<List<WorkoutSummary>> watchHistory() => watchTables(_db, _tables, () async {
    final workouts =
        await (_db.select(_db.workouts)
              ..where((w) => w.finishedAt.isNotNull() & w.deleted.equals(false))
              ..orderBy([(w) => OrderingTerm.desc(w.startedAt)]))
            .get();
    final summaries = <WorkoutSummary>[];
    for (final w in workouts) {
      final detail = (await getDetail(w.id))!;
      summaries.add(
        WorkoutSummary(
          workout: w,
          setCount: detail.setCount,
          volume: detail.volume,
          exerciseNames: [
            for (final e in detail.entries)
              if (e.sets.isNotEmpty) e.exercise.name,
          ],
        ),
      );
    }
    return summaries;
  });

  /// Starts a workout, copying the exercises of [programDay] when given.
  Future<String> start({String? name, String? programDayId}) => _db.transaction(() async {
    final now = _now();
    final id = newId();
    var workoutName = name ?? 'Workout';
    List<ProgramExercise> planned = const [];
    if (programDayId != null) {
      final day = await (_db.select(
        _db.programDays,
      )..where((d) => d.id.equals(programDayId))).getSingle();
      workoutName = name ?? day.name;
      planned =
          await (_db.select(_db.programExercises)
                ..where((e) => e.dayId.equals(programDayId) & e.deleted.equals(false))
                ..orderBy([(e) => OrderingTerm.asc(e.position)]))
              .get();
    }
    await _db
        .into(_db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: Value(id),
            name: workoutName,
            programDayId: Value(programDayId),
            startedAt: now,
            updatedAt: Value(now),
          ),
        );
    for (final (i, p) in planned.indexed) {
      await _db
          .into(_db.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              workoutId: id,
              exerciseId: p.exerciseId,
              position: i,
              targetSets: Value(p.targetSets),
              targetReps: Value(p.targetReps),
              restSeconds: Value(p.restSeconds),
              updatedAt: Value(now),
            ),
          );
    }
    return id;
  });

  Future<String> addExercise(String workoutId, String exerciseId, {int restSeconds = 120}) async {
    final count = countAll();
    final row =
        await (_db.selectOnly(_db.workoutExercises)
              ..addColumns([count])
              ..where(
                _db.workoutExercises.workoutId.equals(workoutId) &
                    _db.workoutExercises.deleted.equals(false),
              ))
            .getSingle();
    final id = newId();
    await _db
        .into(_db.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            id: Value(id),
            workoutId: workoutId,
            exerciseId: exerciseId,
            position: row.read(count)!,
            restSeconds: Value(restSeconds),
            updatedAt: Value(_now()),
          ),
        );
    return id;
  }

  Future<void> removeExercise(String slotId) => _db.transaction(() async {
    final now = _now();
    await (_db.update(_db.workoutSets)..where((s) => s.workoutExerciseId.equals(slotId))).write(
      WorkoutSetsCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
    await (_db.update(_db.workoutExercises)..where((e) => e.id.equals(slotId))).write(
      WorkoutExercisesCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  });

  Future<WorkoutSet> logSet(
    WorkoutExercise slot, {
    required double weight,
    required int reps,
    double? rpe,
  }) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.workoutSets,
    )..where((s) => s.workoutExerciseId.equals(slot.id) & s.deleted.equals(false))).get();
    final now = _now();
    return _db
        .into(_db.workoutSets)
        .insertReturning(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: slot.id,
            workoutId: slot.workoutId,
            exerciseId: slot.exerciseId,
            setIndex: existing.map((s) => s.setIndex + 1).maxOrNull ?? 0,
            weight: weight,
            reps: reps,
            rpe: Value(rpe),
            completedAt: now,
            updatedAt: Value(now),
          ),
        );
  });

  Future<void> updateSet(String setId, {required double weight, required int reps, double? rpe}) =>
      (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId))).write(
        WorkoutSetsCompanion(
          weight: Value(weight),
          reps: Value(reps),
          rpe: Value(rpe),
          updatedAt: Value(_now()),
        ),
      );

  Future<void> deleteSet(String setId) =>
      (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId))).write(
        WorkoutSetsCompanion(deleted: const Value(true), updatedAt: Value(_now())),
      );

  /// Sets performed for [exerciseId] in the most recent finished workout
  /// other than [excludingWorkoutId]. Used to prefill and hint new sets.
  Future<List<WorkoutSet>> previousSets(String exerciseId, {String? excludingWorkoutId}) async {
    final query =
        _db.select(_db.workoutSets).join([
            innerJoin(_db.workouts, _db.workouts.id.equalsExp(_db.workoutSets.workoutId)),
          ])
          ..where(
            _db.workoutSets.exerciseId.equals(exerciseId) &
                _db.workoutSets.deleted.equals(false) &
                _db.workouts.deleted.equals(false) &
                _db.workouts.finishedAt.isNotNull() &
                (excludingWorkoutId == null
                    ? const Constant(true)
                    : _db.workouts.id.equals(excludingWorkoutId).not()),
          )
          ..orderBy([
            OrderingTerm.desc(_db.workouts.startedAt),
            OrderingTerm.asc(_db.workoutSets.setIndex),
          ]);
    final rows = await query.get();
    if (rows.isEmpty) return const [];
    final lastWorkoutId = rows.first.readTable(_db.workouts).id;
    return [
      for (final row in rows)
        if (row.readTable(_db.workouts).id == lastWorkoutId) row.readTable(_db.workoutSets),
    ];
  }

  Future<void> rename(String workoutId, String name) =>
      (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
        WorkoutsCompanion(name: Value(name.trim()), updatedAt: Value(_now())),
      );

  Future<void> updateNotes(String workoutId, String notes) =>
      (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
        WorkoutsCompanion(notes: Value(notes), updatedAt: Value(_now())),
      );

  Future<void> finish(String workoutId) => _db.transaction(() async {
    final now = _now();
    // Planned exercises that were never performed are dropped.
    final detail = await getDetail(workoutId);
    for (final entry in detail?.entries ?? const <WorkoutEntry>[]) {
      if (entry.sets.isEmpty) {
        await (_db.update(_db.workoutExercises)..where((e) => e.id.equals(entry.slot.id))).write(
          WorkoutExercisesCompanion(deleted: const Value(true), updatedAt: Value(now)),
        );
      }
    }
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(finishedAt: Value(now), updatedAt: Value(now)),
    );
  });

  /// Discards an in-progress workout, or deletes a finished one.
  Future<void> delete(String workoutId) => _db.transaction(() async {
    final now = _now();
    await (_db.update(_db.workoutSets)..where((s) => s.workoutId.equals(workoutId))).write(
      WorkoutSetsCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
    await (_db.update(_db.workoutExercises)..where((e) => e.workoutId.equals(workoutId))).write(
      WorkoutExercisesCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  });
}
