import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/data/mock/dummy_data.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/data/mock/mock_goals.dart';
import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';

import 'firestore_rules.dart';

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

/// Every document sitting under `users/<uid>/` in [firestore], checked
/// against the project's real `firestore.rules` — collection by collection,
/// field by field.
///
/// Call this after a test drives a real save flow. A widget test's fake
/// Firestore accepts absolutely any document, so "the write went through
/// and the block is on screen" proves nothing about whether production
/// would have accepted the same write: the categoryId/goalId rules mismatch
/// that made every new activity silently vanish passed the whole suite. See
/// [FirestoreRules] for why the rules can't simply be handed to
/// `FakeFirebaseFirestore` itself.
void expectWrittenDocsSatisfyRules(
  FakeFirebaseFirestore firestore, {
  required String uid,
}) {
  final rules = FirestoreRules.fromFile();
  final root = jsonDecode(firestore.dump()) as Map<String, dynamic>;
  final user =
      (root['users'] as Map<String, dynamic>?)?[uid] as Map<String, dynamic>?;
  if (user == null) return; // Nothing written yet.

  final problems = <String>[];
  for (final collection in user.entries) {
    final docs = collection.value as Map<String, dynamic>;
    for (final doc in docs.entries) {
      problems.addAll(
        rules
            .violations(collection.key, doc.value as Map<String, dynamic>)
            .map((v) => '${collection.key}/${doc.key} — $v'),
      );
    }
  }
  expect(
    problems,
    isEmpty,
    reason:
        'Firestore would have rejected these writes in production:\n'
        '${problems.join('\n')}',
  );
}


/// A signed-in account for a widget test, handed back together with the
/// [FakeFirebaseFirestore] sitting behind it.
///
/// The Firestore instance is the point: reading a saved block back through
/// a provider only proves the app can round-trip its own model, while the
/// raw document is what the deployed security rules actually judge. See
/// [expectWrittenDocsSatisfyRules].
class TestAccount {
  const TestAccount({
    required this.uid,
    required this.firestore,
    required this.overrides,
  });

  final String uid;
  final FakeFirebaseFirestore firestore;
  final List<Override> overrides;

  /// Every document currently in [collection], by document id.
  Future<Map<String, Map<String, dynamic>>> docsIn(String collection) async {
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection(collection)
        .get();
    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  /// Fails unless every document written so far would survive the real
  /// `firestore.rules`.
  void expectWritesWouldBeAccepted() =>
      expectWrittenDocsSatisfyRules(firestore, uid: uid);
}

/// The same seeded mock/dummy data [seededFirestore] provides, wired up as
/// a signed-in account.
Future<TestAccount> seededAccount({String uid = 'seeded-uid'}) async {
  final firestore = await seededFirestore(uid);
  return TestAccount(
    uid: uid,
    firestore: firestore,
    overrides: _overridesFor(uid, firestore, 'seeded@example.com'),
  );
}

/// One category and one goal, no blocks at all — the state a real account
/// is in immediately after onboarding, which is where "I added an activity
/// and nothing appeared" is at its most visible.
Future<TestAccount> onboardedEmptyAccount({
  String uid = 'onboarded-uid',
}) async {
  final firestore = FakeFirebaseFirestore();
  final userDoc = firestore.collection('users').doc(uid);
  const category = Category(
    id: 'cat-1',
    name: 'Work',
    color: Color(0xFF0278E7),
  );
  final goal = Goal(
    id: 'goal-1',
    name: 'Test goal',
    categoryId: category.id,
    startDate: DateTime(2020, 1, 1),
    endDate: DateTime(2099, 12, 31),
    scheduleByWeekday: {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
    },
  );
  await userDoc.collection('categories').doc(category.id).set(category.toMap());
  await userDoc.collection('goals').doc(goal.id).set(goal.toMap());

  return TestAccount(
    uid: uid,
    firestore: firestore,
    overrides: _overridesFor(uid, firestore, 'onboarded@example.com'),
  );
}

List<Override> _overridesFor(
  String uid,
  FakeFirebaseFirestore firestore,
  String email,
) => [
  firebaseAuthProvider.overrideWithValue(
    MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: email),
    ),
  ),
  firestoreProvider.overrideWithValue(firestore),
  selectedDateProvider.overrideWith((ref) => mockDay),
];
