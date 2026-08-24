import 'tracked_block.dart';

/// One calendar day's worth of [TrackedBlock]s — [blocks] is already
/// sorted by start time. [day] is date-only (no time-of-day component).
class DayActivityGroup {
  const DayActivityGroup({required this.day, required this.blocks});

  final DateTime day;
  final List<TrackedBlock> blocks;
}

/// Groups [blocks] by the calendar day they start on, most-recent-day
/// first, each day's own blocks in start-time order — the shape the
/// Activities screen renders directly as a day-sectioned list.
List<DayActivityGroup> groupTrackedBlocksByDay(List<TrackedBlock> blocks) {
  final byDay = <DateTime, List<TrackedBlock>>{};
  for (final block in blocks) {
    final day = DateTime(block.start.year, block.start.month, block.start.day);
    byDay.putIfAbsent(day, () => []).add(block);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      DayActivityGroup(
        day: day,
        blocks: byDay[day]!..sort((a, b) => a.start.compareTo(b.start)),
      ),
  ];
}
