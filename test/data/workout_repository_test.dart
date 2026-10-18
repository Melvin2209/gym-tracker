import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/db/app_database.dart';
import 'package:gym_tracker/data/db/seed.dart';
import 'package:gym_tracker/data/repositories/exercise_repository.dart';
import 'package:gym_tracker/data/repositories/workout_repository.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late WorkoutRepository workouts;
  late ExerciseRepository exercises;

  setUp(() {
    db = createTestDb();
    clock = FakeClock(DateTime(2026, 10, 1, 18));
    workouts = WorkoutRepository(db, clock: clock.call);
    exercises = ExerciseRepository(db, clock: clock.call);
  });

  tearDown(() => db.close());

  final pushDay = starterProgram.days.first;

  test('starting from a program day copies its exercises and targets', () async {
    final id = await workouts.start(programDayId: pushDay.id);
    final detail = (await workouts.getDetail(id))!;

    expect(detail.workout.name, 'Push');
    expect(detail.workout.finishedAt, isNull);
    expect(detail.entries.map((e) => e.exercise.id), [for (final e in pushDay.exercises) e.$1]);
    expect(detail.entries.first.slot.targetSets, 4);
    expect(detail.entries.first.slot.restSeconds, 180);
    expect(await workouts.watchActive().first, isNotNull);
  });

  test('logging, editing and deleting sets', () async {
    final id = await workouts.start();
    await workouts.addExercise(id, 'ex-squat');
    var slot = (await workouts.getDetail(id))!.entries.single.slot;

    final first = await workouts.logSet(slot, weight: 100, reps: 5, rpe: 8);
    clock.advance(const Duration(minutes: 3));
    await workouts.logSet(slot, weight: 100, reps: 5);
    await workouts.updateSet(first.id, weight: 102.5, reps: 4, rpe: 9);

    var detail = (await workouts.getDetail(id))!;
    expect(detail.entries.single.sets.map((s) => (s.setIndex, s.weight, s.reps)), [
      (0, 102.5, 4),
      (1, 100.0, 5),
    ]);
    expect(detail.volume, 102.5 * 4 + 500);

    await workouts.deleteSet(first.id);
    slot = (await workouts.getDetail(id))!.entries.single.slot;
    final third = await workouts.logSet(slot, weight: 90, reps: 8);
    expect(third.setIndex, 2, reason: 'indexes keep increasing after a delete');
    detail = (await workouts.getDetail(id))!;
    expect(detail.setCount, 2);
  });

  test('finishing drops planned exercises that were never performed', () async {
    final id = await workouts.start(programDayId: pushDay.id);
    final slot = (await workouts.getDetail(id))!.entries.first.slot;
    await workouts.logSet(slot, weight: 80, reps: 6);
    clock.advance(const Duration(minutes: 50));
    await workouts.finish(id);

    final detail = (await workouts.getDetail(id))!;
    expect(detail.entries, hasLength(1));
    expect(detail.workout.finishedAt, clock.now);
    expect(detail.duration(clock.now), const Duration(minutes: 50));
    expect(await workouts.watchActive().first, isNull);

    final history = await workouts.watchHistory().first;
    expect(history.single.exerciseNames, ['Bench Press']);
    expect(history.single.setCount, 1);
  });

  test('previousSets returns the latest other finished session', () async {
    Future<String> session(List<(double, int)> sets) async {
      final id = await workouts.start();
      await workouts.addExercise(id, 'ex-bench-press');
      final slot = (await workouts.getDetail(id))!.entries.single.slot;
      for (final (w, r) in sets) {
        await workouts.logSet(slot, weight: w, reps: r);
      }
      await workouts.finish(id);
      clock.advance(const Duration(days: 2));
      return id;
    }

    await session([(80, 5), (80, 5)]);
    final second = await session([(82.5, 5), (82.5, 4), (80, 5)]);
    final current = await workouts.start();

    final previous = await workouts.previousSets('ex-bench-press', excludingWorkoutId: current);
    expect(previous.map((s) => s.weight), [82.5, 82.5, 80]);

    final beforeSecond = await workouts.previousSets('ex-bench-press', excludingWorkoutId: second);
    expect(beforeSecond.map((s) => s.weight), [80, 80]);
    expect(await workouts.previousSets('ex-squat'), isEmpty);
  });

  test('discarding a workout hides it and its sets', () async {
    final id = await workouts.start();
    await workouts.addExercise(id, 'ex-deadlift');
    final slot = (await workouts.getDetail(id))!.entries.single.slot;
    await workouts.logSet(slot, weight: 140, reps: 3);
    await workouts.delete(id);

    expect(await workouts.getDetail(id), isNull);
    expect(await workouts.watchActive().first, isNull);
    expect(await exercises.watchHistory('ex-deadlift').first, isEmpty);
  });

  test('exercise history only contains finished workouts', () async {
    final done = await workouts.start();
    await workouts.addExercise(done, 'ex-ohp');
    var slot = (await workouts.getDetail(done))!.entries.single.slot;
    await workouts.logSet(slot, weight: 50, reps: 5);
    await workouts.finish(done);

    final ongoing = await workouts.start();
    await workouts.addExercise(ongoing, 'ex-ohp');
    slot = (await workouts.getDetail(ongoing))!.entries.single.slot;
    await workouts.logSet(slot, weight: 52.5, reps: 5);

    final history = await exercises.watchHistory('ex-ohp').first;
    expect(history.map((s) => s.weight), [50]);
    final all = await exercises.watchAllHistory().first;
    expect(all.keys, ['ex-ohp']);
  });

  test('custom exercises can be created and deleted', () async {
    final id = await exercises.create(
      name: '  Zercher Squat ',
      muscleGroup: MuscleGroup.legs,
      equipment: Equipment.barbell,
    );
    final created = await exercises.watch(id).first;
    expect(created!.name, 'Zercher Squat');
    expect(created.isCustom, isTrue);
    expect((await exercises.watchAll().first).map((e) => e.name), contains('Zercher Squat'));

    await exercises.delete(id);
    expect((await exercises.watchAll().first).map((e) => e.id), isNot(contains(id)));
  });
}
