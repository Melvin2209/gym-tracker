import 'package:drift/drift.dart';

import '../../data/db/app_database.dart';
import 'remote_store.dart';

/// Where the previous sync stopped.
class SyncCursor {
  const SyncCursor({this.pushedUpTo, this.pulledUpTo});

  /// Local time of the previous sync: local rows updated after it are pushed.
  final DateTime? pushedUpTo;

  /// Highest server `syncedAt` received so far.
  final int? pulledUpTo;
}

class SyncResult {
  const SyncResult({required this.pushed, required this.pulled, required this.cursor});

  final int pushed;
  final int pulled;
  final SyncCursor cursor;
}

/// Two-way, last-write-wins synchronisation between the local Drift database
/// and a [RemoteStore].
///
/// Every synced row carries an `updatedAt` timestamp and a `deleted`
/// tombstone. A sync pulls remote rows uploaded since the previous sync and
/// keeps them when they are newer than the local copy, then pushes local rows
/// changed since the previous sync. Conflicts are resolved by comparing
/// `updatedAt`, so devices are expected to have roughly correct clocks.
class SyncEngine {
  SyncEngine(this._db, this._remote, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final RemoteStore _remote;
  final DateTime Function() _now;

  /// Parents before children so foreign keys hold while applying changes.
  late final List<_SyncedTable> _tables = [
    _SyncedTable<Exercise>('exercises', _db.exercises, Exercise.fromJson),
    _SyncedTable<Program>('programs', _db.programs, Program.fromJson),
    _SyncedTable<ProgramDay>('programDays', _db.programDays, ProgramDay.fromJson),
    _SyncedTable<ProgramExercise>(
      'programExercises',
      _db.programExercises,
      ProgramExercise.fromJson,
    ),
    _SyncedTable<Workout>('workouts', _db.workouts, Workout.fromJson),
    _SyncedTable<WorkoutExercise>(
      'workoutExercises',
      _db.workoutExercises,
      WorkoutExercise.fromJson,
    ),
    _SyncedTable<WorkoutSet>('workoutSets', _db.workoutSets, WorkoutSet.fromJson),
  ];

  Future<SyncResult> sync([SyncCursor cursor = const SyncCursor()]) async {
    // Local changes made while syncing are caught by the next run.
    final startedAt = _now();
    var pulled = 0;
    var pushed = 0;
    var pulledUpTo = cursor.pulledUpTo;

    final remoteChanges = <_SyncedTable, List<Map<String, Object?>>>{};
    for (final t in _tables) {
      final docs = await _remote.changedSince(t.name, cursor.pulledUpTo);
      remoteChanges[t] = docs;
      for (final doc in docs) {
        final syncedAt = doc[RemoteStore.syncedAtField]! as int;
        if (pulledUpTo == null || syncedAt > pulledUpTo) pulledUpTo = syncedAt;
      }
    }
    await _db.transaction(() async {
      for (final t in _tables) {
        pulled += await t.applyRemote(_db, remoteChanges[t]!);
      }
    });

    for (final t in _tables) {
      final local = await t.changedSince(_db, cursor.pushedUpTo);
      if (local.isEmpty) continue;
      await _remote.upsertAll(t.name, local);
      pushed += local.length;
    }

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      cursor: SyncCursor(pushedUpTo: startedAt, pulledUpTo: pulledUpTo),
    );
  }
}

class _SyncedTable<D extends DataClass> {
  _SyncedTable(this.name, this.table, this.fromJson);

  final String name;
  final TableInfo<Table, D> table;
  final D Function(Map<String, dynamic> json, {ValueSerializer? serializer}) fromJson;

  GeneratedColumn<String> get _id => table.columnsByName['id']! as GeneratedColumn<String>;
  GeneratedColumn<DateTime> get _updatedAt =>
      table.columnsByName['updated_at']! as GeneratedColumn<DateTime>;

  Future<List<Map<String, Object?>>> changedSince(AppDatabase db, DateTime? since) async {
    final query = db.select(table);
    if (since != null) query.where((_) => _updatedAt.isBiggerThanValue(since));
    final rows = await query.get();
    return [for (final row in rows) row.toJson()];
  }

  /// Applies remote rows that are newer than their local copy.
  Future<int> applyRemote(AppDatabase db, List<Map<String, Object?>> docs) async {
    if (docs.isEmpty) return 0;
    final ids = [for (final d in docs) d['id']! as String];
    final local = <String, DateTime>{};
    for (final row
        in await (db.selectOnly(table)
              ..addColumns([_id, _updatedAt])
              ..where(_id.isIn(ids)))
            .get()) {
      local[row.read(_id)!] = row.read(_updatedAt)!;
    }

    var applied = 0;
    for (final doc in docs) {
      final remoteUpdatedAt = DateTime.fromMillisecondsSinceEpoch(doc['updatedAt']! as int);
      final localUpdatedAt = local[doc['id']];
      if (localUpdatedAt != null && !remoteUpdatedAt.isAfter(localUpdatedAt)) {
        continue;
      }
      final row = fromJson(doc) as Insertable<D>;
      await db.into(table).insertOnConflictUpdate(row);
      applied++;
    }
    return applied;
  }
}
