import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'firestore_remote_store.dart';
import 'remote_store.dart';
import 'sync_engine.dart';

enum SyncPhase { unavailable, disabled, idle, syncing, error }

class SyncStatus {
  const SyncStatus(this.phase, {this.lastSyncedAt, this.message, this.userId});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? message;
  final String? userId;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? message,
    String? userId,
  }) => SyncStatus(
    phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: message,
    userId: userId ?? this.userId,
  );
}

/// Connects the app to its cloud backend. Returns the remote store for the
/// signed-in user, signing in anonymously when needed.
abstract interface class CloudBackend {
  bool get isAvailable;
  Future<({String userId, RemoteStore store})> connect();
  Future<void> disconnect();
}

class FirebaseCloudBackend implements CloudBackend {
  const FirebaseCloudBackend({required this.isAvailable});

  @override
  final bool isAvailable;

  @override
  Future<({String userId, RemoteStore store})> connect() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    return (userId: user.uid, store: FirestoreRemoteStore(FirebaseFirestore.instance, user.uid));
  }

  @override
  Future<void> disconnect() async {}
}

final cloudBackendProvider = Provider<CloudBackend>(
  (ref) => const FirebaseCloudBackend(isAvailable: false),
);

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);

class SyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final backend = ref.watch(cloudBackendProvider);
    if (!backend.isAvailable) return const SyncStatus(SyncPhase.unavailable);
    // Follow the setting without rebuilding, which would reset an ongoing sync.
    ref.listen(settingsProvider, (_, next) {
      final settings = next.value;
      if (settings == null) return;
      if (!settings.cloudSync) {
        state = SyncStatus(SyncPhase.disabled, lastSyncedAt: settings.lastSyncedAt);
      } else if (state.phase == SyncPhase.disabled) {
        state = SyncStatus(SyncPhase.idle, lastSyncedAt: settings.lastSyncedAt);
      }
    });
    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.cloudSync) {
      return SyncStatus(SyncPhase.disabled, lastSyncedAt: settings?.lastSyncedAt);
    }
    return SyncStatus(SyncPhase.idle, lastSyncedAt: settings.lastSyncedAt);
  }

  Future<void> setEnabled(bool enabled) async {
    if (state.phase == SyncPhase.unavailable) return;
    await ref.read(settingsRepositoryProvider).setCloudSync(enabled);
    if (enabled) await syncNow();
  }

  Future<void> syncNow() async {
    final backend = ref.read(cloudBackendProvider);
    if (!backend.isAvailable || state.phase == SyncPhase.syncing) return;
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.get();
    if (!settings.cloudSync) return;

    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      final connection = await backend.connect();
      final result = await SyncEngine(
        ref.read(databaseProvider),
        connection.store,
        clock: ref.read(clockProvider),
      ).sync(SyncCursor(pushedUpTo: settings.lastSyncedAt, pulledUpTo: settings.remoteCursor));
      final pushedUpTo = result.cursor.pushedUpTo!;
      await settingsRepo.saveSyncCursor(
        pushedUpTo: pushedUpTo,
        pulledUpTo: result.cursor.pulledUpTo,
      );
      state = SyncStatus(
        SyncPhase.idle,
        lastSyncedAt: pushedUpTo,
        userId: connection.userId,
        message: 'Pushed ${result.pushed}, pulled ${result.pulled} changes',
      );
    } catch (error) {
      state = state.copyWith(phase: SyncPhase.error, message: '$error');
    }
  }
}
