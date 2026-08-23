import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/dummy_data.dart';
import '../data/mock/mock_day_20aug.dart';
import '../data/mock/mock_goals.dart';
import '../models/goal.dart';
import '../models/goal_planned_blocks.dart';
import '../models/goal_progress.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';
import 'day_view_providers.dart';

class GoalsNotifier extends StateNotifier<List<Goal>> {
  GoalsNotifier() : super([...mockGoals, ...dummyGoals]);

  void addGoal(Goal goal) => state = [...state, goal];

  void updateGoal(Goal updated) => state = [
        for (final goal in state)
          if (goal.id == updated.id) updated else goal,
      ];

  void removeGoal(String id) =>
      state = state.where((goal) => goal.id != id).toList();
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<Goal>>(
  (ref) => GoalsNotifier(),
);

/// Actual hours this week = the canonical baseline from the handoff's ledger
/// (see [mockGoalActualHours]) plus anything logged since — any tracked
/// block that isn't one of the original seed blocks, so newly logged
/// activity (via Log activity or the Day view) is reflected without
/// double-counting the blocks already folded into the baseline.
double _actualHoursForGoal(
  Goal goal,
  List<TrackedBlock> allTracked,
  DateTime selectedDate,
) {
  final baseline = mockGoalActualHours[goal.categoryId] ?? 0;
  final weekStart = weekStartFor(selectedDate);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final addedHours = allTracked
      .where((b) =>
          b.categoryId == goal.categoryId &&
          !mockTrackedBlocks.contains(b) &&
          !b.start.isBefore(weekStart) &&
          b.start.isBefore(weekEnd))
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
  return baseline + addedHours;
}

/// Planned hours this week = manually planned blocks in this goal's category
/// (seed data plus anything added since) plus the goal's own generated
/// schedule for whichever days it was active this week — see
/// [goalGeneratedBlocksThisWeekProvider].
double _plannedHoursForGoal(
  Goal goal,
  List<PlannedBlock> allPlanned,
  List<PlannedBlock> generatedThisWeek,
  DateTime selectedDate,
) {
  final weekStart = weekStartFor(selectedDate);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final manualHours = allPlanned
      .where((b) =>
          b.categoryId == goal.categoryId &&
          !b.start.isBefore(weekStart) &&
          b.start.isBefore(weekEnd))
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
  final generatedHours = generatedThisWeek
      .where((b) => b.goalId == goal.id)
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
  return manualHours + generatedHours;
}

/// Goals list, filtered to only those active on [selectedDate] — a
/// date-bound goal (a challenge with a start/end date) simply doesn't show
/// up outside its window, the same way it wouldn't in a real habit tracker.
final activeGoalsProvider = Provider<List<Goal>>((ref) {
  final goals = ref.watch(goalsProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return goals.where((goal) => goal.isActiveOn(selectedDate)).toList();
});

/// Every goal's own schedule (duration or time-range mode), rendered as real
/// [PlannedBlock]s for each day of the week containing [selectedDateProvider]
/// — this is what makes a goal's schedule actually show up on the calendar,
/// in the Day view and in goal detail's activity list, rather than existing
/// only as a target number. Recomputed live from [goalsProvider], so
/// creating, editing, or deleting a goal is reflected immediately with no
/// separate sync step.
final goalGeneratedBlocksThisWeekProvider = Provider<List<PlannedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final weekStart = weekStartFor(selectedDate);
  final goals = ref.watch(goalsProvider);
  final manualPlanned = ref.watch(allPlannedBlocksProvider);

  final generated = <PlannedBlock>[];
  for (var i = 0; i < 7; i++) {
    final day = weekStart.add(Duration(days: i));
    final manualForDay = manualPlanned.where((b) => isSameDay(b.start, day)).toList();
    generated.addAll(generateGoalPlannedBlocksForDate(
      goals: goals,
      date: day,
      existingBlocksForDate: manualForDay,
    ));
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
        plannedHours: _plannedHoursForGoal(goal, allPlanned, generatedThisWeek, selectedDate),
        date: selectedDate,
      ),
  ];
});
