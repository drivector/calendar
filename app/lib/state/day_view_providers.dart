import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore/firestore_list_repository.dart';
import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import '../utils/day_range.dart';
import 'firestore_providers.dart';

// today()/isSameDay()/dayBounds()/overlapsDay() moved to
// utils/day_range.dart so the models can share the same overnight rule;
// re-exported here so every existing `day_view_providers.dart` import
// keeps resolving them unchanged.
export '../utils/day_range.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => today());

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
/// timeline. On by default — seeing the whole day's shape at once on
/// entry beats opening to a scroll position and having to reach for this
/// toggle to get the same glance.
final dayViewFullDayProvider = StateProvider<bool>((ref) => true);

/// Which kinds of blocks the Day view's timeline actually draws — lets the
/// calendar be decluttered down to just what's planned, just what's really
/// happened, or both together (the default). A display filter only: it
/// doesn't touch the legend's totals or the drift calculation, which stay
/// based on the full data regardless of what the grid currently shows.
enum DayViewBlockFilter { both, plannedOnly, registeredOnly }

final dayViewBlockFilterProvider = StateProvider<DayViewBlockFilter>(
  (ref) => DayViewBlockFilter.both,
);

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

/// Logs [duration] of real activity against [goal] on [date] in one call,
/// with no fixed clock time — the unscheduled dialog's own quick-log
/// checkmark, for a goal whose schedule entry never had a real slot to
/// begin with ("piano, 15 min, any time"), so there's nothing honest to
/// prefill a start/end from the way every other add-activity entry point
/// does.
///
/// Writes a [TrackedBlock.untimed], which carries [date] and [duration]
/// and genuinely no clock position — this used to fabricate a span ending
/// at noon on [date] and mark it with a flag, and the fabricated values
/// leaked into activity-list ordering, plan matching and (for anything
/// over 12 hours) which day the time was credited to.
Future<void> logUnscheduledGoalTime(
  WidgetRef ref, {
  required Goal goal,
  required DateTime date,
  required Duration duration,
}) {
  return ref
      .read(trackedBlocksRepositoryProvider)
      .upsert(
        TrackedBlock.untimed(
          id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
          day: date,
          duration: duration,
          title: goal.name,
          goalId: goal.id,
          sourceId: 'manual',
        ),
      );
}

final plannedBlocksProvider = Provider<List<PlannedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final all = ref.watch(allPlannedBlocksProvider);
  return all.where((b) => isSameDay(b.start, selectedDate)).toList();
});

final trackedBlocksProvider = Provider<List<TrackedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final all = ref.watch(allTrackedBlocksProvider);
  return all.where((b) => isSameDay(b.day, selectedDate)).toList();
});
