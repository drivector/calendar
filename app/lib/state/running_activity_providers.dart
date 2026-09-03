import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/running_activity.dart';
import '../models/tracked_block.dart';
import 'day_view_providers.dart';
import 'firestore_providers.dart';

/// A single per-user doc, not a list-repository collection — same pattern
/// as `userSettingsDocProvider`: there's only ever one activity running (or
/// none) at a time.
final runningActivityDocProvider =
    Provider<DocumentReference<Map<String, dynamic>>>((ref) {
      final firestore = ref.watch(firestoreProvider);
      final uid = ref.watch(currentUidProvider);
      return firestore
          .collection('users')
          .doc(uid)
          .collection('state')
          .doc('runningActivity');
    });

final runningActivityStreamProvider = StreamProvider<RunningActivity?>((ref) {
  return ref.watch(runningActivityDocProvider).snapshots().map((snapshot) {
    final data = snapshot.data();
    return data == null ? null : RunningActivity.fromMap(data);
  });
});

/// Live from Firestore, not any local/in-memory flag — this is what makes
/// "exit the app and find it running when you re-enter" work: on every
/// (re)launch this provider just reads the same doc back, same as any other
/// per-user Firestore state this app has.
final runningActivityProvider = Provider<RunningActivity?>((ref) {
  return ref.watch(runningActivityStreamProvider).valueOrNull;
});

Future<void> startActivity(
  WidgetRef ref, {
  required String goalId,
  required String categoryId,
  required String title,
}) {
  return ref
      .read(runningActivityDocProvider)
      .set(
        RunningActivity(
          startedAt: DateTime.now(),
          goalId: goalId,
          categoryId: categoryId,
          title: title,
        ).toMap(),
      );
}

/// Registers the run as a real [TrackedBlock] spanning [RunningActivity
/// .startedAt] to now, then clears the running-activity doc. A run stopped
/// within the same minute it started still registers a (very short) block
/// rather than being silently dropped — no minimum-duration guard, matching
/// every other manual entry point in this app.
Future<void> stopActivity(WidgetRef ref, RunningActivity running) async {
  final now = DateTime.now();
  await ref
      .read(trackedBlocksRepositoryProvider)
      .upsert(
        TrackedBlock(
          id: 'live-${running.startedAt.microsecondsSinceEpoch}',
          start: running.startedAt,
          end: now.isAfter(running.startedAt)
              ? now
              : running.startedAt.add(const Duration(minutes: 1)),
          title: running.title,
          categoryId: running.categoryId,
          sourceId: 'manual',
        ),
      );
  await ref.read(runningActivityDocProvider).delete();
}
