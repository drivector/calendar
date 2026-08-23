import 'tracked_block.dart';

/// Derived, never stored — the complement of [TrackedBlock]s within a
/// day's active window, with a minimum-duration threshold applied.
class UntrackedGap {
  const UntrackedGap({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// Walks the sorted gaps between [tracked] blocks (and before/after the
/// window) and returns those at or above [minDuration].
List<UntrackedGap> computeUntrackedGaps({
  required List<TrackedBlock> tracked,
  required DateTime windowStart,
  required DateTime windowEnd,
  Duration minDuration = const Duration(minutes: 45),
}) {
  final sorted = [...tracked]..sort((a, b) => a.start.compareTo(b.start));

  final gaps = <UntrackedGap>[];
  var cursor = windowStart;

  for (final block in sorted) {
    if (block.start.isAfter(cursor)) {
      final gapEnd = block.start.isBefore(windowEnd) ? block.start : windowEnd;
      if (gapEnd.difference(cursor) >= minDuration) {
        gaps.add(UntrackedGap(start: cursor, end: gapEnd));
      }
    }
    if (block.end.isAfter(cursor)) {
      cursor = block.end;
    }
  }

  if (windowEnd.isAfter(cursor) &&
      windowEnd.difference(cursor) >= minDuration) {
    gaps.add(UntrackedGap(start: cursor, end: windowEnd));
  }

  return gaps;
}
