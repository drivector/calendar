import 'goal.dart';
import 'planned_block.dart';
import 'tracked_block.dart';

/// This goal's planned blocks (manual, in its category, plus its own
/// generated schedule) for the week starting [weekStart] that don't yet
/// have a matching tracked block and have already fully happened as of
/// [now] — what the goal list's "complete" button turns into real activity
/// in one tap. A block still in progress or entirely in the future is left
/// out: "complete" fills in what you actually did, not what you're merely
/// scheduled to do later. A [TrackedBlock] counts as already covering a
/// planned block when its [TrackedBlock.plannedBlockId] matches *or* when
/// it simply overlaps the plan for the same goal, so neither a second tap
/// nor a block the user already logged by hand double-creates anything.
List<PlannedBlock> pendingPlannedBlocksForGoal({
  required Goal goal,
  required List<PlannedBlock> allPlanned,
  required List<PlannedBlock> generatedThisWeek,
  required List<TrackedBlock> allTracked,
  required DateTime weekStart,
  required DateTime now,
}) {
  final weekEnd = weekStart.add(const Duration(days: 7));
  bool inWeek(DateTime start) =>
      !start.isBefore(weekStart) && start.isBefore(weekEnd);

  final planned = [
    ...allPlanned.where((b) => b.goalId == goal.id && inWeek(b.start)),
    ...generatedThisWeek.where((b) => b.goalId == goal.id),
  ];

  final coveredPlannedBlockIds = allTracked
      .map((b) => b.plannedBlockId)
      .whereType<String>()
      .toSet();

  // An entry logged by hand (or registered by Start/Stop) never carries a
  // [TrackedBlock.plannedBlockId] — nothing in the app sets one outside
  // this file — so the id set alone doesn't see it, and "complete" used to
  // create a second, identical block over the top of a slot the user had
  // already filled in themselves. Overlap is the same signal the rest of
  // the app already treats as "this tracked block corresponds to that
  // plan" (see [matchingPlannedBlockFor]).
  bool coveredByOverlap(PlannedBlock plan) => allTracked.any(
    (t) =>
        t.goalId == plan.goalId &&
        t.start.isBefore(plan.end) &&
        plan.start.isBefore(t.end),
  );

  return planned
      .where(
        (b) =>
            !coveredPlannedBlockIds.contains(b.id) &&
            !coveredByOverlap(b) &&
            b.end.isBefore(now),
      )
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// The [TrackedBlock]s that completing [pending] creates — exact copies of
/// each planned block's time/title/category. The id is derived from the
/// planned block's own id (not a timestamp), so tapping "complete" twice
/// before the first write round-trips just re-writes the same docs rather
/// than creating duplicates. `sourceId: 'auto'` marks these as filled in by
/// the "complete" button rather than typed by hand (`'manual'`) or read
/// from a device integration.
List<TrackedBlock> trackedBlocksCompletingPlan(List<PlannedBlock> pending) => [
  for (final block in pending)
    TrackedBlock(
      id: 'complete-${block.id}',
      start: block.start,
      end: block.end,
      title: block.title,
      goalId: block.goalId,
      sourceId: 'auto',
      plannedBlockId: block.id,
    ),
];
