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
    this.note,
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

  /// Free-text detail from the Log activity sheet's Note field — null when
  /// left blank, never an empty string.
  final String? note;

  Duration get duration => end.difference(start);

  factory TrackedBlock.fromMap(String id, Map<String, dynamic> map) =>
      TrackedBlock(
        id: id,
        start: DateTime.parse(map['start'] as String),
        end: DateTime.parse(map['end'] as String),
        title: map['title'] as String,
        categoryId: map['categoryId'] as String,
        sourceId: map['sourceId'] as String,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
        plannedBlockId: map['plannedBlockId'] as String?,
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'title': title,
    'categoryId': categoryId,
    'sourceId': sourceId,
    'confidence': confidence,
    'plannedBlockId': plannedBlockId,
    'note': note,
  };
}
