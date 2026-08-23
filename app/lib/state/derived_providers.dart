import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drift.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import '../models/untracked_gap.dart';
import 'day_view_providers.dart';

/// The window "untracked" gaps are computed against — 07:00–18:00, not the
/// full 24h the timeline scrolls through. A calendar showing nothing
/// scheduled at 3am is normal; a giant "untracked" block there wouldn't be.
(DateTime start, DateTime end) dayWindowFor(DateTime date) {
  final start = DateTime(date.year, date.month, date.day, 7, 0);
  final end = DateTime(date.year, date.month, date.day, 18, 0);
  return (start, end);
}

final untrackedGapsProvider = Provider<List<UntrackedGap>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final tracked = ref.watch(trackedBlocksProvider);
  final (windowStart, windowEnd) = dayWindowFor(selectedDate);
  return computeUntrackedGaps(
    tracked: tracked,
    windowStart: windowStart,
    windowEnd: windowEnd,
  );
});

final driftProvider = Provider<List<CategoryDrift>>((ref) {
  final planned = ref.watch(plannedBlocksProvider);
  final tracked = ref.watch(trackedBlocksProvider);
  return computeDrift(planned: planned, tracked: tracked);
});

/// Header totals — "planned 8 h 30 · tracked 7 h 20" — computed as real sums
/// over the mock data rather than hardcoded strings.
(Duration planned, Duration tracked) dayTotals(
  List<PlannedBlock> planned,
  List<TrackedBlock> tracked,
) {
  final plannedTotal = planned.fold<Duration>(
    Duration.zero,
    (total, b) => total + b.duration,
  );
  final trackedTotal = tracked.fold<Duration>(
    Duration.zero,
    (total, b) => total + b.duration,
  );
  return (plannedTotal, trackedTotal);
}

final dayTotalsProvider = Provider<(Duration planned, Duration tracked)>((ref) {
  final planned = ref.watch(plannedBlocksProvider);
  final tracked = ref.watch(trackedBlocksProvider);
  return dayTotals(planned, tracked);
});
