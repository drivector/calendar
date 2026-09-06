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
  // Untimed blocks ("piano, 15 min, any time") are skipped outright: with
  // no clock position they can't close a gap in the window, and they used
  // to close one wherever their fabricated span happened to land.
  final sorted = [for (final b in tracked) if (b.isTimed) b]
    ..sort((a, b) => a.start!.compareTo(b.start!));

  final gaps = <UntrackedGap>[];
  var cursor = windowStart;

  for (final block in sorted) {
    final blockStart = block.start!;
    final blockEnd = block.end!;
    if (blockStart.isAfter(cursor)) {
      final gapEnd = blockStart.isBefore(windowEnd) ? blockStart : windowEnd;
      if (gapEnd.difference(cursor) >= minDuration) {
        gaps.add(UntrackedGap(start: cursor, end: gapEnd));
      }
    }
    if (blockEnd.isAfter(cursor)) {
      cursor = blockEnd;
    }
  }

  if (windowEnd.isAfter(cursor) &&
      windowEnd.difference(cursor) >= minDuration) {
    gaps.add(UntrackedGap(start: cursor, end: windowEnd));
  }

  return gaps;
}
