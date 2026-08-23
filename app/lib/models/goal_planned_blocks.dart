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
/// A day can hold more than one [DayScheduleEntry] — e.g. two time ranges
/// (a split shift) or several plain-duration chunks — and each becomes its
/// own block. Time-range entries place at their exact clock time.
/// Plain-duration entries have no fixed time, so they're placed greedily
/// starting at [dayStartHour], in a slot that doesn't overlap anything
/// already in [existingBlocksForDate] or already placed earlier that day
/// (by this goal or an earlier one).
List<PlannedBlock> generateGoalPlannedBlocksForDate({
  required List<Goal> goals,
  required DateTime date,
  required List<PlannedBlock> existingBlocksForDate,
  int dayStartHour = 6,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final weekday = day.weekday;
  final dateId = '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  final occupied = <(DateTime, DateTime)>[
    for (final b in existingBlocksForDate) (b.start, b.end),
  ];

  final generated = <PlannedBlock>[];

  // Time-range entries first — fixed clock times, no placement decision,
  // so they claim their slot in [occupied] before any duration entry (from
  // this goal or a later one) has to find a way around them.
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
      occupied.add((start, end));
    }
  }

  var cursor = DateTime(day.year, day.month, day.day, dayStartHour);
  for (final goal in goals) {
    if (goal.type != GoalType.target) continue;
    if (!goal.isActiveOn(day)) continue;
    var entryIndex = 0;
    for (final entry in goal.entriesForWeekday(weekday)) {
      final index = entryIndex++;
      if (entry.isTimeRange) continue;

      final start = _findNonOverlappingSlot(cursor, entry.duration!, occupied);
      final end = start.add(entry.duration!);
      generated.add(PlannedBlock(
        id: 'goal-${goal.id}-$dateId-$index',
        start: start,
        end: end,
        title: goal.name,
        categoryId: goal.categoryId,
        goalId: goal.id,
        isGoalAutoPlaced: true,
      ));
      occupied.add((start, end));
      cursor = end;
    }
  }

  return generated;
}

/// The earliest time at or after [earliest] where a block of [duration]
/// fits without overlapping any interval in [occupied] — checked as a
/// whole span, not just its start point, so e.g. a 4-hour block can't land
/// half-inside an existing 3-hour one just because its start was free.
DateTime _findNonOverlappingSlot(
  DateTime earliest,
  Duration duration,
  List<(DateTime, DateTime)> occupied,
) {
  var candidate = earliest;
  var restart = true;
  while (restart) {
    restart = false;
    final candidateEnd = candidate.add(duration);
    for (final (start, end) in occupied) {
      final overlaps = candidate.isBefore(end) && candidateEnd.isAfter(start);
      if (overlaps) {
        candidate = end;
        restart = true;
        break;
      }
    }
  }
  return candidate;
}
