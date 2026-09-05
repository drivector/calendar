import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clock_time.dart';
import '../models/day_capacity.dart';
import '../models/goal_planned_blocks.dart';
import '../models/goal_progress.dart';
import '../models/untracked_gap.dart';
import '../models/week_day_summary.dart';
import 'day_view_providers.dart';
import 'derived_providers.dart';
import 'goals_providers.dart';
import 'user_settings_providers.dart';

/// Live per-day breakdown for the week containing [selectedDateProvider] —
/// derived from the same planned/tracked block data the Day view uses, so
/// looking at a different week's Capacity page shows that week's real
/// activity (or an honest empty day for one with nothing logged). Backs
/// the Capacity page (`features/account/capacity_view.dart`) — there is
/// no "Week view" tab any more.
///
/// "Planned" here used to have to match what the Day view's own header
/// legend counts as planned, or the two screens silently disagreed — a
/// real gap a user hit directly: this used to read only
/// [allPlannedBlocksProvider] (manually created blocks), leaving out
/// everything a goal's own schedule generates (see
/// [generateGoalPlannedBlocksForDate] and
/// [untimedPlannedDurationByCategoryForDate]).
///
/// That's since deliberately diverged from `dayTotalsProvider` (the Day
/// view legend): the legend's "planned" now only counts blocks with a
/// real clock time, while this still folds a goal's untimed minutes in —
/// [_TimelineBar] on the Capacity page needs that combined figure to lay
/// its bar out (it packs untimed goal minutes in after the last timed
/// block, since there's no real position to give them). If the two ever
/// need to agree again, this is where to look.
final weekDaySummariesProvider = Provider<List<WeekDaySummary>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final weekStart = weekStartFor(selectedDate);
  final allPlanned = ref.watch(allPlannedBlocksProvider);
  final allTracked = ref.watch(allTrackedBlocksProvider);
  final goals = ref.watch(goalsProvider);
  final settings = ref.watch(userSettingsProvider);

  double hoursOf(Duration d) => d.inMinutes / 60;

  Map<String, double> groupByCategory(
    Iterable<({String categoryId, Duration duration})> blocks,
  ) {
    final totals = <String, double>{};
    for (final b in blocks) {
      totals.update(
        b.categoryId,
        (h) => h + hoursOf(b.duration),
        ifAbsent: () => hoursOf(b.duration),
      );
    }
    return totals;
  }

  return List<WeekDaySummary>.generate(7, (i) {
    final date = weekStart.add(Duration(days: i));

    final manualForDate = allPlanned
        .where((b) => isSameDay(b.start, date))
        .toList();
    final dayPlanned = [
      ...manualForDate,
      ...generateGoalPlannedBlocksForDate(goals: goals, date: date),
    ];
    final dayTracked = allTracked
        .where((b) => isSameDay(b.start, date))
        .toList();

    final plannedByCategory = groupByCategory(
      dayPlanned.map(
        (b) => (
          categoryId: goalById(goals, b.goalId)?.categoryId ?? '',
          duration: b.duration,
        ),
      ),
    );
    for (final entry
        in untimedPlannedDurationByCategoryForDate(
          goals: goals,
          date: date,
          manualBlocksForDate: manualForDate,
        ).entries) {
      plannedByCategory.update(
        entry.key,
        (h) => h + hoursOf(entry.value),
        ifAbsent: () => hoursOf(entry.value),
      );
    }

    // A day can have more than one tracking window now (see
    // UserSettings.windowsByWeekday) — untracked gaps are computed
    // separately within each and summed, rather than treating the day as
    // one span with a hole in it.
    final windows = dayWindowsFor(
      date,
      windows: settings.windowsForWeekday(date.weekday),
    );
    final untrackedHours = [
      for (final (windowStart, windowEnd) in windows)
        ...computeUntrackedGaps(
          tracked: dayTracked,
          windowStart: windowStart,
          windowEnd: windowEnd,
        ),
    ].fold<double>(0, (t, g) => t + hoursOf(g.duration));

    return WeekDaySummary(
      date: date,
      plannedHoursByCategory: plannedByCategory,
      actualHoursByCategory: groupByCategory(
        dayTracked.map(
          (b) => (
            categoryId: goalById(goals, b.goalId)?.categoryId ?? '',
            duration: b.duration,
          ),
        ),
      ),
      untrackedHours: untrackedHours,
      plannedBlocks: dayPlanned,
    );
  });
});

/// Each day of the week, reduced to planned-vs-available against the
/// user's own tracking window(s) for that weekday — the same per-day
/// planned/actual totals from [weekDaySummariesProvider], just paired with
/// how much open room is left. A day's total window is the sum of its own
/// (possibly several) ranges.
final weekDayCapacityProvider = Provider<List<DayCapacity>>((ref) {
  final days = ref.watch(weekDaySummariesProvider);
  final settings = ref.watch(userSettingsProvider);
  return [
    for (final day in days)
      _dayCapacityFor(day, settings.windowsForWeekday(day.date.weekday)),
  ];
});

DayCapacity _dayCapacityFor(WeekDaySummary day, List<ClockRange> windows) {
  final ranges = dayWindowsFor(day.date, windows: windows);
  DateTime? windowStart;
  DateTime? windowEnd;
  for (final (start, end) in ranges) {
    if (windowStart == null || start.isBefore(windowStart)) {
      windowStart = start;
    }
    if (windowEnd == null || end.isAfter(windowEnd)) windowEnd = end;
  }
  return computeDayCapacity(
    date: day.date,
    plannedHours: day.totalPlannedHours,
    actualHours: day.totalActualHours,
    windowHours: windows.fold<double>(
      0,
      (t, w) => t + w.duration.inMinutes / 60,
    ),
    plannedHoursByCategory: day.plannedHoursByCategory,
    plannedBlocks: day.plannedBlocks,
    windowStart: windowStart,
    windowEnd: windowEnd,
  );
}
