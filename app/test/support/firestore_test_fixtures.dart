import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:calendar_tracker/data/mock/dummy_data.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/data/mock/mock_goals.dart';
import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';

/// A [FakeFirebaseFirestore] pre-seeded under `users/{uid}/...` with the
/// same mock/dummy data the old in-memory providers used to boot with — a
/// real account starts empty; this is purely a test fixture so existing
/// screen/provider assertions ("Walk 45 m", specific per-category hours,
/// ...) still hold against the same numbers they always have.
Future<FakeFirebaseFirestore> seededFirestore(String uid) async {
  final firestore = FakeFirebaseFirestore();
  final userDoc = firestore.collection('users').doc(uid);
  await Future.wait([
    for (final category in [...mockCategories, ...dummyCategories])
      userDoc.collection('categories').doc(category.id).set(category.toMap()),
    for (final goal in [...mockGoals, ...dummyGoals])
      userDoc.collection('goals').doc(goal.id).set(goal.toMap()),
    for (final block in [...mockPlannedBlocks, ...dummyPlannedBlocks])
      userDoc.collection('plannedBlocks').doc(block.id).set(block.toMap()),
    for (final block in [...mockTrackedBlocks, ...dummyTrackedBlocks])
      userDoc.collection('trackedBlocks').doc(block.id).set(block.toMap()),
  ]);
  return firestore;
}
