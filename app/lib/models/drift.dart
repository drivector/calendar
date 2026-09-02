import 'goal.dart';
import 'planned_block.dart';
import 'tracked_block.dart';

/// Per-goal drift: tracked minus planned, signed. Grouped by goal rather
/// than category — a category can back more than one goal (e.g. "job" and
/// a "side project" both under "work"), and lumping their drift together
/// under one category row would hide which one is actually behind.
///
/// A manually created [PlannedBlock] or a [TrackedBlock] only ever carries
/// a category, never a goal id (only a goal-generated [PlannedBlock] does
/// — see [PlannedBlock.goalId]), so [computeDrift] resolves those to
/// "whichever goal [goals] resolves that category to" — same first-match
/// rule as `goalForCategory` in `state/goals_providers.dart`, kept in sync
/// with the [categoryId]-scoped counting `_plannedHoursForGoal`/
/// `_actualHoursForGoal` in that file already use. A category with no goal
/// of its own (e.g. its goal was deleted) has [goalId] left null and falls
/// back to its own row, keyed and labeled by category instead.
class GoalDrift {
  const GoalDrift({required this.categoryId, this.goalId, required this.delta});

  final String categoryId;
  final String? goalId;

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
  String? goalIdForCategory(String categoryId) {
    for (final goal in goals) {
      if (goal.categoryId == categoryId) return goal.id;
    }
    return null;
  }

  final categoryOfGoal = {for (final goal in goals) goal.id: goal.categoryId};

  final plannedTotals = <String, Duration>{};
  final trackedTotals = <String, Duration>{};
  final categoryOfKey = <String, String>{};
  final goalOfKey = <String, String?>{};

  void bucket(
    Map<String, Duration> totals,
    String? goalId,
    String categoryId,
    Duration duration,
  ) {
    final key = goalId ?? categoryId;
    categoryOfKey[key] = categoryId;
    goalOfKey[key] = goalId;
    totals.update(key, (total) => total + duration, ifAbsent: () => duration);
  }

  for (final block in planned) {
    bucket(
      plannedTotals,
      block.goalId ?? goalIdForCategory(block.categoryId),
      block.categoryId,
      block.duration,
    );
  }
  for (final entry in untimedPlannedByGoal.entries) {
    final categoryId = categoryOfGoal[entry.key];
    if (categoryId == null) continue; // goal not in [goals] — nothing to key by
    bucket(plannedTotals, entry.key, categoryId, entry.value);
  }

  for (final block in tracked) {
    bucket(
      trackedTotals,
      goalIdForCategory(block.categoryId),
      block.categoryId,
      block.duration,
    );
  }

  final keys = {...plannedTotals.keys, ...trackedTotals.keys};

  return [
    for (final key in keys)
      GoalDrift(
        categoryId: categoryOfKey[key]!,
        goalId: goalOfKey[key],
        delta:
            (trackedTotals[key] ?? Duration.zero) -
            (plannedTotals[key] ?? Duration.zero),
      ),
  ];
}
