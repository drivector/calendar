/// One day's per-category hour breakdown for the Week view's stacked bars.
class WeekDaySummary {
  const WeekDaySummary({
    required this.date,
    required this.plannedHoursByCategory,
    required this.actualHoursByCategory,
    required this.untrackedHours,
  });

  final DateTime date;
  final Map<String, double> plannedHoursByCategory;
  final Map<String, double> actualHoursByCategory;
  final double untrackedHours;

  double get totalPlannedHours =>
      plannedHoursByCategory.values.fold(0, (a, b) => a + b);

  double get totalActualHours =>
      actualHoursByCategory.values.fold(0, (a, b) => a + b);

  double get driftHours => totalActualHours - totalPlannedHours;
}
