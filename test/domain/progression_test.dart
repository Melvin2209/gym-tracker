import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/domain/logged_set.dart';
import 'package:gym_tracker/domain/one_rep_max.dart';
import 'package:gym_tracker/domain/progression.dart';

LoggedSet s(double weight, int reps, int day, {int minute = 0}) => LoggedSet(
  weight: weight,
  reps: reps,
  date: DateTime(2026, 3, day, 18, minute),
  workoutId: 'w$day',
);

void main() {
  test('sessions groups sets per workout, oldest first', () {
    final sessions = Progression.sessions([
      s(100, 5, 10),
      s(80, 8, 3, minute: 5),
      s(85, 8, 3, minute: 10),
      s(105, 3, 10, minute: 4),
    ]);
    expect(sessions.map((x) => x.workoutId), ['w3', 'w10']);
    expect(sessions.first.sets, hasLength(2));
    expect(sessions.first.date, DateTime(2026, 3, 3, 18, 5));
  });

  test('session summary metrics', () {
    final session = Progression.sessions([s(100, 5, 1), s(105, 3, 1), s(105, 2, 1)]).single;
    expect(session.topSet.weight, 105);
    expect(session.topSet.reps, 3);
    expect(session.volume, 500 + 315 + 210);
    expect(session.totalReps, 10);
    expect(session.bestE1rm, closeTo(OneRepMax.estimate(100, 5), 1e-9));
    expect(session.value(ProgressMetric.topWeight), 105);
    expect(session.value(ProgressMetric.totalReps), 10);
  });

  group('trend', () {
    test('needs two sessions', () {
      expect(
        Progression.trend(Progression.sessions([s(100, 5, 1)]), ProgressMetric.topWeight),
        isNull,
      );
    });

    test('compares the first session in the window with the last', () {
      final sessions = Progression.sessions([
        s(50, 5, 1), // outside the window
        s(100, 5, 5),
        s(105, 5, 12),
        s(110, 5, 28),
      ]);
      expect(
        Progression.trend(sessions, ProgressMetric.topWeight, window: const Duration(days: 25)),
        closeTo(0.10, 1e-9),
      );
    });

    test('is null when only the last session is in the window', () {
      final sessions =
          Progression.sessions([s(100, 5, 1)]) +
          [
            SessionSummary(workoutId: 'late', date: DateTime(2026, 6, 1), sets: [s(120, 5, 1)]),
          ];
      expect(Progression.trend(sessions, ProgressMetric.topWeight), isNull);
    });
  });
}
