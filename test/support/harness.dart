import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/app.dart';
import 'package:gym_tracker/core/providers.dart';
import 'package:gym_tracker/data/db/app_database.dart';
import 'package:gym_tracker/services/rest_alarm.dart';
import 'package:gym_tracker/services/sync/remote_store.dart';
import 'package:gym_tracker/services/sync/sync_controller.dart';

import 'test_db.dart';

class RecordingRestAlarm implements RestAlarm {
  final scheduled = <Duration>[];
  int cancelled = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> schedule(Duration after, {String? nextUp}) async => scheduled.add(after);

  @override
  Future<void> cancel() async => cancelled++;
}

class FakeCloudBackend implements CloudBackend {
  FakeCloudBackend({this.isAvailable = true});

  final store = InMemoryRemoteStore();
  int connections = 0;

  @override
  final bool isAvailable;

  @override
  Future<({String userId, RemoteStore store})> connect() async {
    connections++;
    return (userId: 'test-user', store: store);
  }

  @override
  Future<void> disconnect() async {}
}

class TestApp {
  TestApp({AppDatabase? db, DateTime? now, CloudBackend? backend})
    : db = db ?? createTestDb(),
      clock = FakeClock(now ?? DateTime(2026, 10, 18, 10)),
      backend = backend ?? FakeCloudBackend(isAvailable: false);

  final AppDatabase db;
  final FakeClock clock;
  final CloudBackend backend;
  final alarm = RecordingRestAlarm();

  List<Override> get overrides => [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(clock.call),
    restAlarmProvider.overrideWithValue(alarm),
    cloudBackendProvider.overrideWithValue(backend),
  ];

  /// A container that is disposed, then its database closed, after the test.
  ProviderContainer container() {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return container;
  }

  Future<void> pump(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: home == null ? const GymTrackerApp() : GymTrackerApp(home: home),
      ),
    );
    await settle(tester);
    addTearDown(() async {
      // Unmount first so that streams are cancelled before the database closes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });
  }

  /// Lets database futures and streams complete, then settles animations.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }
}
