import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'services/rest_alarm.dart';
import 'services/sync/firebase_config.dart';
import 'services/sync/sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseConfig.initialize();
  final alarm = LocalNotificationRestAlarm();
  unawaited(alarm.init());

  final container = ProviderContainer(
    overrides: [
      restAlarmProvider.overrideWithValue(alarm),
      cloudBackendProvider.overrideWithValue(FirebaseCloudBackend(isAvailable: firebaseReady)),
    ],
  );
  // Catch up with changes made on other devices.
  if (firebaseReady) unawaited(container.read(syncControllerProvider.notifier).syncNow());

  runApp(UncontrolledProviderScope(container: container, child: const GymTrackerApp()));
}
