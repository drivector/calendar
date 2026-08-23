import 'clock_time.dart';

enum GoalType { target, cap }

/// How a goal's per-day target is defined:
/// - [duration]: just an amount, no fixed time — "piano, 15 min, any time".
/// - [timeRange]: a specific clock window each active day — "work, 09:00
///   to 18:00". The duration is derived from the range.
enum GoalScheduleMode { duration, timeRange }

/// A goal always has a start and end date — there's no separate "ongoing"
/// flag. An open-ended goal is just one whose end date is far out; a
/// time-bound challenge is one whose end date is close to its start.
const ongoingGoalSpan = Duration(days: 365);

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    required this.targetsByWeekday,
    required this.startDate,
    required this.endDate,
    this.scheduleMode = GoalScheduleMode.duration,
    this.timeRangesByWeekday,
  });

  final String id;
  final String name;
  final String categoryId;
  final GoalType type;

  /// Per-day targets, keyed by [DateTime.weekday] (Monday = 1 .. Sunday = 7).
  /// Always populated regardless of [scheduleMode] — when [scheduleMode] is
  /// [GoalScheduleMode.timeRange] this is derived from [timeRangesByWeekday]
  /// (each day's target = that day's range duration), kept in sync by
  /// whatever builds the [Goal] (the edit sheet). Everything that computes
  /// progress only ever reads this map, never the ranges directly.
  final Map<int, Duration> targetsByWeekday;

  final DateTime startDate;
  final DateTime endDate;

  final GoalScheduleMode scheduleMode;

  /// Only meaningful when [scheduleMode] is [GoalScheduleMode.timeRange] —
  /// kept alongside the derived [targetsByWeekday] so the edit sheet can
  /// show the original clock times back, not just a duration. A day absent
  /// from this map has no fixed time that day (not scheduled).
  final Map<int, ClockRange>? timeRangesByWeekday;

  /// True once a goal's window is short enough to read as a deliberate
  /// challenge rather than an open-ended habit — anything created via the
  /// edit sheet's default span (see [ongoingGoalSpan]) or longer reads as
  /// ongoing and doesn't show its dates in the UI.
  bool get isDateBound => endDate.difference(startDate) < ongoingGoalSpan;

  bool isActiveOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Duration targetForWeekday(int weekday) =>
      targetsByWeekday[weekday] ?? Duration.zero;

  Duration get weeklyTarget =>
      targetsByWeekday.values.fold(Duration.zero, (a, b) => a + b);

  double get weeklyTargetHours => weeklyTarget.inMinutes / 60;

  /// True if every day asks for the same amount.
  bool get isUniformAcrossWeek => targetsByWeekday.values.toSet().length <= 1;
}
