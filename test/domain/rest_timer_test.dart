import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/domain/rest_timer.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  test('idle timer', () {
    const timer = RestTimerState.idle();
    expect(timer.isIdle, isTrue);
    expect(timer.remaining(t0), Duration.zero);
    expect(timer.isFinished(t0), isFalse);
    expect(timer.progress(t0), 0);
    expect(timer.adjust(t0, const Duration(seconds: 15)).isIdle, isTrue);
  });

  test('counts down from wall clock time', () {
    final timer = RestTimerState.started(t0, const Duration(seconds: 90));
    expect(timer.remaining(at(0)), const Duration(seconds: 90));
    expect(timer.remaining(at(30)), const Duration(seconds: 60));
    expect(timer.progress(at(45)), closeTo(0.5, 1e-9));
    expect(timer.isFinished(at(89)), isFalse);
    expect(timer.isFinished(at(90)), isTrue);
    expect(timer.remaining(at(500)), Duration.zero);
  });

  test('adding and removing time', () {
    final timer = RestTimerState.started(t0, const Duration(seconds: 60));
    final longer = timer.adjust(at(10), const Duration(seconds: 15));
    expect(longer.remaining(at(10)), const Duration(seconds: 65));
    expect(longer.total, const Duration(seconds: 75));

    final shorter = timer.adjust(at(50), const Duration(seconds: -15));
    expect(shorter.remaining(at(50)), Duration.zero);
    expect(shorter.isFinished(at(50)), isTrue);
  });

  test('pause freezes the countdown and resume continues it', () {
    final timer = RestTimerState.started(t0, const Duration(seconds: 60));
    final paused = timer.pause(at(20));
    expect(paused.isPaused, isTrue);
    expect(paused.remaining(at(1000)), const Duration(seconds: 40));
    expect(paused.pause(at(30)), same(paused));

    final adjusted = paused.adjust(at(30), const Duration(seconds: 15));
    expect(adjusted.isPaused, isTrue);
    expect(adjusted.remaining(at(30)), const Duration(seconds: 55));

    final resumed = paused.resume(at(100));
    expect(resumed.isPaused, isFalse);
    expect(resumed.remaining(at(110)), const Duration(seconds: 30));
    expect(timer.resume(at(5)), same(timer));
  });
}
