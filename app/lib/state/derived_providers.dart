import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drift.dart';
import '../models/goal_planned_blocks.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import 'day_view_providers.dart';
import 'goals_providers.dart';

/// The window "untracked" gaps are computed against — 07:00–18:00, not the
/// full 24h the timeline scrolls through. A calendar showing nothing
/// scheduled at 3am is normal; a giant "untracked" block there wouldn't be.
(DateTime start, DateTime end) dayWindowFor(DateTime date) {
  final start = DateTime(date.year, date.month, date.day, 7, 0);
  final end = DateTime(date.year, date.month, date.day, 18, 0);
  return (start, end);
}

// Both providers below read [dayViewPlannedBlocksProvider] (manual blocks
// plus whatever active goals' own time-range entries generate for the
// selected day — see that provider's own doc comment) rather than the
// narrower [plannedBlocksProvider], and add in [goalsProvider]'s
// plain-duration entries on top — otherwise a fully-scheduled goal with no
// *manually* created planned block (the normal case: nobody hand-plans a
// recurring goal) would silently show "planned 0m" and drift as if nothing
// had ever been planned for it at all.

final driftProvider = Provider<List<CategoryDrift>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final planned = ref.watch(dayViewPlannedBlocksProvider);
  final tracked = ref.watch(trackedBlocksProvider);
  final untimed = untimedPlannedDurationByCategoryForDate(
    goals: ref.watch(goalsProvider),
    date: selectedDate,
  );
  return computeDrift(
    planned: planned,
    tracked: tracked,
    untimedPlannedByCategory: untimed,
  );
});

/// Header totals — "planned 8 h 30 · tracked 7 h 20" — computed as real sums
/// over the mock data rather than hardcoded strings.
(Duration planned, Duration tracked) dayTotals(
  List<PlannedBlock> planned,
  List<TrackedBlock> tracked, {
  Duration untimedPlanned = Duration.zero,
}) {
  final plannedTotal =
      planned.fold<Duration>(
        Duration.zero,
        (total, b) => total + b.duration,
      ) +
      untimedPlanned;
  final trackedTotal = tracked.fold<Duration>(
    Duration.zero,
    (total, b) => total + b.duration,
  );
  return (plannedTotal, trackedTotal);
}

final dayTotalsProvider = Provider<(Duration planned, Duration tracked)>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final planned = ref.watch(dayViewPlannedBlocksProvider);
  final tracked = ref.watch(trackedBlocksProvider);
  final untimed = untimedPlannedDurationByCategoryForDate(
    goals: ref.watch(goalsProvider),
    date: selectedDate,
  ).values.fold<Duration>(Duration.zero, (total, d) => total + d);
  return dayTotals(planned, tracked, untimedPlanned: untimed);
});
