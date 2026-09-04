/// A currently in-progress activity — created by "Start", turned into a
/// real [TrackedBlock] and cleared by "Stop". Persisted as a single
/// Firestore doc (see `runningActivityDocProvider`) rather than any local
/// in-memory state, which is what lets it survive the app being closed and
/// reopened, or opened on another device signed into the same account.
/// Like [PlannedBlock]/[TrackedBlock], its category is looked up via
/// [goalId] (`goalById` in `state/goals_providers.dart`) rather than
/// stored here — a live run's displayed color can change if its goal is
/// edited mid-run, a deliberate tradeoff for one consistent source of
/// truth over the resilience a separately-snapshotted category used to give.
class RunningActivity {
  const RunningActivity({
    required this.startedAt,
    required this.goalId,
    required this.title,
  });

  final DateTime startedAt;
  final String goalId;
  final String title;

  Map<String, dynamic> toMap() => {
    'startedAt': startedAt.toIso8601String(),
    'goalId': goalId,
    'title': title,
  };

  factory RunningActivity.fromMap(Map<String, dynamic> map) =>
      RunningActivity(
        startedAt: DateTime.parse(map['startedAt'] as String),
        goalId: map['goalId'] as String,
        title: map['title'] as String,
      );
}
