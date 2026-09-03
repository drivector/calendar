/// One item's horizontal slot among others it overlaps in time — [columnIndex]
/// is which of [columnCount] equal-width side-by-side slots it occupies,
/// the same way a calendar app lays out simultaneous meetings next to each
/// other instead of stacking them directly on top of one another.
class OverlapSlot<T> {
  const OverlapSlot({
    required this.item,
    required this.columnIndex,
    required this.columnCount,
  });

  final T item;
  final int columnIndex;
  final int columnCount;
}

/// Lays [items] out so nothing overlapping in time shares a column — items
/// with no time overlap with anything else always get the full width
/// ([columnCount] 1); items that overlap one another split evenly across
/// as many columns as their own connected cluster's own peak concurrency
/// needs. This is the standard "connected clusters + greedy column
/// packing" calendar layout algorithm, without the further "expand into
/// unused space to the right" refinement real calendar apps sometimes add
/// — a column can end up narrower than strictly necessary if an item
/// sharing its cluster ends early, but nothing ever overlaps.
List<OverlapSlot<T>> layoutOverlaps<T>(
  Iterable<T> items,
  DateTime Function(T item) startOf,
  DateTime Function(T item) endOf,
) {
  final sorted = items.toList()
    ..sort((a, b) => startOf(a).compareTo(startOf(b)));
  final result = <OverlapSlot<T>>[];

  var i = 0;
  while (i < sorted.length) {
    // Grow the current cluster for as long as each next item starts
    // before the cluster's own running max end — a classic sweep-line
    // connected-component pass over sorted intervals.
    var clusterEnd = endOf(sorted[i]);
    var j = i + 1;
    while (j < sorted.length && startOf(sorted[j]).isBefore(clusterEnd)) {
      final end = endOf(sorted[j]);
      if (end.isAfter(clusterEnd)) clusterEnd = end;
      j++;
    }
    final cluster = sorted.sublist(i, j);

    // Greedy column assignment within the cluster: each item takes the
    // first column whose own last-placed item has already ended by this
    // item's start, or a brand new column if none is free yet.
    final columnEnds = <DateTime>[];
    final columnIndexByItem = <int>[];
    for (final item in cluster) {
      final start = startOf(item);
      var placed = -1;
      for (var c = 0; c < columnEnds.length; c++) {
        if (!start.isBefore(columnEnds[c])) {
          placed = c;
          break;
        }
      }
      if (placed == -1) {
        placed = columnEnds.length;
        columnEnds.add(endOf(item));
      } else {
        columnEnds[placed] = endOf(item);
      }
      columnIndexByItem.add(placed);
    }

    final columnCount = columnEnds.length;
    for (var k = 0; k < cluster.length; k++) {
      result.add(
        OverlapSlot(
          item: cluster[k],
          columnIndex: columnIndexByItem[k],
          columnCount: columnCount,
        ),
      );
    }
    i = j;
  }
  return result;
}
