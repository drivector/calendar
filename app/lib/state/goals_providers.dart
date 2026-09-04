import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore/firestore_list_repository.dart';
import '../models/goal.dart';
import '../models/goal_planned_blocks.dart';
import '../models/goal_progress.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import 'day_view_providers.dart';
import 'firestore_providers.dart';

final goalsRepositoryProvider = Provider<FirestoreListRepository<Goal>>((ref) {
  return FirestoreListRepository<Goal>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'goals',
    fromMap: Goal.fromMap,
    toMap: (goal) => goal.toMap(),
    idOf: (goal) => goal.id,
  );
});

final goalsStreamProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsRepositoryProvider).watchAll();
});

/// The signed-in user's goals, live from Firestore — empty for a brand-new
/// account, and while the first snapshot is still loading.
final goalsProvider = Provider<List<Goal>>((ref) {
  return ref.watch(goalsStreamProvider).valueOrNull ?? [];
});

/// The goal a category counts toward, if any — still used where something
/// only has a category in hand and needs "which goal is this" (e.g.
/// coloring a goal-picker dropdown by its category). A category can in
/// principle back more than one goal, so the first match is it.
Goal? goalForCategory(List<Goal> goals, String categoryId) {
  for (final goal in goals) {
    if (goal.categoryId == categoryId) return goal;
  }
  return null;
}

/// The goal a [PlannedBlock]/[TrackedBlock]/[RunningActivity]'s own
/// [goalId] points at — the actual lookup every block's category now goes
/// through, since none of them store `categoryId` directly any more. `null`
/// only if the goal has since been hard-deleted out from under a block that
/// still references it (shouldn't happen in practice — a goal with linked
/// activities is deactivated, not deleted — but blocks reference goals by
/// id, not by a live object, so this stays a lookup rather than a
/// guarantee).
Goal? goalById(List<Goal> goals, String goalId) {
  for (final goal in goals) {
    if (goal.id == goalId) return goal;
  }
  return null;
}

/// The window actual/planned hours are summed over for one goal — the
/// current week for [GoalScheduleMode.weekly] (a repeating pattern only
/// ever means "this week's worth"), or the goal's own whole
/// [Goal.startDate]–[Goal.endDate] span for [GoalScheduleMode.byDate],
/// since a day-by-day challenge's progress is against the challenge
/// itself, not whichever calendar week the Day view happens to be showing.
(DateTime start, DateTime end) _progressWindowFor(
  Goal goal,
  DateTime selectedDate,
) {
  if (goal.scheduleMode == GoalScheduleMode.byDate) {
    final start = DateTime(
      goal.startDate.year,
      goal.startDate.month,
      goal.startDate.day,
    );
    final end = DateTime(
      goal.endDate.year,
      goal.endDate.month,
      goal.endDate.day,
    ).add(const Duration(days: 1));
    return (start, end);
  }
  final weekStart = weekStartFor(selectedDate);
  return (weekStart, weekStart.add(const Duration(days: 7)));
}

/// Actual hours toward this goal, within [_progressWindowFor]'s own
/// window = tracked blocks whose [TrackedBlock.goalId] matches, falling in
/// that window.
double _actualHoursForGoal(
  Goal goal,
  List<TrackedBlock> allTracked,
  DateTime selectedDate,
) {
  final (windowStart, windowEnd) = _progressWindowFor(goal, selectedDate);
  return allTracked
      .where(
        (b) =>
            b.goalId == goal.id &&
            !b.start.isBefore(windowStart) &&
            b.start.isBefore(windowEnd),
      )
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
}

/// Planned hours toward this goal, within [_progressWindowFor]'s own
/// window = manually planned blocks whose [PlannedBlock.goalId] matches
/// (seed data plus anything added since) plus the goal's own generated
/// schedule for whichever days of that window it was active.
///
/// [generatedThisWeek] (see [goalGeneratedBlocksThisWeekProvider]) only
/// ever covers the *current* week, which is exactly the window a
/// [GoalScheduleMode.weekly] goal needs here — but a
/// [GoalScheduleMode.byDate] goal's own window can span (or sit entirely
/// outside) the current week, so its generated blocks are recomputed
/// fresh over its own window instead of reusing that week-scoped list.
double _plannedHoursForGoal(
  Goal goal,
  List<PlannedBlock> allPlanned,
  List<PlannedBlock> generatedThisWeek,
  DateTime selectedDate,
) {
  final (windowStart, windowEnd) = _progressWindowFor(goal, selectedDate);
  final manualHours = allPlanned
      .where(
        (b) =>
            b.goalId == goal.id &&
            !b.start.isBefore(windowStart) &&
            b.start.isBefore(windowEnd),
      )
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);

  final generatedForWindow = goal.scheduleMode == GoalScheduleMode.byDate
      ? [
          for (
            var day = windowStart;
            day.isBefore(windowEnd);
            day = day.add(const Duration(days: 1))
          )
            ...generateGoalPlannedBlocksForDate(goals: [goal], date: day),
        ]
      : generatedThisWeek;
  final generatedHours = generatedForWindow
      .where((b) => b.goalId == goal.id)
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
  return manualHours + generatedHours;
}

