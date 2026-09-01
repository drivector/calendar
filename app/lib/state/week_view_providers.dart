import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/day_capacity.dart';
import '../models/goal_progress.dart';
import '../models/untracked_gap.dart';
import '../models/week_day_summary.dart';
import 'day_view_providers.dart';
import 'derived_providers.dart';
import 'user_settings_providers.dart';

/// Live per-day breakdown for the week containing [selectedDateProvider] —
/// derived from the same planned/tracked block data the Day view uses, so
/// looking at a different week's Capacity page shows that week's real
/// activity (or an honest empty day for one with nothing logged). Backs
/// the Capacity page (`features/account/capacity_view.dart`) — there is
/// no "Week view" tab any more.
final weekDaySummariesProvider = Provider<List<WeekDaySummary>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final weekStart = weekStartFor(selectedDate);
  final allPlanned = ref.watch(allPlannedBlocksProvider);
  final allTracked = ref.watch(allTrackedBlocksProvider);
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

    final dayPlanned = allPlanned
        .where((b) => isSameDay(b.start, date))
        .toList();
    final dayTracked = allTracked
        .where((b) => isSameDay(b.start, date))
        .toList();

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
      plannedHoursByCategory: groupByCategory(
        dayPlanned.map((b) => (categoryId: b.categoryId, duration: b.duration)),
      ),
      actualHoursByCategory: groupByCategory(
        dayTracked.map((b) => (categoryId: b.categoryId, duration: b.duration)),
      ),
      untrackedHours: untrackedHours,
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
      computeDayCapacity(
        date: day.date,
        plannedHours: day.totalPlannedHours,
        actualHours: day.totalActualHours,
        windowHours: settings
            .windowsForWeekday(day.date.weekday)
            .fold<double>(0, (t, w) => t + w.duration.inMinutes / 60),
      ),
  ];
});
