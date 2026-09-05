import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

import 'package:calendar_tracker/data/firestore/firestore_list_repository.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/state/categories_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';

/// Repository stand-ins for the two ways Firestore actually fails in
/// production, neither of which `FakeFirebaseFirestore` can produce on its
/// own: a write it rejects, and a read it refuses.
///
/// `DocumentReference` is sealed in `cloud_firestore`, so neither can be
/// faked at the Firestore level — overriding the repository provider is
/// the seam this app already uses for exactly this (see
/// `saveUserSettingsProvider`'s own doc comment).
FirebaseException _permissionDenied() => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
  message: 'The caller does not have permission.',
);

/// Reads normally; every write and delete is rejected.
class RejectingRepository<T> extends FirestoreListRepository<T> {
  RejectingRepository({
    required super.firestore,
    required super.uid,
    required super.collectionName,
    required super.fromMap,
    required super.toMap,
    required super.idOf,
  });

  @override
  Future<void> upsert(T item) => Future.error(_permissionDenied());

  @override
  Future<void> remove(String id) => Future.error(_permissionDenied());
}

/// The collection can't be read at all — what a missing or mismatched
/// rules block does to a live `snapshots()` stream.
class UnreadableRepository<T> extends FirestoreListRepository<T> {
  UnreadableRepository({
    required super.firestore,
    required super.uid,
    required super.collectionName,
    required super.fromMap,
    required super.toMap,
    required super.idOf,
  });

  @override
  Stream<List<T>> watchAll() => Stream<List<T>>.error(_permissionDenied());
}

final rejectingTrackedBlocks = trackedBlocksRepositoryProvider.overrideWith(
  (ref) => RejectingRepository<TrackedBlock>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'trackedBlocks',
    fromMap: TrackedBlock.fromMap,
    toMap: (block) => block.toMap(),
    idOf: (block) => block.id,
  ),
);

final rejectingPlannedBlocks = plannedBlocksRepositoryProvider.overrideWith(
  (ref) => RejectingRepository<PlannedBlock>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'plannedBlocks',
    fromMap: PlannedBlock.fromMap,
    toMap: (block) => block.toMap(),
    idOf: (block) => block.id,
  ),
);

final rejectingGoals = goalsRepositoryProvider.overrideWith(
  (ref) => RejectingRepository<Goal>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'goals',
    fromMap: Goal.fromMap,
    toMap: (goal) => goal.toMap(),
    idOf: (goal) => goal.id,
  ),
);

final rejectingCategories = categoriesRepositoryProvider.overrideWith(
  (ref) => RejectingRepository<Category>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'categories',
    fromMap: Category.fromMap,
    toMap: (category) => category.toMap(),
    idOf: (category) => category.id,
  ),
);

final unreadableTrackedBlocks = trackedBlocksRepositoryProvider.overrideWith(
  (ref) => UnreadableRepository<TrackedBlock>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'trackedBlocks',
    fromMap: TrackedBlock.fromMap,
    toMap: (block) => block.toMap(),
    idOf: (block) => block.id,
  ),
);

final unreadableGoals = goalsRepositoryProvider.overrideWith(
  (ref) => UnreadableRepository<Goal>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'goals',
    fromMap: Goal.fromMap,
    toMap: (goal) => goal.toMap(),
    idOf: (goal) => goal.id,
  ),
);
