import 'planned_block.dart';
import 'tracked_block.dart';

/// Per-category drift: tracked minus planned, signed.
class CategoryDrift {
  const CategoryDrift({required this.categoryId, required this.delta});

  final String categoryId;

  /// Positive = tracked more than planned; negative = tracked less.
  final Duration delta;
}

List<CategoryDrift> computeDrift({
  required List<PlannedBlock> planned,
  required List<TrackedBlock> tracked,
  // A goal's plain-duration schedule entries ("piano, 15 min, any time")
  // have no fixed clock time, so they never become a [PlannedBlock] (see
  // `generateGoalPlannedBlocksForDate`) — without this, that time would
  // silently never count as planned anywhere. Keyed by categoryId, same as
  // [plannedTotals] below, so the two merge directly.
  Map<String, Duration> untimedPlannedByCategory = const {},
}) {
  final plannedTotals = <String, Duration>{};
  for (final block in planned) {
    plannedTotals.update(
      block.categoryId,
      (total) => total + block.duration,
      ifAbsent: () => block.duration,
    );
  }
  for (final entry in untimedPlannedByCategory.entries) {
    plannedTotals.update(
      entry.key,
      (total) => total + entry.value,
      ifAbsent: () => entry.value,
    );
  }

  final trackedTotals = <String, Duration>{};
  for (final block in tracked) {
    trackedTotals.update(
      block.categoryId,
      (total) => total + block.duration,
      ifAbsent: () => block.duration,
    );
  }

  final categoryIds = {...plannedTotals.keys, ...trackedTotals.keys};

  return [
    for (final categoryId in categoryIds)
      CategoryDrift(
        categoryId: categoryId,
        delta:
            (trackedTotals[categoryId] ?? Duration.zero) -
            (plannedTotals[categoryId] ?? Duration.zero),
      ),
  ];
}
