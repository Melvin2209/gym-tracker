import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gym_tracker/data/db/app_database.dart';

AppDatabase createTestDb({bool seed = true}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  AppDatabase.seedOnCreate = seed;
  // Synchronous stream cleanup avoids drift's zero-delay timers, which widget
  // tests would report as pending.
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}

/// A controllable clock for deterministic timestamps.
class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}
