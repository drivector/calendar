import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore/firestore_list_repository.dart';
import '../models/goal_progress.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import 'firestore_providers.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final selectedDateProvider = StateProvider<DateTime>((ref) => _today());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// How many day-columns the Day view's timeline shows at once — mirrors the
/// header's "Day | 3 Day | Working week | Week" segmented control.
enum DayViewMode { day, threeDay, workingWeek, week }

int windowSizeFor(DayViewMode mode) => switch (mode) {
  DayViewMode.day => 1,
  DayViewMode.threeDay => 3,
  DayViewMode.workingWeek => 5,
  DayViewMode.week => 7,
};

final dayViewModeProvider = StateProvider<DayViewMode>(
  (ref) => DayViewMode.day,
);

/// Whether the timeline compresses the full 24 hours to fit the screen at
/// once (no scrolling) instead of the normal fixed-height, scrollable
/// timeline. Off by default — the fixed scale reads more clearly for a
/// normal day; this is for glancing at the whole day's shape at once.
final dayViewFullDayProvider = StateProvider<bool>((ref) => false);

/// The dates the timeline currently shows, one per column — "3 Day" starts
/// at whatever day is selected; "Working week"/"Week" always anchor to the
/// Monday of the selected day's week (so which weekday within the week is
/// selected doesn't shift the visible window, matching how a normal
/// calendar app's week view behaves).
final visibleDatesProvider = Provider<List<DateTime>>((ref) {
  final mode = ref.watch(dayViewModeProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final anchor = switch (mode) {
    DayViewMode.day || DayViewMode.threeDay => selectedDate,
    DayViewMode.workingWeek || DayViewMode.week => weekStartFor(selectedDate),
  };
  return List.generate(windowSizeFor(mode), (i) => anchor.add(Duration(days: i)));
});

/// How far one "next/previous" step moves [selectedDateProvider] — the
/// whole window for Working week/Week (jumps a full week at a time, same
/// as any calendar app's week view), but just **one day** for 3 Day: a
/// sliding 3-day window, not a jump to a disjoint next set of three days.
/// Day mode's window is already 1, so stepping by it is the same thing
/// either way.
int stepSizeFor(DayViewMode mode) => switch (mode) {
  DayViewMode.day || DayViewMode.threeDay => 1,
  DayViewMode.workingWeek || DayViewMode.week => windowSizeFor(mode),
};

/// Steps [selectedDateProvider] by [stepSizeFor] the current view mode —
/// shared by the header's prev/next arrows and the timeline's own swipe
/// navigation so both always mean the same thing.
void stepDayViewWindow(WidgetRef ref, {required bool forward}) {
  final step = stepSizeFor(ref.read(dayViewModeProvider));
  final current = ref.read(selectedDateProvider);
  ref.read(selectedDateProvider.notifier).state = current.add(
    Duration(days: forward ? step : -step),
  );
}

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

/// Excludes soft-deleted blocks — the single point every screen reads
/// tracked blocks through, so deleting an activity (see
/// `softDeleteTrackedBlock` below) disappears everywhere at once without
/// each of Day view/Goals/Activities/Capacity needing its own filter.
final allTrackedBlocksProvider = Provider<List<TrackedBlock>>((ref) {
  return (ref.watch(allTrackedBlocksStreamProvider).valueOrNull ?? [])
      .where((b) => b.status != TrackedBlockStatus.deleted)
      .toList();
});

/// Deletes an activity without physically removing its Firestore document
/// — flips it to [TrackedBlockStatus.deleted] instead, which
/// [allTrackedBlocksProvider] then filters out everywhere. Confirm before
/// calling this; it doesn't ask on its own (see
/// `showConfirmDeleteDialog`, used by both places in the UI that call it).
Future<void> softDeleteTrackedBlock(WidgetRef ref, TrackedBlock block) {
  return ref
      .read(trackedBlocksRepositoryProvider)
      .upsert(block.copyWithStatus(TrackedBlockStatus.deleted));
}

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
