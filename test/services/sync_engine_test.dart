import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/db/app_database.dart';
import 'package:gym_tracker/data/repositories/exercise_repository.dart';
import 'package:gym_tracker/data/repositories/program_repository.dart';
import 'package:gym_tracker/data/repositories/workout_repository.dart';
import 'package:gym_tracker/services/sync/remote_store.dart';
import 'package:gym_tracker/services/sync/sync_engine.dart';

import '../support/test_db.dart';

/// One simulated device: its own database and clock, sharing a remote store.
class Device {
  Device(this.remote, this.clock) : db = createTestDb();

  final RemoteStore remote;
  final FakeClock clock;
  final AppDatabase db;
  SyncCursor cursor = const SyncCursor();

  WorkoutRepository get workouts => WorkoutRepository(db, clock: clock.call);
  ProgramRepository get programs => ProgramRepository(db, clock: clock.call);
  ExerciseRepository get exercises => ExerciseRepository(db, clock: clock.call);

  Future<SyncResult> sync() async {
    final result = await SyncEngine(db, remote, clock: clock.call).sync(cursor);
    cursor = result.cursor;
    clock.advance(const Duration(seconds: 1));
    return result;
  }
}

void main() {
  late InMemoryRemoteStore remote;
  late Device phone;
  late Device tablet;

  setUp(() {
    remote = InMemoryRemoteStore();
    // Devices share a clock: last-write-wins assumes roughly synced clocks.
    final clock = FakeClock(DateTime(2026, 5, 1, 9));
    phone = Device(remote, clock);
    tablet = Device(remote, clock);
  });

  tearDown(() async {
    await phone.db.close();
    await tablet.db.close();
  });

  Future<String> logWorkout(Device d, String exerciseId, double weight) async {
    final id = await d.workouts.start(name: 'Session');
    await d.workouts.addExercise(id, exerciseId);
    final slot = (await d.workouts.getDetail(id))!.entries.single.slot;
    await d.workouts.logSet(slot, weight: weight, reps: 5, rpe: 8.5);
    d.clock.advance(const Duration(minutes: 45));
    await d.workouts.finish(id);
    return id;
  }

  test('first sync uploads the whole local database', () async {
    await logWorkout(phone, 'ex-squat', 100);
    final result = await phone.sync();
    expect(result.pushed, greaterThan(30)); // seeded library + program + workout
    expect(remote.collections['workoutSets'], hasLength(1));
    final doc = remote.collections['workoutSets']!.values.single;
    expect(doc['weight'], 100.0);
    expect(doc['rpe'], 8.5);
    expect(doc['updatedAt'], isA<int>());
    expect(doc['syncedAt'], isA<int>());
  });

  test('a workout logged on one device appears on the other', () async {
    final id = await logWorkout(phone, 'ex-bench-press', 85);
    await phone.sync();
    final result = await tablet.sync();

    expect(result.pulled, greaterThan(0));
    final detail = (await tablet.workouts.getDetail(id))!;
    expect(detail.workout.finishedAt, isNotNull);
    expect(detail.entries.single.exercise.name, 'Bench Press');
    expect(detail.entries.single.sets.single.weight, 85);
    expect(detail.entries.single.sets.single.rpe, 8.5);
  });

  test('incremental syncs only send what changed', () async {
    await phone.sync();
    await tablet.sync();
    await phone.sync(); // receives the tablet's echo of the library
    final idle = await phone.sync();
    expect(idle.pushed, 0);
    expect(idle.pulled, 0);

    await phone.programs.createProgram('5/3/1');
    final result = await phone.sync();
    expect(result.pushed, 1);
    expect((await tablet.sync()).pulled, 1);
    final names = (await tablet.programs.watchPrograms().first).map((p) => p.program.name);
    expect(names, contains('5/3/1'));
  });

  test('last write wins on conflicting edits', () async {
    final id = await logWorkout(phone, 'ex-deadlift', 140);
    await phone.sync();
    await tablet.sync();

    // Both devices rename the same workout while offline; the tablet is later.
    await phone.workouts.rename(id, 'Phone name');
    phone.clock.advance(const Duration(minutes: 5));
    await tablet.workouts.rename(id, 'Tablet name');

    await phone.sync();
    await tablet.sync(); // pulls the older phone edit: ignored, pushes its own
    await phone.sync(); // the tablet's edit predates this sync, but was uploaded after it

    expect((await phone.workouts.getDetail(id))!.workout.name, 'Tablet name');
    expect((await tablet.workouts.getDetail(id))!.workout.name, 'Tablet name');
  });

  test('deletions propagate as tombstones', () async {
    final id = await logWorkout(phone, 'ex-squat', 120);
    await phone.sync();
    await tablet.sync();
    expect(await tablet.workouts.getDetail(id), isNotNull);

    await tablet.workouts.delete(id);
    await tablet.sync();
    await phone.sync();

    expect(await phone.workouts.getDetail(id), isNull);
    expect(await phone.exercises.watchHistory('ex-squat').first, isEmpty);
  });
}
