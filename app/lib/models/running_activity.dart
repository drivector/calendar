/// A currently in-progress activity — created by "Start", turned into a
/// real [TrackedBlock] and cleared by "Stop". Persisted as a single
/// Firestore doc (see `runningActivityDocProvider`) rather than any local
/// in-memory state, which is what lets it survive the app being closed and
/// reopened, or opened on another device signed into the same account.
/// [categoryId] is captured at start time rather than looked up again from
/// [goalId] at stop time, so stopping still works correctly even if the
/// goal it was started against gets edited or deleted while it's running.
class RunningActivity {
  const RunningActivity({
    required this.startedAt,
    required this.goalId,
    required this.categoryId,
    required this.title,
  });

  final DateTime startedAt;
  final String goalId;
  final String categoryId;
  final String title;

  Map<String, dynamic> toMap() => {
    'startedAt': startedAt.toIso8601String(),
    'goalId': goalId,
    'categoryId': categoryId,
    'title': title,
  };

  factory RunningActivity.fromMap(Map<String, dynamic> map) =>
      RunningActivity(
        startedAt: DateTime.parse(map['startedAt'] as String),
        goalId: map['goalId'] as String,
        categoryId: map['categoryId'] as String,
        title: map['title'] as String,
      );
}
