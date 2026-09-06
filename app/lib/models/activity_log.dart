import 'tracked_block.dart';

/// One calendar day's worth of [TrackedBlock]s — [blocks] is already
/// sorted (see [groupTrackedBlocksByDay]). [day] is date-only (no
/// time-of-day component).
class DayActivityGroup {
  const DayActivityGroup({required this.day, required this.blocks});

  final DateTime day;
  final List<TrackedBlock> blocks;
}

/// Groups [blocks] by the calendar day they are credited to (see
/// [TrackedBlock.day]), most-recent-day first. Within a day, timed blocks
/// come first in start-time order, then untimed ones ("piano, 15 min, any
/// time") in id order — an untimed block has no clock position to sort by,
/// so it sits at the end of the day rather than being wedged into the
/// middle of the timeline by a placeholder value, which is exactly what
/// the old fabricated-noon span used to do here.
List<DayActivityGroup> groupTrackedBlocksByDay(List<TrackedBlock> blocks) {
  final byDay = <DateTime, List<TrackedBlock>>{};
  for (final block in blocks) {
    byDay.putIfAbsent(block.day, () => []).add(block);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      DayActivityGroup(
        day: day,
        blocks: byDay[day]!..sort(compareTrackedBlocksByTime),
      ),
  ];
}

/// Chronological order within a day: timed blocks first by start time,
/// then untimed ones by id (a stable tiebreak — they have no clock
/// position to order by). Shared by every list that shows a day's
/// activities, so they all agree on where an "any time" entry sits.
int compareTrackedBlocksByTime(TrackedBlock a, TrackedBlock b) {
  final aStart = a.start;
  final bStart = b.start;
  if (aStart != null && bStart != null) return aStart.compareTo(bStart);
  if (aStart != null) return -1;
  if (bStart != null) return 1;
  return a.id.compareTo(b.id);
}
