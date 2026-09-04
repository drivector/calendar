import 'goal.dart';
import 'planned_block.dart';
import 'tracked_block.dart';

/// Per-goal drift: tracked minus planned, signed. Grouped by goal rather
/// than category — a category can back more than one goal (e.g. "job" and
/// a "side project" both under "work"), and lumping their drift together
/// under one category row would hide which one is actually behind.
///
/// Every [PlannedBlock]/[TrackedBlock] carries a real [PlannedBlock.goalId]
/// /[TrackedBlock.goalId] now, so no category-based fallback lookup is
/// needed — [categoryId] here is just [goals]' own category for that goal,
/// resolved once and carried along for display.
class GoalDrift {
  const GoalDrift({required this.categoryId, required this.goalId, required this.delta});

  final String categoryId;
  final String goalId;

  /// Positive = tracked more than planned; negative = tracked less.
  final Duration delta;
}

List<GoalDrift> computeDrift({
  required List<PlannedBlock> planned,
  required List<TrackedBlock> tracked,
  List<Goal> goals = const [],
  // A goal's plain-duration schedule entries ("piano, 15 min, any time")
  // have no fixed clock time, so they never become a [PlannedBlock] (see
  // `generateGoalPlannedBlocksForDate`) — without this, that time would
  // silently never count as planned anywhere. Keyed by goal id (see
  // `untimedPlannedDurationByGoalForDate`), so it merges directly with the
  // per-goal totals built below.
  Map<String, Duration> untimedPlannedByGoal = const {},
}) {
  final categoryOfGoal = {for (final goal in goals) goal.id: goal.categoryId};

  final plannedTotals = <String, Duration>{};
  final trackedTotals = <String, Duration>{};

  void bucket(Map<String, Duration> totals, String goalId, Duration duration) {
    totals.update(
      goalId,
      (total) => total + duration,
      ifAbsent: () => duration,
    );
  }

  for (final block in planned) {
    bucket(plannedTotals, block.goalId, block.duration);
  }
  for (final entry in untimedPlannedByGoal.entries) {
    if (!categoryOfGoal.containsKey(entry.key)) {
      continue; // goal not in [goals] — nothing to key by
    }
    bucket(plannedTotals, entry.key, entry.value);
  }

  for (final block in tracked) {
    bucket(trackedTotals, block.goalId, block.duration);
  }

  final keys = {...plannedTotals.keys, ...trackedTotals.keys};

  return [
    for (final goalId in keys)
      if (categoryOfGoal.containsKey(goalId))
        GoalDrift(
          categoryId: categoryOfGoal[goalId]!,
          goalId: goalId,
          delta:
              (trackedTotals[goalId] ?? Duration.zero) -
              (plannedTotals[goalId] ?? Duration.zero),
        ),
  ];
}
