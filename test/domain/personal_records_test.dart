import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/domain/logged_set.dart';
import 'package:gym_tracker/domain/personal_records.dart';

LoggedSet s(double weight, int reps, int day, {double? rpe, String? workout}) => LoggedSet(
  weight: weight,
  reps: reps,
  rpe: rpe,
  date: DateTime(2026, 1, day, 18),
  workoutId: workout ?? 'w$day',
);

void main() {
  group('PersonalRecords.fromSets', () {
    test('is empty without sets', () {
      final records = PersonalRecords.fromSets(const []);
      expect(records.isEmpty, isTrue);
      expect(records.bestE1rm, isNull);
    });

    test('tracks heaviest, best e1RM, best volume and rep maxes', () {
      final records = PersonalRecords.fromSets([
        s(100, 5, 1),
        s(110, 1, 2), // heaviest, e1RM 110
        s(90, 10, 3), // e1RM 120, volume 900
        s(95, 5, 4), // lighter 5RM, ignored
      ]);
      expect(records.heaviest!.weight, 110);
      expect(records.bestE1rm!.set.weight, 90);
      expect(records.bestE1rm!.value, closeTo(120, 1e-9));
      expect(records.bestVolumeSet!.volume, 900);
      expect(records.repMaxes[5]!.weight, 100);
      expect(records.repMaxes[1]!.weight, 110);
      expect(records.repMaxes[10]!.weight, 90);
    });

    test('order of input does not matter', () {
      final sets = [s(100, 5, 3), s(100, 5, 1), s(105, 3, 2)];
      final a = PersonalRecords.fromSets(sets);
      final b = PersonalRecords.fromSets(sets.reversed);
      expect(a.heaviest, same(b.heaviest));
      // Ties are credited to the first occurrence.
      expect(a.repMaxes[5]!.date.day, 1);
    });
  });

  group('brokenBy', () {
    final records = PersonalRecords.fromSets([s(100, 5, 1)]);

    test('heavier set breaks weight and e1RM records', () {
      expect(
        records.brokenBy(s(105, 5, 2)),
        containsAll([PrType.heaviestWeight, PrType.estimatedOneRepMax, PrType.repMax]),
      );
    });

    test('more reps at the same weight breaks e1RM and volume only', () {
      final broken = records.brokenBy(s(100, 6, 2));
      expect(broken, contains(PrType.estimatedOneRepMax));
      expect(broken, contains(PrType.bestSetVolume));
      expect(broken, isNot(contains(PrType.heaviestWeight)));
      // First time doing 6 reps: nothing to beat yet.
      expect(broken, isNot(contains(PrType.repMax)));
    });

    test('equal set breaks nothing', () {
      expect(records.brokenBy(s(100, 5, 2)), isEmpty);
    });

    test('ignores empty sets', () {
      expect(records.brokenBy(s(0, 0, 2)), isEmpty);
    });
  });

  group('forWorkout', () {
    test('reports PRs only for sets of the given workout', () {
      final sets = [
        s(100, 5, 1),
        s(100, 5, 1),
        s(102.5, 5, 8), // PR
        s(102.5, 5, 8), // ties the previous set: no PR
        s(90, 5, 8),
      ];
      final prs = PersonalRecords.forWorkout(sets, 'w8');
      expect(prs.keys, [2]);
      expect(prs[2], contains(PrType.heaviestWeight));
    });

    test('the very first workout has no PRs', () {
      final sets = [s(60, 5, 1), s(70, 5, 1)];
      expect(PersonalRecords.forWorkout(sets, 'w1'), isEmpty);
    });
  });
}
