import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Alerts the user when a rest period is over, even if the app is in the
/// background.
abstract interface class RestAlarm {
  Future<void> init();
  Future<void> schedule(Duration after, {String? nextUp});
  Future<void> cancel();
}

class NoopRestAlarm implements RestAlarm {
  const NoopRestAlarm();
  @override
  Future<void> init() async {}
  @override
  Future<void> schedule(Duration after, {String? nextUp}) async {}
  @override
  Future<void> cancel() async {}
}

class LocalNotificationRestAlarm implements RestAlarm {
  LocalNotificationRestAlarm([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 1001;
  static const _channel = AndroidNotificationDetails(
    'rest_timer',
    'Rest timer',
    channelDescription: 'Tells you when your rest between sets is over',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    enableVibration: true,
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  bool _exact = false;

  @override
  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _exact = await android?.canScheduleExactNotifications() ?? false;
    _ready = true;
  }

  @override
  Future<void> schedule(Duration after, {String? nextUp}) async {
    try {
      await init();
      await _plugin.cancel(id: _notificationId);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Rest is over 💪',
        body: nextUp == null ? 'Time for your next set.' : 'Next up: $nextUp',
        scheduledDate: tz.TZDateTime.now(tz.UTC).add(after),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: _exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      // Notifications are a nice-to-have: the in-app timer still works.
      debugPrint('Could not schedule rest notification: $error');
    }
  }

  @override
  Future<void> cancel() async {
    if (!_ready) return;
    await _plugin.cancel(id: _notificationId);
  }
}
