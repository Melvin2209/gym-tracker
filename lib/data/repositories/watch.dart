import 'package:drift/drift.dart';

/// Emits [load] once, then again every time one of [tables] changes.
///
/// Handy for screens that read a small aggregate spread across several
/// tables, where composing individual `watch()` streams would be noisy.
/// Piggybacks on a trivial drift query so that drift handles debouncing and
/// cancellation, and `asyncMap` keeps results in order.
Stream<T> watchTables<T>(
  DatabaseConnectionUser db,
  Iterable<TableInfo<Table, Object?>> tables,
  Future<T> Function() load,
) {
  final names = [for (final t in tables) t.actualTableName]..sort();
  // Drift shares streams with identical SQL, so the table list must be part of
  // the statement; otherwise watchers would only see the first one's tables.
  return db
      .customSelect('SELECT 1 /* ${names.join(',')} */', readsFrom: tables.toSet())
      .watch()
      .asyncMap((_) => load());
}
