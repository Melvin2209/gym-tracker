/// A completed set, independent from the persistence layer.
class LoggedSet {
  const LoggedSet({
    required this.weight,
    required this.reps,
    required this.date,
    required this.workoutId,
    this.rpe,
    this.id,
  });

  final double weight;
  final int reps;
  final double? rpe;
  final DateTime date;
  final String workoutId;

  /// Id of the stored set, when it comes from the database.
  final String? id;

  double get volume => weight * reps;

  @override
  String toString() => 'LoggedSet($weight x $reps @${rpe ?? '-'} on $date)';
}
