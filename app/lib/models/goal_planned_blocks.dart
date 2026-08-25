import 'goal.dart';
import 'planned_block.dart';

/// Renders each active goal's own schedule as [PlannedBlock]s for one
/// specific [date] — this is what makes a goal like "work 9am-6pm" actually
/// show up as a planned block in the Day view. Nothing is ever stored for
/// this: an ongoing goal doesn't materialize hundreds of blocks up front,
/// it's recomputed fresh for whichever day is being looked at, so editing
/// or deleting the goal is reflected immediately with no separate sync step.
///
/// Only time-range entries generate a block, at their exact clock time — a
/// plain-duration entry ("piano, 15 min, any time") has no real time to
/// place it at, so it's left off the calendar entirely. It still counts
/// toward what's "planned" for the day, just not as a drawable block — see
/// [untimedPlannedDurationByCategoryForDate], its counterpart for exactly
/// that remaining time.
List<PlannedBlock> generateGoalPlannedBlocksForDate({
  required List<Goal> goals,
  required DateTime date,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final weekday = day.weekday;
  final dateId =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  final generated = <PlannedBlock>[];
  for (final goal in goals) {
    if (!goal.isActiveOn(day)) continue;
    var entryIndex = 0;
    for (final entry in goal.entriesForWeekday(weekday)) {
      final index = entryIndex++;
      if (!entry.isTimeRange) continue;
      final range = entry.timeRange!;
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        range.start.hour,
        range.start.minute,
      );
      final end = DateTime(
        day.year,
        day.month,
        day.day,
        range.end.hour,
        range.end.minute,
      );
      generated.add(
        PlannedBlock(
          id: 'goal-${goal.id}-$dateId-$index',
          start: start,
          end: end,
          title: goal.name,
          categoryId: goal.categoryId,
          goalId: goal.id,
        ),
      );
    }
  }

  return generated;
}

/// The other half of a day's planned time — every active goal's
/// plain-duration schedule entries for [date]'s weekday, summed per
/// category, since none of them generate a block (see
/// [generateGoalPlannedBlocksForDate]'s own doc comment for why). Feeds the
/// "planned" total and per-category drift so a goal like "walking, 30 min,
/// any time" still reads as planned even though it has no fixed slot on the
/// calendar — a category with only time-range entries simply doesn't
/// appear in the returned map.
Map<String, Duration> untimedPlannedDurationByCategoryForDate({
  required List<Goal> goals,
  required DateTime date,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final weekday = day.weekday;

  final totals = <String, Duration>{};
  for (final goal in goals) {
    if (!goal.isActiveOn(day)) continue;
    for (final entry in goal.entriesForWeekday(weekday)) {
      if (entry.isTimeRange) continue;
      totals.update(
        goal.categoryId,
        (total) => total + entry.effectiveDuration,
        ifAbsent: () => entry.effectiveDuration,
      );
    }
  }
  return totals;
}
