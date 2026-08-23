class PlannedBlock {
  const PlannedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.categoryId,
    this.sourceCalendarId,
    this.goalId,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String title;
  final String categoryId;
  final String? sourceCalendarId;

  /// Set when this block was derived from a goal's own schedule (see
  /// `generateGoalPlannedBlocksForDate`) rather than entered by hand — null
  /// for anything added via Log activity or tap-to-create in the Day view.
  final String? goalId;

  Duration get duration => end.difference(start);

  factory PlannedBlock.fromMap(String id, Map<String, dynamic> map) => PlannedBlock(
        id: id,
        start: DateTime.parse(map['start'] as String),
        end: DateTime.parse(map['end'] as String),
        title: map['title'] as String,
        categoryId: map['categoryId'] as String,
        sourceCalendarId: map['sourceCalendarId'] as String?,
        goalId: map['goalId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'title': title,
        'categoryId': categoryId,
        'sourceCalendarId': sourceCalendarId,
        'goalId': goalId,
      };
}
