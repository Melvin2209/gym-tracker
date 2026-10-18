import 'dart:math' as math;

enum OneRepMaxFormula { epley, brzycki, lombardi }

/// Estimates one-rep maxes from submaximal sets.
///
/// When an RPE is given, the reps left in reserve (10 - RPE) are added to the
/// performed reps, so 100 kg x 5 @ RPE 8 is treated like a 7-rep max.
abstract final class OneRepMax {
  /// Estimates above this many (effective) reps are unreliable.
  static const reliableRepLimit = 12;

  static double estimate(
    double weight,
    int reps, {
    double? rpe,
    OneRepMaxFormula formula = OneRepMaxFormula.epley,
  }) {
    if (weight <= 0 || reps <= 0) return 0;
    final effectiveReps = reps + repsInReserve(rpe);
    if (effectiveReps <= 1) return weight;
    return switch (formula) {
      OneRepMaxFormula.epley => weight * (1 + effectiveReps / 30),
      OneRepMaxFormula.brzycki =>
        effectiveReps >= 37
            ? weight * (1 + effectiveReps / 30)
            : weight * 36 / (37 - effectiveReps),
      OneRepMaxFormula.lombardi => weight * math.pow(effectiveReps, 0.10).toDouble(),
    };
  }

  /// Reps left in the tank for a given RPE (clamped to 0..4).
  static double repsInReserve(double? rpe) {
    if (rpe == null) return 0;
    return (10 - rpe).clamp(0, 4).toDouble();
  }

  static bool isReliable(int reps, {double? rpe}) => reps + repsInReserve(rpe) <= reliableRepLimit;

  /// Inverse of the Epley formula: the weight expected for [reps] given a 1RM.
  static double weightForReps(double oneRepMax, int reps) {
    if (reps <= 1) return oneRepMax;
    return oneRepMax / (1 + reps / 30);
  }

  /// Training percentages table (1..12 reps) for a given 1RM.
  static List<({int reps, double weight, int percent})> table(double oneRepMax) => [
    for (var reps = 1; reps <= 12; reps++)
      (
        reps: reps,
        weight: weightForReps(oneRepMax, reps),
        percent: (100 / (reps <= 1 ? 1 : 1 + reps / 30)).round(),
      ),
  ];
}
