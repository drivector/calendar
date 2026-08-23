import 'goal.dart';
import 'planned_block.dart';

/// Renders each active goal's own schedule as [PlannedBlock]s for one
/// specific [date] — this is what makes a goal like "work 9am-6pm" actually
/// show up as a planned block in the Day view. Nothing is ever stored for
/// this: an ongoing goal doesn't materialize hundreds of blocks up front,
/// it's recomputed fresh for whichever day is being looked at, so editing
/// or deleting the goal is reflected immediately with no separate sync step.
///
/// Only [GoalType.target] goals generate a block — a [GoalType.cap] goal
/// (Meetings, Screen time, ...) is a ceiling you're trying to stay under,
/// not something you're planning to do, so scheduling it as a plan block
/// would misrepresent it.
///
/// Only time-range entries generate a block, at their exact clock time — a
/// plain-duration entry ("piano, 15 min, any time") has no real time to
/// place it at, so it's left off the calendar entirely and only counts
/// toward the goal's weekly target, not toward what's "planned" for any
/// particular day.
List<PlannedBlock> generateGoalPlannedBlocksForDate({
  required List<Goal> goals,
  required DateTime date,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final weekday = day.weekday;
  final dateId = '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  final generated = <PlannedBlock>[];
  for (final goal in goals) {
    if (goal.type != GoalType.target) continue;
    if (!goal.isActiveOn(day)) continue;
    var entryIndex = 0;
    for (final entry in goal.entriesForWeekday(weekday)) {
      final index = entryIndex++;
      if (!entry.isTimeRange) continue;
      final range = entry.timeRange!;
      final start = DateTime(day.year, day.month, day.day, range.start.hour, range.start.minute);
      final end = DateTime(day.year, day.month, day.day, range.end.hour, range.end.minute);
      generated.add(PlannedBlock(
        id: 'goal-${goal.id}-$dateId-$index',
        start: start,
        end: end,
        title: goal.name,
        categoryId: goal.categoryId,
        goalId: goal.id,
      ));
    }
  }

  return generated;
}
