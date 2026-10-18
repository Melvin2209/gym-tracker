import 'package:collection/collection.dart';

import 'logged_set.dart';
import 'one_rep_max.dart';

enum PrType {
  estimatedOneRepMax('e1RM'),
  heaviestWeight('Heaviest'),
  bestSetVolume('Volume'),
  repMax('Rep max');

  const PrType(this.label);
  final String label;
}

class PersonalRecords {
  const PersonalRecords({
    this.bestE1rm,
    this.heaviest,
    this.bestVolumeSet,
    this.repMaxes = const {},
  });

  static const empty = PersonalRecords();

  /// Set with the highest estimated 1RM, and that estimate.
  final ({LoggedSet set, double value})? bestE1rm;
  final LoggedSet? heaviest;
  final LoggedSet? bestVolumeSet;

  /// Heaviest weight lifted for each exact rep count.
  final Map<int, LoggedSet> repMaxes;

  bool get isEmpty => heaviest == null;

  factory PersonalRecords.fromSets(Iterable<LoggedSet> sets) {
    var records = PersonalRecords.empty;
    // Oldest first so that ties are credited to the first time it happened.
    for (final set in sets.sortedBy((s) => s.date)) {
      records = records.add(set);
    }
    return records;
  }

  /// Which records [set] would break, compared with the current ones.
  Set<PrType> brokenBy(LoggedSet set) {
    if (set.weight <= 0 || set.reps <= 0) return const {};
    final e1rm = OneRepMax.estimate(set.weight, set.reps, rpe: set.rpe);
    final previousRepMax = repMaxes[set.reps];
    return {
      if (bestE1rm == null || e1rm > bestE1rm!.value + 1e-9) PrType.estimatedOneRepMax,
      if (heaviest == null || set.weight > heaviest!.weight) PrType.heaviestWeight,
      if (bestVolumeSet == null || set.volume > bestVolumeSet!.volume) PrType.bestSetVolume,
      // Only beating an existing rep max counts, not a first-ever rep count.
      if (previousRepMax != null && set.weight > previousRepMax.weight) PrType.repMax,
    };
  }

  PersonalRecords add(LoggedSet set) {
    final broken = brokenBy(set);
    final previousRepMax = repMaxes[set.reps];
    final newRepMax =
        set.reps > 0 && (previousRepMax == null || set.weight > previousRepMax.weight);
    if (broken.isEmpty && !newRepMax) return this;
    return PersonalRecords(
      bestE1rm: broken.contains(PrType.estimatedOneRepMax)
          ? (set: set, value: OneRepMax.estimate(set.weight, set.reps, rpe: set.rpe))
          : bestE1rm,
      heaviest: broken.contains(PrType.heaviestWeight) ? set : heaviest,
      bestVolumeSet: broken.contains(PrType.bestSetVolume) ? set : bestVolumeSet,
      repMaxes: newRepMax ? {...repMaxes, set.reps: set} : repMaxes,
    );
  }

  /// PRs broken by each set of [workoutId], compared with everything that
  /// happened before it. Keys are indexes into [sets].
  static Map<int, Set<PrType>> forWorkout(List<LoggedSet> sets, String workoutId) {
    final result = <int, Set<PrType>>{};
    var records = PersonalRecords.empty;
    // Nothing to beat during the very first session of an exercise.
    var hasHistory = false;
    for (final (index, set) in sets.indexed.sortedBy((e) => e.$2.date)) {
      if (set.workoutId == workoutId) {
        final broken = records.brokenBy(set);
        if (hasHistory && broken.isNotEmpty) result[index] = broken;
      } else {
        hasHistory = true;
      }
      records = records.add(set);
    }
    return result;
  }
}
