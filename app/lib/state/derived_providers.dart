import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clock_time.dart';
import '../models/drift.dart';
import '../models/goal_planned_blocks.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import '../models/user_settings.dart';
import 'categories_providers.dart';
import 'day_view_providers.dart';
import 'goals_providers.dart';
import 'running_activity_providers.dart';
import 'user_settings_providers.dart';

/// The window(s) "untracked" gaps are computed against — not the full 24h
/// the timeline scrolls through by default, so a calendar showing nothing
/// scheduled at 3am doesn't automatically read as a giant "untracked" gap
/// there. [windows] is a day's [UserSettings.windowsForWeekday] result —
/// possibly more than one range (e.g. 06:00–09:00 and 17:00–22:00, skipping
/// a midday gap) — each converted to a real [start, end) pair on [date].
/// Defaults to [fullDayWindow], matching an account that's never
/// configured a narrower one.
List<(DateTime start, DateTime end)> dayWindowsFor(
  DateTime date, {
  List<ClockRange> windows = const [fullDayWindow],
}) {
  return [
    for (final window in windows)
      (
        DateTime(
          date.year,
          date.month,
          date.day,
          window.start.hour,
          window.start.minute,
        ),
        DateTime(
          date.year,
          date.month,
          date.day,
          window.end.hour,
          window.end.minute,
        ),
      ),
  ];
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
///
/// Future days (beyond [today]) are excluded — a day that hasn't happened
/// yet has nothing tracked against it, so it would always show up as fully
/// "behind" its plan rather than not-yet-due.
final driftProvider = Provider<List<GoalDrift>>((ref) {
  final cutoff = today();
  final dates = ref
      .watch(visibleDatesProvider)
      .where((date) => !date.isAfter(cutoff))
      .toList();
  final dayBlocks = ref
      .watch(visibleDayBlocksProvider)
      .where((day) => !day.date.isAfter(cutoff));
  final goals = ref.watch(goalsProvider);

  final planned = [for (final day in dayBlocks) ...day.planned];
  final tracked = [for (final day in dayBlocks) ...day.tracked];
  final dayBlocksByDate = {for (final day in dayBlocks) day.date: day};
  final untimed = <String, Duration>{};
  for (final date in dates) {
    final manualForDate =
        dayBlocksByDate[date]?.planned.where((b) => !b.isGoalGenerated).toList() ??
            const <PlannedBlock>[];
    for (final entry
        in untimedPlannedDurationByGoalForDate(
          goals: goals,
          date: date,
          manualBlocksForDate: manualForDate,
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
    goals: goals,
    untimedPlannedByGoal: untimed,
  );
});

/// Header totals — "planned 8 h 30 · registered 7 h 20" — computed as real
/// sums over the mock data rather than hardcoded strings.
(Duration planned, Duration registered) dayTotals(
  List<PlannedBlock> planned,
  List<TrackedBlock> registered, {
  Duration untimedPlanned = Duration.zero,
}) {
  final plannedTotal =
      planned.fold<Duration>(
        Duration.zero,
        (total, b) => total + b.duration,
      ) +
      untimedPlanned;
  final registeredTotal = registered.fold<Duration>(
    Duration.zero,
    (total, b) => total + b.duration,
  );
  return (plannedTotal, registeredTotal);
}

/// One entry per visible day, in [visibleDatesProvider] order — the same
/// planned/tracked/registered figures [dayTotalsProvider] reports, kept
/// per day rather than summed. The header's capacity bar draws one track
/// per entry, so in 3 Day/Working week/Week mode a day with nothing
/// logged reads as its own empty track instead of averaging away into the
/// week's total.
///
/// "unscheduled" isn't carried here: it's goal-targeted time with no slot
/// on the calendar at all, so it has no per-day track to fill — see
/// [dayTotalsProvider], which still reports it as one window-wide figure.
typedef VisibleDayTotals = ({
  DateTime date,
  Duration planned,
  Duration tracked,
  Duration registered,
});

final visibleDayTotalsProvider = Provider<List<VisibleDayTotals>>((ref) {
  final dayBlocks = ref.watch(visibleDayBlocksProvider);
  final settings = ref.watch(userSettingsProvider);

  return [
    for (final day in dayBlocks)
      (
        date: day.date,
        planned: day.planned.fold<Duration>(
          Duration.zero,
          (total, b) => total + b.duration,
        ),
        tracked: dayWindowsFor(
          day.date,
          windows: settings.windowsForWeekday(day.date.weekday),
        ).fold<Duration>(
          Duration.zero,
          (total, window) => total + window.$2.difference(window.$1),
        ),
        registered: day.tracked.fold<Duration>(
          Duration.zero,
          (total, b) => total + b.duration,
        ),
      ),
  ];
});

/// Header totals across every day the Day view's timeline currently shows
/// — [visibleDatesProvider] (1/3/5/7 days depending on the Day/3 Day/
/// Working week/Week mode), not just [selectedDateProvider] alone. A user
/// hit this directly: switching to 3 Day still showed only the selected
/// day's own planned/registered total, reading as if the other two visible
/// columns weren't planned or logged at all.
///
/// "tracked" in the header means the user's own configured tracking
/// window (see [UserSettings]) — how many hours count as trackable across
/// the visible days — not what's actually been logged; that's
/// [registered] (real [TrackedBlock]s, formerly what this header itself
/// called "tracked", before the window took that name).
///
/// "planned" only ever counts blocks with a real clock time on the
/// calendar — a manually planned block, or a goal's own time-range
/// schedule entry (see [generateGoalPlannedBlocksForDate]). A goal's
/// plain-duration entry ("piano, 15 min, any time") has no slot on the
/// calendar at all, so it's excluded from "planned" and counted in
/// [unscheduled] instead — goal-targeted time that hasn't been given a
/// fixed time yet. A user hit this directly: an untimed goal minute
/// silently inflating "planned" past what the visible blocks on the
/// calendar actually added up to, reading as a miscalculation.
final dayTotalsProvider =
    Provider<
      (
        Duration planned,
        Duration tracked,
        Duration registered,
        Duration unscheduled,
      )
    >((ref) {
      final perDay = ref.watch(visibleDayTotalsProvider);
      final dayBlocks = ref.watch(visibleDayBlocksProvider);
      final goals = ref.watch(goalsProvider);

      var plannedTotal = Duration.zero;
      var windowTotal = Duration.zero;
      var registeredTotal = Duration.zero;
      for (final day in perDay) {
        plannedTotal += day.planned;
        windowTotal += day.tracked;
        registeredTotal += day.registered;
      }
      var unscheduledTotal = Duration.zero;
      for (final day in dayBlocks) {
        unscheduledTotal += untimedPlannedDurationByCategoryForDate(
          goals: goals,
          date: day.date,
          manualBlocksForDate:
              day.planned.where((b) => !b.isGoalGenerated).toList(),
        ).values.fold<Duration>(Duration.zero, (total, d) => total + d);
      }
      return (plannedTotal, windowTotal, registeredTotal, unscheduledTotal);
    });

/// [dayTotalsProvider]'s own `unscheduled` figure, broken down per goal
/// rather than summed into one total — the exact goal-level breakdown the
/// legend's "unscheduled" popup lists. Keyed by goal id (not category), so
/// two goals sharing a category never merge into one row.
final unscheduledByGoalProvider = Provider<Map<String, Duration>>((ref) {
  final dayBlocks = ref.watch(visibleDayBlocksProvider);
  final goals = ref.watch(goalsProvider);

  final totals = <String, Duration>{};
  for (final day in dayBlocks) {
    final manualForDate =
        day.planned.where((b) => !b.isGoalGenerated).toList();
    for (final entry
        in untimedPlannedDurationByGoalForDate(
          goals: goals,
          date: day.date,
          manualBlocksForDate: manualForDate,
        ).entries) {
      totals.update(
        entry.key,
        (total) => total + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }
  return totals;
});


/// True when any of the app's Firestore reads has actually failed — a
/// permission-denied on a collection, say, which this app has shipped
/// twice (the settings collection, then the live-activity state doc).
///
/// Every list provider turns an errored stream into an empty list, so
/// without this a failed read looks exactly like a brand-new account with
/// nothing in it: no error, no retry, just an empty calendar. A single
/// document that can't be parsed is *not* this — the repository skips it
/// and keeps the rest (see `FirestoreListRepository.watchAll`), so this
/// stays false for one stale row.
final firestoreReadFailedProvider = Provider<bool>((ref) {
  bool failed(AsyncValue<Object?> value) => value.hasError;
  return failed(ref.watch(categoriesStreamProvider)) ||
      failed(ref.watch(goalsStreamProvider)) ||
      failed(ref.watch(allPlannedBlocksStreamProvider)) ||
      failed(ref.watch(allTrackedBlocksStreamProvider)) ||
      failed(ref.watch(userSettingsStreamProvider)) ||
      failed(ref.watch(runningActivityStreamProvider));
});
