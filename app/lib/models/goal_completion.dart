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
/// planned block when its [TrackedBlock.plannedBlockId] matches, so a
/// second tap (or a block the user already logged by hand) never
/// double-creates anything.
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
    ...allPlanned.where(
      (b) => b.categoryId == goal.categoryId && inWeek(b.start),
    ),
    ...generatedThisWeek.where((b) => b.goalId == goal.id),
  ];

  final coveredPlannedBlockIds = allTracked
      .map((b) => b.plannedBlockId)
      .whereType<String>()
      .toSet();

  return planned
      .where(
        (b) => !coveredPlannedBlockIds.contains(b.id) && b.end.isBefore(now),
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
      categoryId: block.categoryId,
      sourceId: 'auto',
      plannedBlockId: block.id,
    ),
];
