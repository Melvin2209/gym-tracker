/// Immutable state of the rest timer. Time is always derived from wall-clock
/// timestamps so the countdown stays correct if the app is suspended.
class RestTimerState {
  const RestTimerState._({required this.total, this.endsAt, this.pausedRemaining});

  const RestTimerState.idle() : this._(total: Duration.zero);

  factory RestTimerState.started(DateTime now, Duration duration) =>
      RestTimerState._(total: duration, endsAt: now.add(duration));

  final Duration total;
  final DateTime? endsAt;
  final Duration? pausedRemaining;

  bool get isIdle => endsAt == null && pausedRemaining == null;
  bool get isPaused => pausedRemaining != null;

  Duration remaining(DateTime now) {
    if (pausedRemaining != null) return pausedRemaining!;
    if (endsAt == null) return Duration.zero;
    final left = endsAt!.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isFinished(DateTime now) => !isIdle && remaining(now) == Duration.zero;

  /// Fraction of the rest already elapsed, between 0 and 1.
  double progress(DateTime now) {
    if (isIdle || total == Duration.zero) return 0;
    final elapsed = 1 - remaining(now).inMilliseconds / total.inMilliseconds;
    return elapsed.clamp(0, 1).toDouble();
  }

  RestTimerState adjust(DateTime now, Duration delta) {
    if (isIdle) return this;
    final left = remaining(now) + delta;
    final clamped = left.isNegative ? Duration.zero : left;
    final total = this.total + delta;
    final newTotal = total < clamped ? clamped : total;
    if (isPaused) {
      return RestTimerState._(total: newTotal, pausedRemaining: clamped);
    }
    return RestTimerState._(total: newTotal, endsAt: now.add(clamped));
  }

  RestTimerState pause(DateTime now) =>
      isIdle || isPaused ? this : RestTimerState._(total: total, pausedRemaining: remaining(now));

  RestTimerState resume(DateTime now) =>
      !isPaused ? this : RestTimerState._(total: total, endsAt: now.add(pausedRemaining!));
}
