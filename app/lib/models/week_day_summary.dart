import 'planned_block.dart';

/// One day's per-category hour breakdown for the Week view's stacked bars.
class WeekDaySummary {
  const WeekDaySummary({
    required this.date,
    required this.plannedHoursByCategory,
    required this.actualHoursByCategory,
    required this.untrackedHours,
    this.plannedBlocks = const [],
  });

  final DateTime date;
  final Map<String, double> plannedHoursByCategory;
  final Map<String, double> actualHoursByCategory;
  final double untrackedHours;

  /// The day's own clock-timed planned blocks (manually created and
  /// goal-generated) — lets the Capacity page draw its per-day bar in real
  /// chronological order instead of an arbitrary per-category stack. Excludes
  /// plain-duration goal entries, which have no real time to place them at.
  final List<PlannedBlock> plannedBlocks;

  double get totalPlannedHours =>
      plannedHoursByCategory.values.fold(0, (a, b) => a + b);

  double get totalActualHours =>
      actualHoursByCategory.values.fold(0, (a, b) => a + b);

  double get driftHours => totalActualHours - totalPlannedHours;
}
