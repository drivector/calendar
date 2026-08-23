class PlannedBlock {
  const PlannedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.categoryId,
    this.sourceCalendarId,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String title;
  final String categoryId;
  final String? sourceCalendarId;

  Duration get duration => end.difference(start);
}
