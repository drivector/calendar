import 'clock_time.dart';
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
  final dateId =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  final generated = <PlannedBlock>[];
  for (final goal in goals) {
    if (goal.status != GoalLifecycleStatus.active) continue;
    if (!goal.isActiveOn(day)) continue;
    var entryIndex = 0;
    for (final entry in goal.entriesForOccurrence(day)) {
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
      // A genuinely overnight entry (e.g. a night-shift goal scheduled
      // 22:00–06:00) has its end time roll into the next calendar day —
      // GoalEditSheet's own overnight-confirmation prompt is what lets one
      // be saved deliberately, so this has to honor the same wrap-around
      // semantics ClockTime.difference already uses, or the resulting
      // block ends up with a negative duration (end time earlier in the
      // day than start) instead of the real elapsed time.
      final overnight = isOvernightRange(range.start, range.end);
      final end = DateTime(
        day.year,
        day.month,
        day.day,
        range.end.hour,
        range.end.minute,
      ).add(overnight ? const Duration(days: 1) : Duration.zero);
      generated.add(
        PlannedBlock(
          id: 'goal-${goal.id}-$dateId-$index',
          start: start,
          end: end,
          title: goal.name,
          goalId: goal.id,
          isGoalGenerated: true,
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
  List<PlannedBlock> manualBlocksForDate = const [],
}) {
  final byGoal = untimedPlannedDurationByGoalForDate(
    goals: goals,
    date: date,
    manualBlocksForDate: manualBlocksForDate,
  );
  final categoryByGoalId = {for (final goal in goals) goal.id: goal.categoryId};

  final totals = <String, Duration>{};
  for (final entry in byGoal.entries) {
    final categoryId = categoryByGoalId[entry.key];
    if (categoryId == null) continue;
    totals.update(
      categoryId,
      (total) => total + entry.value,
      ifAbsent: () => entry.value,
    );
  }
  return totals;
}

/// Same as [untimedPlannedDurationByCategoryForDate], but keyed by goal id
/// instead of category id — for callers (drift) that need to keep two
/// goals sharing a category separate rather than merging their untimed
/// time into one bucket.
///
/// [manualBlocksForDate] — the day's manually-created (non-goal-generated)
/// [PlannedBlock]s, if the caller has them handy — lets a goal's untimed
/// requirement count as met once the user hand-schedules real time against
/// it: a "walk, 30 min, any time" goal that gets a 3–3:30pm block placed on
/// it should read as 30 min less unscheduled, not as unscheduled *and*
/// planned simultaneously. Each manual block reduces its goal's own
/// untimed total (never below zero) by its duration; a block for a goal
/// with no untimed entry today, or more manual time than the goal owes, is
/// simply ignored rather than going negative or crediting another goal.
Map<String, Duration> untimedPlannedDurationByGoalForDate({
  required List<Goal> goals,
  required DateTime date,
  List<PlannedBlock> manualBlocksForDate = const [],
}) {
  final day = DateTime(date.year, date.month, date.day);

  final totals = <String, Duration>{};
  for (final goal in goals) {
    if (goal.status != GoalLifecycleStatus.active) continue;
    if (!goal.isActiveOn(day)) continue;
    for (final entry in goal.entriesForOccurrence(day)) {
      if (entry.isTimeRange) continue;
      totals.update(
        goal.id,
        (total) => total + entry.effectiveDuration,
        ifAbsent: () => entry.effectiveDuration,
      );
    }
  }

  for (final goalId in totals.keys.toList()) {
    final consumed = manualBlocksForDate
        .where((b) => !b.isGoalGenerated && b.goalId == goalId)
        .fold<Duration>(Duration.zero, (total, b) => total + b.duration);
    if (consumed == Duration.zero) continue;
    final remaining = totals[goalId]! - consumed;
    totals[goalId] = remaining.isNegative ? Duration.zero : remaining;
  }

  return totals;
}
