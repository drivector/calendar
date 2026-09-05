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
  const GoalDrift({
    required this.categoryId,
    required this.goalId,
    required this.planned,
    required this.tracked,
  });

  final String categoryId;
  final String goalId;

  /// The two totals [delta] is the difference of, carried along rather
  /// than reduced away: the drift footer draws a bar of tracked-against-
  /// planned per goal, which a signed delta alone can't say anything
  /// about — "−30m" is the whole of a 30m goal but a rounding error on an
  /// 8h one.
  final Duration planned;
  final Duration tracked;

  /// Positive = tracked more than planned; negative = tracked less.
  Duration get delta => tracked - planned;
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
          planned: plannedTotals[goalId] ?? Duration.zero,
          tracked: trackedTotals[goalId] ?? Duration.zero,
        ),
  ];
}
