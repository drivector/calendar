class PlannedBlock {
  const PlannedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.goalId,
    this.sourceCalendarId,
    this.isGoalGenerated = false,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? sourceCalendarId;

  /// Every planned block belongs to a goal — this is the source of truth
  /// for its category (look it up via `goalById` in
  /// `state/goals_providers.dart`, never a `categoryId` on this class
  /// directly). Set either by `generateGoalPlannedBlocksForDate` for a
  /// goal-derived block, or by whichever goal was picked in the add-block
  /// sheet for a manually added one.
  final String goalId;

  /// True only for an ephemeral block synthesized by
  /// `generateGoalPlannedBlocksForDate` — never persisted to Firestore, so
  /// never read back `true` from [fromMap]. Used to tell "this represents
  /// a goal's own recurring schedule, no standalone document to edit" apart
  /// from a real manually-added [PlannedBlock] document, now that every
  /// block (not just goal-generated ones) carries a [goalId].
  final bool isGoalGenerated;

  Duration get duration => end.difference(start);

  factory PlannedBlock.fromMap(String id, Map<String, dynamic> map) =>
      PlannedBlock(
        id: id,
        start: DateTime.parse(map['start'] as String),
        end: DateTime.parse(map['end'] as String),
        title: map['title'] as String,
        goalId: map['goalId'] as String,
        sourceCalendarId: map['sourceCalendarId'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'title': title,
    'sourceCalendarId': sourceCalendarId,
    'goalId': goalId,
  };
}
