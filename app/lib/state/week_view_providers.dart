import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal_progress.dart';
import '../models/untracked_gap.dart';
import '../models/week_day_summary.dart';
import 'day_view_providers.dart';
import 'derived_providers.dart';

/// Live per-day breakdown for the week containing [selectedDateProvider] —
/// derived from the same planned/tracked block data the Day view uses, so
/// navigating to a different week shows that week's real activity (or an
/// honest empty day for one with nothing logged).
final weekDaySummariesProvider = Provider<List<WeekDaySummary>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final weekStart = weekStartFor(selectedDate);
  final allPlanned = ref.watch(allPlannedBlocksProvider);
  final allTracked = ref.watch(allTrackedBlocksProvider);

  double hoursOf(Duration d) => d.inMinutes / 60;

  Map<String, double> groupByCategory(Iterable<({String categoryId, Duration duration})> blocks) {
    final totals = <String, double>{};
    for (final b in blocks) {
      totals.update(b.categoryId, (h) => h + hoursOf(b.duration),
          ifAbsent: () => hoursOf(b.duration));
    }
    return totals;
  }

  return List<WeekDaySummary>.generate(7, (i) {
    final date = weekStart.add(Duration(days: i));

    final dayPlanned = allPlanned.where((b) => isSameDay(b.start, date)).toList();
    final dayTracked = allTracked.where((b) => isSameDay(b.start, date)).toList();

    final (windowStart, windowEnd) = dayWindowFor(date);
    final gaps = computeUntrackedGaps(
      tracked: dayTracked,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );

    return WeekDaySummary(
      date: date,
      plannedHoursByCategory: groupByCategory(
          dayPlanned.map((b) => (categoryId: b.categoryId, duration: b.duration))),
      actualHoursByCategory: groupByCategory(
          dayTracked.map((b) => (categoryId: b.categoryId, duration: b.duration))),
      untrackedHours: gaps.fold<double>(0, (t, g) => t + hoursOf(g.duration)),
    );
  });
});

final weekTotalsProvider = Provider<(double planned, double tracked)>((ref) {
  final days = ref.watch(weekDaySummariesProvider);
  final planned = days.fold<double>(0, (t, d) => t + d.totalPlannedHours);
  final tracked = days.fold<double>(0, (t, d) => t + d.totalActualHours);
  return (planned, tracked);
});
