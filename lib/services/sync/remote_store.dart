/// Minimal document store the sync engine talks to. Implemented with
/// Firestore in production and in memory for tests.
///
/// The store stamps every written document with a server-assigned `syncedAt`
/// (ms since epoch). Pulling by `syncedAt` instead of the writer's own
/// `updatedAt` guarantees that a change uploaded late by another device is
/// still picked up.
abstract interface class RemoteStore {
  static const syncedAtField = 'syncedAt';

  Future<void> upsertAll(String collection, List<Map<String, Object?>> docs);

  /// Documents whose `syncedAt` is strictly after [cursor].
  Future<List<Map<String, Object?>>> changedSince(String collection, int? cursor);
}

class InMemoryRemoteStore implements RemoteStore {
  final Map<String, Map<String, Map<String, Object?>>> collections = {};
  int _serverTime = 0;

  @override
  Future<void> upsertAll(String collection, List<Map<String, Object?>> docs) async {
    final target = collections.putIfAbsent(collection, () => {});
    for (final doc in docs) {
      target[doc['id']! as String] = {...doc, RemoteStore.syncedAtField: ++_serverTime};
    }
  }

  @override
  Future<List<Map<String, Object?>>> changedSince(String collection, int? cursor) async {
    final docs = collections[collection]?.values ?? const [];
    return [
      for (final doc in docs)
        if (cursor == null || (doc[RemoteStore.syncedAtField]! as int) > cursor) Map.of(doc),
    ];
  }
}
