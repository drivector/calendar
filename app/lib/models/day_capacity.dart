/// The tracked window's length in hours — matches `dayWindowFor`
/// (07:00–18:00) in `state/derived_providers.dart`, the same window the Day
/// view already uses to decide what counts as an "untracked" gap. Reused
/// here as the day's plannable capacity, so "available" means the same
/// thing across the app rather than introducing a second definition of a
/// normal day.
const double defaultCapacityWindowHours = 11;

/// One day's planned-vs-available breakdown, against a fixed capacity
/// window rather than a full 24h day — free time at 3am isn't "available"
/// in any useful sense.
class DayCapacity {
  const DayCapacity({
    required this.date,
    required this.plannedHours,
    required this.actualHours,
    this.windowHours = defaultCapacityWindowHours,
  });

  final DateTime date;
  final double plannedHours;
  final double actualHours;
  final double windowHours;

  /// Hours in the window not yet claimed by any planned block — clamped at
  /// zero once planning fills or exceeds the window.
  double get availableHours => (windowHours - plannedHours).clamp(0, windowHours);

  /// Planned time beyond the window itself, if any — a day can be
  /// scheduled past the window that "available" caps out at.
  double get overplannedHours => plannedHours > windowHours ? plannedHours - windowHours : 0;
}

DayCapacity computeDayCapacity({
  required DateTime date,
  required double plannedHours,
  required double actualHours,
  double windowHours = defaultCapacityWindowHours,
}) {
  return DayCapacity(
    date: date,
    plannedHours: plannedHours,
    actualHours: actualHours,
    windowHours: windowHours,
  );
}
