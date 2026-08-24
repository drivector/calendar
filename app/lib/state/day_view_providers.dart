import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore/firestore_list_repository.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import 'firestore_providers.dart';

/// Which columns the day view shows — mirrors the header's
/// "Day | Plan + actual" segmented control.
enum DayLayer { actual, planAndActual }

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final selectedDateProvider = StateProvider<DateTime>((ref) => _today());

final dayLayerProvider = StateProvider<DayLayer>(
  (ref) => DayLayer.planAndActual,
);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final plannedBlocksRepositoryProvider =
    Provider<FirestoreListRepository<PlannedBlock>>((ref) {
      return FirestoreListRepository<PlannedBlock>(
        firestore: ref.watch(firestoreProvider),
        uid: ref.watch(currentUidProvider),
        collectionName: 'plannedBlocks',
        fromMap: PlannedBlock.fromMap,
        toMap: (block) => block.toMap(),
        idOf: (block) => block.id,
      );
    });

final trackedBlocksRepositoryProvider =
    Provider<FirestoreListRepository<TrackedBlock>>((ref) {
      return FirestoreListRepository<TrackedBlock>(
        firestore: ref.watch(firestoreProvider),
        uid: ref.watch(currentUidProvider),
        collectionName: 'trackedBlocks',
        fromMap: TrackedBlock.fromMap,
        toMap: (block) => block.toMap(),
        idOf: (block) => block.id,
      );
    });

final allPlannedBlocksStreamProvider = StreamProvider<List<PlannedBlock>>((
  ref,
) {
  return ref.watch(plannedBlocksRepositoryProvider).watchAll();
});

final allTrackedBlocksStreamProvider = StreamProvider<List<TrackedBlock>>((
  ref,
) {
  return ref.watch(trackedBlocksRepositoryProvider).watchAll();
});

/// Every planned/tracked block across all days — the Day view filters these
/// down to the selected day; Goals sums them across the current week.
final allPlannedBlocksProvider = Provider<List<PlannedBlock>>((ref) {
  return ref.watch(allPlannedBlocksStreamProvider).valueOrNull ?? [];
});

final allTrackedBlocksProvider = Provider<List<TrackedBlock>>((ref) {
  return ref.watch(allTrackedBlocksStreamProvider).valueOrNull ?? [];
});

final plannedBlocksProvider = Provider<List<PlannedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final all = ref.watch(allPlannedBlocksProvider);
  return all.where((b) => isSameDay(b.start, selectedDate)).toList();
});

final trackedBlocksProvider = Provider<List<TrackedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final all = ref.watch(allTrackedBlocksProvider);
  return all.where((b) => isSameDay(b.start, selectedDate)).toList();
});
