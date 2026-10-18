import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/providers.dart';
import 'package:gym_tracker/services/sync/sync_controller.dart';

import '../support/harness.dart';

void main() {
  test('sync is unavailable without a Firebase project', () async {
    final app = TestApp();
    final container = app.container();
    expect(container.read(syncControllerProvider).phase, SyncPhase.unavailable);
    await container.read(syncControllerProvider.notifier).setEnabled(true);
    expect((await container.read(settingsRepositoryProvider).get()).cloudSync, isFalse);
  });

  test('enabling sync uploads data and stores the cursors', () async {
    final backend = FakeCloudBackend();
    final app = TestApp(backend: backend);
    final container = app.container();
    final sub = container.listen(syncControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(settingsProvider.future);
    expect(container.read(syncControllerProvider).phase, SyncPhase.disabled);

    await container.read(syncControllerProvider.notifier).setEnabled(true);
    final status = container.read(syncControllerProvider);
    expect(status.phase, SyncPhase.idle);
    expect(status.userId, 'test-user');
    expect(status.lastSyncedAt, app.clock.now);
    expect(backend.store.collections['exercises'], isNotEmpty);

    final settings = await container.read(settingsRepositoryProvider).get();
    expect(settings.cloudSync, isTrue);
    expect(settings.lastSyncedAt, app.clock.now);
    expect(settings.remoteCursor, isNull, reason: 'nothing was pulled from an empty cloud');

    await container.read(syncControllerProvider.notifier).syncNow();
    expect(container.read(syncControllerProvider).message, startsWith('Pushed'));
    expect(backend.connections, 2);
    expect((await container.read(settingsRepositoryProvider).get()).remoteCursor, isNotNull);
  });

  test('syncNow does nothing while sync is disabled', () async {
    final backend = FakeCloudBackend();
    final app = TestApp(backend: backend);
    final container = app.container();
    await container.read(syncControllerProvider.notifier).syncNow();
    expect(backend.connections, 0);
  });
}
