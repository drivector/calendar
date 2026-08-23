import 'package:cloud_firestore/cloud_firestore.dart';

/// A live, per-user Firestore collection of [T] — the shared shape behind
/// categories, goals, planned blocks, and tracked blocks, which all read as
/// "the current user's list of X" and write as "create or replace one X by
/// id" / "delete one X by id".
class FirestoreListRepository<T> {
  FirestoreListRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String collectionName,
    required this.fromMap,
    required this.toMap,
    required this.idOf,
  }) : _collection = firestore.collection('users').doc(uid).collection(collectionName);

  final CollectionReference<Map<String, dynamic>> _collection;
  final T Function(String id, Map<String, dynamic> data) fromMap;
  final Map<String, dynamic> Function(T item) toMap;
  final String Function(T item) idOf;

  Stream<List<T>> watchAll() => _collection.snapshots().map(
        (snapshot) => [for (final doc in snapshot.docs) fromMap(doc.id, doc.data())],
      );

  Future<void> upsert(T item) => _collection.doc(idOf(item)).set(toMap(item));

  Future<void> remove(String id) => _collection.doc(id).delete();
}
