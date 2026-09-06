import 'clock_time.dart';
import 'goal.dart';
import 'planned_block.dart';
import 'tracked_block.dart';

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
///
/// [manualBlocksForDate] — [date]'s own manually-created (real,
/// Firestore-backed) planned blocks, if the caller already has them handy
/// — lets a single occurrence be edited without touching the goal's
/// recurring schedule: the add-block sheet saves that edit as a real
/// [PlannedBlock] document reusing this function's own deterministic id
/// (`goal-<goalId>-<dateId>-<index>`, see below) for that exact occurrence,
/// so once such a document exists, generating the *virtual* one for the
/// same slot on top of it would just double it up. A caller that doesn't
/// pass this (the default, `const []`) simply never sees an occurrence get
/// suppressed this way — fine for something like scheduling a reminder,
/// where a single day's one-off edit isn't worth threading through.
List<PlannedBlock> generateGoalPlannedBlocksForDate({
  required List<Goal> goals,
  required DateTime date,
  List<PlannedBlock> manualBlocksForDate = const [],
}) {
  final day = DateTime(date.year, date.month, date.day);
  final dateId =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  final overriddenIds = manualBlocksForDate.map((b) => b.id).toSet();

  final generated = <PlannedBlock>[];
  for (final goal in goals) {
    if (goal.status != GoalLifecycleStatus.active) continue;
    if (!goal.isActiveOn(day)) continue;
    var entryIndex = 0;
    for (final entry in goal.entriesForOccurrence(day)) {
      final index = entryIndex++;
      if (!entry.isTimeRange) continue;
      if (overriddenIds.contains('goal-${goal.id}-$dateId-$index')) continue;
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
  List<TrackedBlock> trackedBlocksForDate = const [],
}) {
  final byGoal = untimedPlannedDurationByGoalForDate(
    goals: goals,
    date: date,
    manualBlocksForDate: manualBlocksForDate,
    trackedBlocksForDate: trackedBlocksForDate,
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
///
/// [trackedBlocksForDate] — the day's real [TrackedBlock]s for the same
/// caller, if it has them — does the same for time actually *done*, not
/// just scheduled: a "walk, 30 min, any time" goal with a 30-min activity
/// already logged against it (with or without ever getting a manual
/// planned block first) reads as 30 min less unscheduled too, not as
/// unscheduled *and* done. A manual block a tracked block already overlaps
/// only has the tracked block's own duration counted — not both — since
/// they represent the same stretch of time; only a manual block still
/// waiting on its own tracked counterpart counts separately, as time
/// that's scheduled but not yet actually done.
///
/// Deliberately not threaded into every caller: [driftProvider] passes
/// neither, since its own "planned" total already means *committed*
/// (scheduled-or-owed) time and independently adds tracked time on top to
/// find drift — folding tracked consumption into the untimed figure there
/// too would shrink "planned" every time real time got logged, silently
/// erasing drift rather than measuring it.
Map<String, Duration> untimedPlannedDurationByGoalForDate({
  required List<Goal> goals,
  required DateTime date,
  List<PlannedBlock> manualBlocksForDate = const [],
  List<TrackedBlock> trackedBlocksForDate = const [],
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
    final trackedForGoal = trackedBlocksForDate.where(
      (b) => b.goalId == goalId,
    );
    // Untimed tracked blocks are skipped here for the same reason they
    // are in [pendingPlannedBlocksForGoal]: with no clock position, one
    // can't be said to overlap any particular plan. Their duration still
    // counts in [trackedConsumed] below.
    bool coveredByTracked(PlannedBlock plan) => trackedForGoal.any((t) {
      final start = t.start;
      final end = t.end;
      if (start == null || end == null) return false;
      return start.isBefore(plan.end) && plan.start.isBefore(end);
    });
    final manualConsumed = manualBlocksForDate
        .where(
          (b) =>
              !b.isGoalGenerated &&
              b.goalId == goalId &&
              !coveredByTracked(b),
        )
        .fold<Duration>(Duration.zero, (total, b) => total + b.duration);
    final trackedConsumed = trackedForGoal.fold<Duration>(
      Duration.zero,
      (total, b) => total + b.duration,
    );
    final consumed = manualConsumed + trackedConsumed;
    if (consumed == Duration.zero) continue;
    final remaining = totals[goalId]! - consumed;
    totals[goalId] = remaining.isNegative ? Duration.zero : remaining;
  }

  return totals;
}
