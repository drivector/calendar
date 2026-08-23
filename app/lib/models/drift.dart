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
}) {
  final plannedTotals = <String, Duration>{};
  for (final block in planned) {
    plannedTotals.update(
      block.categoryId,
      (total) => total + block.duration,
      ifAbsent: () => block.duration,
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
        delta: (trackedTotals[categoryId] ?? Duration.zero) -
            (plannedTotals[categoryId] ?? Duration.zero),
      ),
  ];
}
