import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'watch.dart';

class ProgramDetail {
  const ProgramDetail({required this.program, required this.days});
  final Program program;
  final List<ProgramDayDetail> days;
}

class ProgramDayDetail {
  const ProgramDayDetail({required this.day, required this.exercises});
  final ProgramDay day;
  final List<({ProgramExercise item, Exercise exercise})> exercises;
}

class ProgramRepository {
  ProgramRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<ProgramDetail>> watchPrograms() => watchTables(
    _db,
    [_db.programs, _db.programDays, _db.programExercises, _db.exercises],
    () async {
      final programs =
          await (_db.select(_db.programs)
                ..where((p) => p.deleted.equals(false))
                ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
              .get();
      return [for (final p in programs) await _detail(p)];
    },
  );

  Stream<ProgramDetail?> watchProgram(String id) => watchTables(
    _db,
    [_db.programs, _db.programDays, _db.programExercises, _db.exercises],
    () async {
      final program = await (_db.select(
        _db.programs,
      )..where((p) => p.id.equals(id) & p.deleted.equals(false))).getSingleOrNull();
      return program == null ? null : _detail(program);
    },
  );

  Future<ProgramDayDetail?> getDay(String dayId) async {
    final day = await (_db.select(
      _db.programDays,
    )..where((d) => d.id.equals(dayId))).getSingleOrNull();
    return day == null ? null : _dayDetail(day);
  }

  Future<ProgramDetail> _detail(Program program) async {
    final days =
        await (_db.select(_db.programDays)
              ..where((d) => d.programId.equals(program.id) & d.deleted.equals(false))
              ..orderBy([(d) => OrderingTerm.asc(d.position)]))
            .get();
    return ProgramDetail(program: program, days: [for (final d in days) await _dayDetail(d)]);
  }

  Future<ProgramDayDetail> _dayDetail(ProgramDay day) async {
    final rows =
        await (_db.select(_db.programExercises).join([
                innerJoin(
                  _db.exercises,
                  _db.exercises.id.equalsExp(_db.programExercises.exerciseId),
                ),
              ])
              ..where(
                _db.programExercises.dayId.equals(day.id) &
                    _db.programExercises.deleted.equals(false),
              )
              ..orderBy([OrderingTerm.asc(_db.programExercises.position)]))
            .get();
    return ProgramDayDetail(
      day: day,
      exercises: [
        for (final row in rows)
          (item: row.readTable(_db.programExercises), exercise: row.readTable(_db.exercises)),
      ],
    );
  }

  Future<String> createProgram(String name, {String description = ''}) async {
    final id = newId();
    final now = _now();
    await _db
        .into(_db.programs)
        .insert(
          ProgramsCompanion.insert(
            id: Value(id),
            name: name.trim(),
            description: Value(description.trim()),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<void> updateProgram(String id, {String? name, String? description}) =>
      (_db.update(_db.programs)..where((p) => p.id.equals(id))).write(
        ProgramsCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          description: description == null ? const Value.absent() : Value(description.trim()),
          updatedAt: Value(_now()),
        ),
      );

  Future<void> deleteProgram(String id) => _db.transaction(() async {
    final now = _now();
    final days = await (_db.select(_db.programDays)..where((d) => d.programId.equals(id))).get();
    for (final day in days) {
      await _deleteDay(day.id, now);
    }
    await (_db.update(_db.programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  });

  Future<String> addDay(String programId, String name) async {
    final id = newId();
    final count = await _countWhere(
      _db.programDays,
      _db.programDays.programId.equals(programId) & _db.programDays.deleted.equals(false),
    );
    await _db
        .into(_db.programDays)
        .insert(
          ProgramDaysCompanion.insert(
            id: Value(id),
            programId: programId,
            name: name.trim(),
            position: count,
            updatedAt: Value(_now()),
          ),
        );
    return id;
  }

  Future<void> renameDay(String dayId, String name) =>
      (_db.update(_db.programDays)..where((d) => d.id.equals(dayId))).write(
        ProgramDaysCompanion(name: Value(name.trim()), updatedAt: Value(_now())),
      );

  Future<void> deleteDay(String dayId) => _db.transaction(() => _deleteDay(dayId, _now()));

  Future<void> _deleteDay(String dayId, DateTime now) async {
    await (_db.update(_db.programExercises)..where((e) => e.dayId.equals(dayId))).write(
      ProgramExercisesCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
    await (_db.update(_db.programDays)..where((d) => d.id.equals(dayId))).write(
      ProgramDaysCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  }

  Future<void> addExercise(
    String dayId,
    String exerciseId, {
    int sets = 3,
    int reps = 8,
    int restSeconds = 120,
  }) async {
    final count = await _countWhere(
      _db.programExercises,
      _db.programExercises.dayId.equals(dayId) & _db.programExercises.deleted.equals(false),
    );
    await _db
        .into(_db.programExercises)
        .insert(
          ProgramExercisesCompanion.insert(
            dayId: dayId,
            exerciseId: exerciseId,
            position: count,
            targetSets: Value(sets),
            targetReps: Value(reps),
            restSeconds: Value(restSeconds),
            updatedAt: Value(_now()),
          ),
        );
  }

  Future<void> updateExercise(String id, {int? sets, int? reps, int? restSeconds}) =>
      (_db.update(_db.programExercises)..where((e) => e.id.equals(id))).write(
        ProgramExercisesCompanion(
          targetSets: Value.absentIfNull(sets),
          targetReps: Value.absentIfNull(reps),
          restSeconds: Value.absentIfNull(restSeconds),
          updatedAt: Value(_now()),
        ),
      );

  Future<void> removeExercise(String id) =>
      (_db.update(_db.programExercises)..where((e) => e.id.equals(id))).write(
        ProgramExercisesCompanion(deleted: const Value(true), updatedAt: Value(_now())),
      );

  /// Moves an exercise one slot up (-1) or down (+1) within its day.
  Future<void> moveExercise(String dayId, String id, int delta) => _db.transaction(() async {
    final items =
        await (_db.select(_db.programExercises)
              ..where((e) => e.dayId.equals(dayId) & e.deleted.equals(false))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    final from = items.indexWhere((e) => e.id == id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= items.length) return;
    final reordered = [...items];
    reordered.insert(to, reordered.removeAt(from));
    final now = _now();
    for (final (i, item) in reordered.indexed) {
      if (item.position == i) continue;
      await (_db.update(_db.programExercises)..where((e) => e.id.equals(item.id))).write(
        ProgramExercisesCompanion(position: Value(i), updatedAt: Value(now)),
      );
    }
  });

  Future<int> _countWhere(TableInfo<Table, Object?> table, Expression<bool> where) async {
    final count = countAll();
    final row =
        await (_db.selectOnly(table)
              ..addColumns([count])
              ..where(where))
            .getSingle();
    return row.read(count)!;
  }
}
