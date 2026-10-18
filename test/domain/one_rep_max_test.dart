import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/domain/one_rep_max.dart';

void main() {
  group('OneRepMax.estimate', () {
    test('a single is its own 1RM', () {
      expect(OneRepMax.estimate(140, 1), 140);
      expect(OneRepMax.estimate(140, 1, formula: OneRepMaxFormula.brzycki), 140);
    });

    test('Epley formula', () {
      // 100 * (1 + 5/30)
      expect(OneRepMax.estimate(100, 5), closeTo(116.67, 0.01));
      expect(OneRepMax.estimate(80, 10), closeTo(106.67, 0.01));
    });

    test('Brzycki formula', () {
      // 100 * 36 / (37 - 5)
      expect(OneRepMax.estimate(100, 5, formula: OneRepMaxFormula.brzycki), closeTo(112.5, 0.01));
    });

    test('Lombardi formula', () {
      expect(
        OneRepMax.estimate(100, 10, formula: OneRepMaxFormula.lombardi),
        closeTo(125.89, 0.01),
      );
    });

    test('RPE adds the reps left in reserve', () {
      // 5 reps @ RPE 8 is treated as a 7-rep max.
      expect(OneRepMax.estimate(100, 5, rpe: 8), OneRepMax.estimate(100, 7));
      // RPE 10 changes nothing.
      expect(OneRepMax.estimate(100, 5, rpe: 10), OneRepMax.estimate(100, 5));
      // A single at RPE 9 counts as a double.
      expect(OneRepMax.estimate(100, 1, rpe: 9), OneRepMax.estimate(100, 2));
    });

    test('reps in reserve are clamped for very low RPE', () {
      expect(OneRepMax.repsInReserve(null), 0);
      expect(OneRepMax.repsInReserve(9.5), 0.5);
      expect(OneRepMax.repsInReserve(3), 4);
      expect(OneRepMax.repsInReserve(11), 0);
    });

    test('invalid input gives 0', () {
      expect(OneRepMax.estimate(0, 5), 0);
      expect(OneRepMax.estimate(100, 0), 0);
      expect(OneRepMax.estimate(-20, 5), 0);
    });

    test('Brzycki falls back to Epley past its asymptote', () {
      expect(
        OneRepMax.estimate(20, 40, formula: OneRepMaxFormula.brzycki),
        OneRepMax.estimate(20, 40),
      );
    });
  });

  test('isReliable flags high-rep estimates', () {
    expect(OneRepMax.isReliable(5), isTrue);
    expect(OneRepMax.isReliable(12), isTrue);
    expect(OneRepMax.isReliable(15), isFalse);
    expect(OneRepMax.isReliable(10, rpe: 7), isFalse);
  });

  test('weightForReps inverts Epley', () {
    final e1rm = OneRepMax.estimate(100, 8);
    expect(OneRepMax.weightForReps(e1rm, 8), closeTo(100, 1e-9));
    expect(OneRepMax.weightForReps(e1rm, 1), e1rm);
  });

  test('table lists 12 rep targets with decreasing weights', () {
    final table = OneRepMax.table(150);
    expect(table, hasLength(12));
    expect(table.first.percent, 100);
    expect(table.first.weight, 150);
    for (var i = 1; i < table.length; i++) {
      expect(table[i].weight, lessThan(table[i - 1].weight));
    }
  });
}
