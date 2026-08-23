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


/// Actual hours this week = tracked blocks in the goal's category that fall
/// within the current week.
double _actualHoursForGoal(
  Goal goal,
  List<TrackedBlock> allTracked,
  DateTime selectedDate,
) {
  final weekStart = weekStartFor(selectedDate);
  final weekEnd = weekStart.add(const Duration(days: 7));
  return allTracked
      .where((b) =>
          b.categoryId == goal.categoryId &&
          !b.start.isBefore(weekStart) &&
          b.start.isBefore(weekEnd))
      .fold(0.0, (total, b) => total + b.duration.inMinutes / 60);
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
    generated.addAll(generateGoalPlannedBlocksForDate(
      goals: goals,
      date: day,
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
