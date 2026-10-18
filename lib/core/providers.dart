import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/program_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../services/rest_alarm.dart';

/// Overridden in `main()` and in tests.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final restAlarmProvider = Provider<RestAlarm>((ref) => const NoopRestAlarm());

final exerciseRepositoryProvider = Provider(
  (ref) => ExerciseRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)),
);

final programRepositoryProvider = Provider(
  (ref) => ProgramRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)),
);

final workoutRepositoryProvider = Provider(
  (ref) => WorkoutRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
