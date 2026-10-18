import 'package:cloud_firestore/cloud_firestore.dart';

import 'remote_store.dart';

/// Stores each table as a sub-collection of `users/{uid}`.
class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  /// Firestore rejects batches with more than 500 writes.
  static const _batchSize = 450;

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _firestore.collection('users').doc(_uid).collection(name);

  @override
  Future<void> upsertAll(String collection, List<Map<String, Object?>> docs) async {
    final ref = _collection(collection);
    for (var i = 0; i < docs.length; i += _batchSize) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(_batchSize)) {
        batch.set(ref.doc(doc['id']! as String), {
          ...doc,
          RemoteStore.syncedAtField: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<List<Map<String, Object?>>> changedSince(String collection, int? cursor) async {
    Query<Map<String, dynamic>> query = _collection(collection);
    if (cursor != null) {
      query = query.where(
        RemoteStore.syncedAtField,
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursor),
      );
    }
    final snapshot = await query.get(const GetOptions(source: Source.server));
    return [
      for (final doc in snapshot.docs)
        {
          ...doc.data(),
          RemoteStore.syncedAtField:
              (doc.data()[RemoteStore.syncedAtField] as Timestamp).millisecondsSinceEpoch,
        },
    ];
  }
}
