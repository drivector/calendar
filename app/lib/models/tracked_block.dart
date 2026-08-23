class TrackedBlock {
  const TrackedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.categoryId,
    required this.sourceId,
    this.confidence = 1.0,
    this.plannedBlockId,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String title;
  final String categoryId;

  /// e.g. "health", "jira", "calendar", "manual".
  final String sourceId;
  final double confidence;

  /// The [PlannedBlock.id] this resolves against, if any.
  final String? plannedBlockId;

  Duration get duration => end.difference(start);
}
