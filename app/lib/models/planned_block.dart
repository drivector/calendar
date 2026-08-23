class PlannedBlock {
  const PlannedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.categoryId,
    this.sourceCalendarId,
    this.goalId,
    this.isGoalAutoPlaced = false,
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

  /// True only for a goal-generated block that came from a plain-duration
  /// entry with no fixed clock time — its position here is just wherever it
  /// happened to fit that day, not a real commitment, unlike a
  /// goal-generated block from a time-range entry (which has a genuine,
  /// user-set time and reads the same as a manual one).
  final bool isGoalAutoPlaced;

  Duration get duration => end.difference(start);
}
