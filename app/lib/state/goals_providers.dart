import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/dummy_data.dart';
import '../data/mock/mock_day_20aug.dart';
import '../data/mock/mock_goals.dart';
import '../models/goal.dart';
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

/// Planned hours this week — there's no separate "planned" baseline the way
/// there is for actual hours, so this is purely the sum of [PlannedBlock]s
/// (seed data plus anything added since) in this goal's category.
double _plannedHoursForGoal(
  Goal goal,
  List<PlannedBlock> allPlanned,
  DateTime selectedDate,
) {
  final weekStart = weekStartFor(selectedDate);
  final weekEnd = weekStart.add(const Duration(days: 7));
  return allPlanned
      .where((b) =>
          b.categoryId == goal.categoryId &&
          !b.start.isBefore(weekStart) &&
          b.start.isBefore(weekEnd))
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
}

/// Goals list, filtered to only those active on [selectedDate] — a
/// date-bound goal (a challenge with a start/end date) simply doesn't show
/// up outside its window, the same way it wouldn't in a real habit tracker.
final activeGoalsProvider = Provider<List<Goal>>((ref) {
  final goals = ref.watch(goalsProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return goals.where((goal) => goal.isActiveOn(selectedDate)).toList();
});

final goalProgressListProvider = Provider<List<GoalProgress>>((ref) {
  final goals = ref.watch(activeGoalsProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final allTracked = ref.watch(allTrackedBlocksProvider);
  final allPlanned = ref.watch(allPlannedBlocksProvider);

  return [
    for (final goal in goals)
      computeGoalProgress(
        goal: goal,
        actualHours: _actualHoursForGoal(goal, allTracked, selectedDate),
        plannedHours: _plannedHoursForGoal(goal, allPlanned, selectedDate),
        date: selectedDate,
      ),
  ];
});
