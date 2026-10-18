import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/rest_timer.dart';

class RestTimerView {
  const RestTimerView(this.timer, this.now, {this.nextUp});

  final RestTimerState timer;
  final DateTime now;
  final String? nextUp;

  bool get isActive => !timer.isIdle;
  Duration get remaining => timer.remaining(now);
  double get progress => timer.progress(now);
}

final restTimerProvider = NotifierProvider<RestTimerController, RestTimerView>(
  RestTimerController.new,
);

class RestTimerController extends Notifier<RestTimerView> {
  Timer? _ticker;

  DateTime _now() => ref.read(clockProvider)();

  @override
  RestTimerView build() {
    ref.onDispose(() => _ticker?.cancel());
    return RestTimerView(const RestTimerState.idle(), _now());
  }

  Future<void> start(Duration duration, {String? nextUp}) async {
    final now = _now();
    state = RestTimerView(RestTimerState.started(now, duration), now, nextUp: nextUp);
    _startTicker();
    await _scheduleAlarm();
  }

  Future<void> adjust(Duration delta) async {
    final now = _now();
    state = RestTimerView(state.timer.adjust(now, delta), now, nextUp: state.nextUp);
    if (state.timer.isFinished(now)) return _finish();
    await _scheduleAlarm();
  }

  Future<void> togglePause() async {
    final now = _now();
    final timer = state.timer.isPaused ? state.timer.resume(now) : state.timer.pause(now);
    state = RestTimerView(timer, now, nextUp: state.nextUp);
    if (timer.isPaused) {
      await ref.read(restAlarmProvider).cancel();
    } else {
      await _scheduleAlarm();
    }
  }

  Future<void> skip() async {
    _ticker?.cancel();
    state = RestTimerView(const RestTimerState.idle(), _now());
    await ref.read(restAlarmProvider).cancel();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final now = _now();
    if (state.timer.isFinished(now)) {
      _finish();
    } else {
      state = RestTimerView(state.timer, now, nextUp: state.nextUp);
    }
  }

  void _finish() {
    _ticker?.cancel();
    HapticFeedback.heavyImpact();
    state = RestTimerView(const RestTimerState.idle(), _now());
  }

  Future<void> _scheduleAlarm() async {
    final settings = ref.read(settingsProvider).value;
    final alarm = ref.read(restAlarmProvider);
    if (settings?.restNotifications == false) return;
    await alarm.schedule(state.remaining, nextUp: state.nextUp);
  }
}
