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

// Both providers below read [visibleDayBlocksProvider] (manual blocks plus
// whatever active goals' own time-range entries generate, per visible day
// — see that provider's own doc comment) rather than the narrower
// [plannedBlocksProvider], and add in [goalsProvider]'s plain-duration
// entries on top — otherwise a fully-scheduled goal with no *manually*
// created planned block (the normal case: nobody hand-plans a recurring
// goal) would silently show "planned 0m" and drift as if nothing had ever
// been planned for it at all.

/// Drift across every day the Day view's timeline currently shows — see
/// [dayTotalsProvider]'s own doc comment, which this mirrors: the same bug
/// (only ever looking at [selectedDateProvider] alone, ignoring the other
/// visible columns in 3 Day/Working week/Week mode) applied here too.
final driftProvider = Provider<List<CategoryDrift>>((ref) {
  final dates = ref.watch(visibleDatesProvider);
  final dayBlocks = ref.watch(visibleDayBlocksProvider);
  final goals = ref.watch(goalsProvider);

  final planned = [for (final day in dayBlocks) ...day.planned];
  final tracked = [for (final day in dayBlocks) ...day.tracked];
  final untimed = <String, Duration>{};
  for (final date in dates) {
    for (final entry
        in untimedPlannedDurationByCategoryForDate(
          goals: goals,
          date: date,
        ).entries) {
      untimed.update(
        entry.key,
        (total) => total + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }
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

/// Header totals across every day the Day view's timeline currently shows
/// — [visibleDatesProvider] (1/3/5/7 days depending on the Day/3 Day/
/// Working week/Week mode), not just [selectedDateProvider] alone. A user
/// hit this directly: switching to 3 Day still showed only the selected
/// day's own planned/tracked total, reading as if the other two visible
/// columns weren't planned or tracked at all.
final dayTotalsProvider = Provider<(Duration planned, Duration tracked)>((ref) {
  final dates = ref.watch(visibleDatesProvider);
  final dayBlocks = ref.watch(visibleDayBlocksProvider);
  final goals = ref.watch(goalsProvider);

  var plannedTotal = Duration.zero;
  var trackedTotal = Duration.zero;
  for (final day in dayBlocks) {
    plannedTotal += day.planned.fold<Duration>(
      Duration.zero,
      (total, b) => total + b.duration,
    );
    trackedTotal += day.tracked.fold<Duration>(
      Duration.zero,
      (total, b) => total + b.duration,
    );
  }
  for (final date in dates) {
    plannedTotal += untimedPlannedDurationByCategoryForDate(
      goals: goals,
      date: date,
    ).values.fold<Duration>(Duration.zero, (total, d) => total + d);
  }
  return (plannedTotal, trackedTotal);
});