/// Goals that haven't been deactivated (see [GoalLifecycleStatus]) — the filter
/// every goal-picker dropdown uses, and the base every other "which goals
/// should show up" provider below builds on. Distinct from
/// [activeGoalsProvider]'s "active" (which means active *on a date*,
/// unrelated to this status).
final statusActiveGoalsProvider = Provider<List<Goal>>((ref) {
  final goals = ref.watch(goalsProvider);
  return goals.where((goal) => goal.status == GoalLifecycleStatus.active).toList();
});

/// Goals list, filtered to only those not deactivated and active on
/// [selectedDate] — a date-bound goal (a challenge with a start/end date)
/// simply doesn't show up outside its window, the same way it wouldn't in
/// a real habit tracker.
final activeGoalsProvider = Provider<List<Goal>>((ref) {
  final goals = ref.watch(statusActiveGoalsProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return goals.where((goal) => goal.isActiveOn(selectedDate)).toList();
});

/// Every goal's own time-range schedule entries, rendered as real
/// [PlannedBlock]s for each day of the week containing [selectedDateProvider]
/// — this is what makes a goal like "work 9am-6pm" actually show up on the
/// calendar. Plain-duration entries never generate a block (see
/// [generateGoalPlannedBlocksForDate]) — they only count toward the goal's
/// weekly target. Recomputed live from [goalsProvider], so creating,
/// editing, or deleting a goal is reflected immediately with no separate
/// sync step.
final goalGeneratedBlocksThisWeekProvider = Provider<List<PlannedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final weekStart = weekStartFor(selectedDate);
  final goals = ref.watch(goalsProvider);

  final generated = <PlannedBlock>[];
  for (var i = 0; i < 7; i++) {
    final day = weekStart.add(Duration(days: i));
    generated.addAll(generateGoalPlannedBlocksForDate(goals: goals, date: day));
  }
  return generated;
});

/// The Day view's planned lane for [selectedDateProvider] — manually
/// entered blocks plus whatever the active goals' own schedules generate
/// for that day.
final dayViewPlannedBlocksProvider = Provider<List<PlannedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final manual = ref.watch(plannedBlocksProvider);
  final goalBlocks = ref
      .watch(goalGeneratedBlocksThisWeekProvider)
      .where((b) => isSameDay(b.start, selectedDate));
  return [...manual, ...goalBlocks]..sort((a, b) => a.start.compareTo(b.start));
});

/// One day's worth of planned + tracked blocks — the per-column unit the
/// Day view's multi-day timeline renders.
class DayBlocks {
  const DayBlocks({
    required this.date,
    required this.planned,
    required this.tracked,
  });

  final DateTime date;
  final List<PlannedBlock> planned;
  final List<TrackedBlock> tracked;
}

/// The timeline's actual data source, for every visible column at once —
/// deliberately calls [generateGoalPlannedBlocksForDate] directly per date
/// rather than routing through [goalGeneratedBlocksThisWeekProvider], since
/// that provider only ever covers one Monday-anchored week: a 3-Day window
/// straddling two calendar weeks (e.g. starting on a Saturday) would
/// silently lose a goal's generated blocks for the day(s) in the next week.
final visibleDayBlocksProvider = Provider<List<DayBlocks>>((ref) {
  final dates = ref.watch(visibleDatesProvider);
  final goals = ref.watch(goalsProvider);
  final allPlanned = ref.watch(allPlannedBlocksProvider);
  final allTracked = ref.watch(allTrackedBlocksProvider);

  return [
    for (final date in dates)
      DayBlocks(
        date: date,
        planned:
            [
                ...allPlanned.where((b) => overlapsDay(b.start, b.end, date)),
                ...generateGoalPlannedBlocksForDate(goals: goals, date: date),
              ]
              ..sort((a, b) => a.start.compareTo(b.start)),
        // overlapsDay, not isSameDay — an overnight block (started one
        // evening, ending after midnight) needs to show up on both days
        // it touches, not just the one it started on. See overlapsDay's
        // own doc comment for the exact bug this fixes.
        tracked: allTracked
            .where((b) => overlapsDay(b.start, b.end, date))
            .toList(),
      ),
  ];
});

final goalProgressListProvider = Provider<List<GoalProgress>>((ref) {
  final goals = ref.watch(activeGoalsProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final allTracked = ref.watch(allTrackedBlocksProvider);
  final allPlanned = ref.watch(allPlannedBlocksProvider);
  final generatedThisWeek = ref.watch(goalGeneratedBlocksThisWeekProvider);

  return [
    for (final goal in goals)
      computeGoalProgress(
        goal: goal,
        actualHours: _actualHoursForGoal(goal, allTracked, selectedDate),
        plannedHours: _plannedHoursForGoal(
          goal,
          allPlanned,
          generatedThisWeek,
          selectedDate,
        ),
        date: selectedDate,
      ),
  ];
});
