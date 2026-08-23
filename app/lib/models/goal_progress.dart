import 'goal.dart';

enum GoalStatus { onPace, behindPace, overCap }

/// Derived per goal — matches the README's `goalProgress` state entry.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.actualHours,
    required this.plannedHours,
    required this.expectedByNowHours,
    required this.status,
  });

  final Goal goal;
  final double actualHours;

  /// Hours planned (not necessarily tracked) toward this goal this week —
  /// from [PlannedBlock]s in the Day view, separate from [actualHours].
  final double plannedHours;

  /// Pace target: the sum of full targets for every day of this week so far,
  /// plus today's own target scaled by how much of today has elapsed.
  final double expectedByNowHours;
  final GoalStatus status;

  double get completionFraction => goal.weeklyTargetHours == 0
      ? 0
      : (actualHours / goal.weeklyTargetHours).clamp(0, 1);

  double get expectedByNowFraction => goal.weeklyTargetHours == 0
      ? 0
      : (expectedByNowHours / goal.weeklyTargetHours).clamp(0, 1);
}

/// Where pace "should" be right now, given each day of the week can ask for
/// a different amount — full credit for every day already finished this
/// week, partial credit for today based on how much of it has elapsed.
double expectedByNowHours(Goal goal, DateTime date) {
  var total = 0.0;
  for (var weekday = 1; weekday < date.weekday; weekday++) {
    total += goal.targetForWeekday(weekday).inMinutes / 60;
  }
  final todayTargetHours = goal.targetForWeekday(date.weekday).inMinutes / 60;
  final dayFraction = (date.hour * 60 + date.minute) / (24 * 60);
  return total + todayTargetHours * dayFraction;
}

GoalProgress computeGoalProgress({
  required Goal goal,
  required double actualHours,
  required double plannedHours,
  required DateTime date,
}) {
  final expectedByNow = expectedByNowHours(goal, date);

  final GoalStatus status;
  if (goal.type == GoalType.cap) {
    status = actualHours > goal.weeklyTargetHours
        ? GoalStatus.overCap
        : GoalStatus.onPace;
  } else {
    status =
        actualHours >= expectedByNow ? GoalStatus.onPace : GoalStatus.behindPace;
  }

  return GoalProgress(
    goal: goal,
    actualHours: actualHours,
    plannedHours: plannedHours,
    expectedByNowHours: expectedByNow,
    status: status,
  );
}

/// The Monday that starts the week containing [date].
DateTime weekStartFor(DateTime date) {
  final dayOnly = DateTime(date.year, date.month, date.day);
  return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
}

String formatGoalStatus(GoalProgress progress) {
  switch (progress.status) {
    case GoalStatus.onPace:
      return 'on pace';
    case GoalStatus.behindPace:
      return 'behind pace';
    case GoalStatus.overCap:
      final over = progress.actualHours - progress.goal.weeklyTargetHours;
      return 'over cap by ${_formatHours(over)}';
  }
}

String _formatHours(double hours) {
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m m';
  if (m == 0) return '$h h';
  return '$h h $m';
}
