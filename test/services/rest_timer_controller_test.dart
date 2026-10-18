import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/providers.dart';
import 'package:gym_tracker/data/repositories/settings_repository.dart';
import 'package:gym_tracker/features/workout/rest_timer_controller.dart';

import '../support/harness.dart';
import '../support/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeClock clock;
  late RecordingRestAlarm alarm;

  ProviderContainer create({AppSettings settings = const AppSettings()}) {
    clock = FakeClock(DateTime(2026, 10, 18, 10));
    alarm = RecordingRestAlarm();
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock.call),
        restAlarmProvider.overrideWithValue(alarm),
        settingsProvider.overrideWithValue(AsyncData(settings)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('counts down, schedules the alarm and goes idle when done', () {
    fakeAsync((async) {
      final container = create();
      final controller = container.read(restTimerProvider.notifier);
      controller.start(const Duration(seconds: 90), nextUp: 'Squat · set 2');
      async.flushMicrotasks();

      expect(container.read(restTimerProvider).isActive, isTrue);
      expect(container.read(restTimerProvider).remaining, const Duration(seconds: 90));
      expect(container.read(restTimerProvider).nextUp, 'Squat · set 2');
      expect(alarm.scheduled, [const Duration(seconds: 90)]);

      clock.advance(const Duration(seconds: 30));
      async.elapse(const Duration(milliseconds: 300));
      expect(container.read(restTimerProvider).remaining, const Duration(seconds: 60));
      expect(container.read(restTimerProvider).progress, closeTo(1 / 3, 1e-9));

      clock.advance(const Duration(seconds: 60));
      async.elapse(const Duration(milliseconds: 300));
      expect(container.read(restTimerProvider).isActive, isFalse);
      expect(async.periodicTimerCount, 0, reason: 'the ticker stops when idle');
    });
  });

  test('adjust reschedules, pause cancels the alarm, skip stops', () {
    fakeAsync((async) {
      final container = create();
      final controller = container.read(restTimerProvider.notifier);
      controller.start(const Duration(seconds: 60));
      async.flushMicrotasks();

      controller.adjust(const Duration(seconds: 15));
      async.flushMicrotasks();
      expect(alarm.scheduled.last, const Duration(seconds: 75));

      controller.togglePause();
      async.flushMicrotasks();
      expect(container.read(restTimerProvider).timer.isPaused, isTrue);
      expect(alarm.cancelled, 1);

      clock.advance(const Duration(minutes: 10));
      async.elapse(const Duration(seconds: 1));
      expect(container.read(restTimerProvider).remaining, const Duration(seconds: 75));

      controller.togglePause();
      async.flushMicrotasks();
      expect(alarm.scheduled.last, const Duration(seconds: 75));

      controller.skip();
      async.flushMicrotasks();
      expect(container.read(restTimerProvider).isActive, isFalse);
      expect(alarm.cancelled, 2);
    });
  });

  test('removing more time than left finishes the rest', () {
    fakeAsync((async) {
      final container = create();
      final controller = container.read(restTimerProvider.notifier);
      controller.start(const Duration(seconds: 10));
      async.flushMicrotasks();
      controller.adjust(const Duration(seconds: -15));
      async.flushMicrotasks();
      expect(container.read(restTimerProvider).isActive, isFalse);
    });
  });

  test('no alarm when rest notifications are disabled', () {
    fakeAsync((async) {
      final container = create(settings: const AppSettings(restNotifications: false));
      container.read(restTimerProvider.notifier).start(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(container.read(restTimerProvider).isActive, isTrue);
      expect(alarm.scheduled, isEmpty);
      container.read(restTimerProvider.notifier).skip();
    });
  });
}
