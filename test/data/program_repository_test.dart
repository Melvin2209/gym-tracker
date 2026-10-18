import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/db/app_database.dart';
import 'package:gym_tracker/data/repositories/program_repository.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late ProgramRepository repo;

  setUp(() {
    db = createTestDb();
    repo = ProgramRepository(db, clock: FakeClock(DateTime(2026, 1, 1)).call);
  });

  tearDown(() => db.close());

  test('the starter program is seeded on first launch', () async {
    final programs = await repo.watchPrograms().first;
    expect(programs.single.program.name, 'Push / Pull / Legs');
    expect(programs.single.days.map((d) => d.day.name), ['Push', 'Pull', 'Legs']);
    expect(programs.single.days.first.exercises.first.exercise.name, 'Bench Press');
  });

  test('builds a program with days and exercises', () async {
    final id = await repo.createProgram('Upper / Lower', description: 'Four days');
    final upper = await repo.addDay(id, 'Upper');
    await repo.addDay(id, 'Lower');
    await repo.addExercise(upper, 'ex-bench-press', sets: 5, reps: 5, restSeconds: 180);
    await repo.addExercise(upper, 'ex-barbell-row');

    final program = (await repo.watchProgram(id).first)!;
    expect(program.program.description, 'Four days');
    expect(program.days.map((d) => d.day.name), ['Upper', 'Lower']);
    final items = program.days.first.exercises;
    expect(items.map((e) => e.exercise.id), ['ex-bench-press', 'ex-barbell-row']);
    expect(items.first.item.targetSets, 5);
    expect(items.last.item.targetSets, 3);

    await repo.updateExercise(items.last.item.id, sets: 4, reps: 10);
    final updated = (await repo.getDay(upper))!.exercises.last.item;
    expect((updated.targetSets, updated.targetReps, updated.restSeconds), (4, 10, 120));
  });

  test('reorders exercises within a day', () async {
    final id = await repo.createProgram('P');
    final day = await repo.addDay(id, 'D');
    for (final e in ['ex-squat', 'ex-rdl', 'ex-leg-curl']) {
      await repo.addExercise(day, e);
    }
    Future<List<String>> order() async => [
      for (final e in (await repo.getDay(day))!.exercises) e.exercise.id,
    ];
    final items = (await repo.getDay(day))!.exercises;

    await repo.moveExercise(day, items[2].item.id, -1);
    expect(await order(), ['ex-squat', 'ex-leg-curl', 'ex-rdl']);
    await repo.moveExercise(day, items[0].item.id, 1);
    expect(await order(), ['ex-leg-curl', 'ex-squat', 'ex-rdl']);
    // Out of bounds moves are ignored.
    await repo.moveExercise(day, items[1].item.id, 1); // ex-rdl is already last
    expect(await order(), ['ex-leg-curl', 'ex-squat', 'ex-rdl']);
  });

  test('deleting removes the program, its days and exercises', () async {
    final id = await repo.createProgram('Temp');
    final day = await repo.addDay(id, 'Only day');
    await repo.addExercise(day, 'ex-squat');
    await repo.deleteProgram(id);

    expect(await repo.watchProgram(id).first, isNull);
    expect((await repo.watchPrograms().first).map((p) => p.program.id), isNot(contains(id)));
    final rows = await db.select(db.programExercises).get();
    expect(rows.where((r) => r.dayId == day).every((r) => r.deleted), isTrue);
  });

  test('watchPrograms emits again after a change', () async {
    final emissions = <int>[];
    final sub = repo.watchPrograms().listen((p) => emissions.add(p.length));
    await pumpEventQueue();
    await repo.createProgram('Another');
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions, [1, 2]);
  });
}
