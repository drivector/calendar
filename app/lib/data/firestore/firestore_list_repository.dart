import 'package:cloud_firestore/cloud_firestore.dart';

/// The longest string this app writes to any Firestore field, mirroring
/// the `isReasonableString` cap in `firestore.rules` — a longer one is
/// rejected outright by the rules, so the input fields that feed a
/// document (an activity title, a goal or category name) limit themselves
/// to this rather than letting a paste produce a write that can only fail.
/// `test/firestore_rules_test.dart` asserts this still matches the
/// deployed rules.
const kMaxFieldLength = 500;

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
  }) : _collection = firestore
           .collection('users')
           .doc(uid)
           .collection(collectionName);

  final CollectionReference<Map<String, dynamic>> _collection;
  final T Function(String id, Map<String, dynamic> data) fromMap;
  final Map<String, dynamic> Function(T item) toMap;
  final String Function(T item) idOf;

  /// One unreadable document must not take the whole collection with it.
  /// `snapshots()` delivers every document at once, so a [fromMap] that
  /// throws on a single one — a row written before a schema change, say,
  /// which is exactly what a pre-`goalId` block is — used to error the
  /// entire stream; and every provider downstream turns a stream error
  /// into an empty list (`valueOrNull ?? []`). The visible result was an
  /// app with *no* data at all, silently, because of one stale row.
  ///
  /// Skipping the row it can't read keeps the other N-1 on screen. A
  /// genuine failure of the read itself (permission-denied, say) still
  /// errors the stream — see `firestoreReadFailedProvider`, which is what
  /// tells the user that rather than showing them an empty account.
  Stream<List<T>> watchAll() => _collection.snapshots().map((snapshot) {
    final items = <T>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(fromMap(doc.id, doc.data()));
      } catch (_) {
        continue;
      }
    }
    return items;
  });

  Future<void> upsert(T item) => _collection.doc(idOf(item)).set(toMap(item));

  Future<void> remove(String id) => _collection.doc(id).delete();
}
