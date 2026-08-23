import 'clock_time.dart';

enum GoalType { target, cap }

/// A goal always has a start and end date — there's no separate "ongoing"
/// flag. An open-ended goal is just one whose end date is far out; a
/// time-bound challenge is one whose end date is close to its start.
const ongoingGoalSpan = Duration(days: 365);

/// One piece of a day's schedule — either a plain amount of time with no
/// fixed clock position ("piano, 15 min, any time"), or a specific clock
/// window ("work, 09:00 to 18:00"), whose duration is derived from the
/// range rather than stored separately. A day can hold more than one of
/// these (e.g. two work shifts, or a time range plus some extra untimed
/// duration on top) — the day's target is the sum of all its entries.
class DayScheduleEntry {
  const DayScheduleEntry.duration(Duration amount)
      : duration = amount,
        timeRange = null;

  const DayScheduleEntry.timeRange(ClockRange range)
      : timeRange = range,
        duration = null;

  /// Set only for a plain-duration entry.
  final Duration? duration;

  /// Set only for a time-range entry.
  final ClockRange? timeRange;

  bool get isTimeRange => timeRange != null;

  Duration get effectiveDuration => timeRange?.duration ?? duration!;

  factory DayScheduleEntry.fromMap(Map<String, dynamic> map) {
    final durationMinutes = map['durationMinutes'] as int?;
    if (durationMinutes != null) {
      return DayScheduleEntry.duration(Duration(minutes: durationMinutes));
    }
    final startMinutes = map['startMinutes'] as int;
    final endMinutes = map['endMinutes'] as int;
    return DayScheduleEntry.timeRange(ClockRange(
      ClockTime(startMinutes ~/ 60, startMinutes % 60),
      ClockTime(endMinutes ~/ 60, endMinutes % 60),
    ));
  }

  Map<String, dynamic> toMap() => isTimeRange
      ? {
          'startMinutes': timeRange!.start.minutesSinceMidnight,
          'endMinutes': timeRange!.end.minutesSinceMidnight,
        }
      : {'durationMinutes': duration!.inMinutes};
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    required this.scheduleByWeekday,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String name;
  final String categoryId;
  final GoalType type;

  /// Each day's schedule, keyed by [DateTime.weekday] (Monday = 1 ..
  /// Sunday = 7) — a list of [DayScheduleEntry], possibly empty (day off).
  /// A day with no key at all is treated the same as an empty list.
  final Map<int, List<DayScheduleEntry>> scheduleByWeekday;

  final DateTime startDate;
  final DateTime endDate;

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

  List<DayScheduleEntry> entriesForWeekday(int weekday) =>
      scheduleByWeekday[weekday] ?? const <DayScheduleEntry>[];

  Duration targetForWeekday(int weekday) => entriesForWeekday(weekday)
      .fold(Duration.zero, (total, e) => total + e.effectiveDuration);

  Duration get weeklyTarget => [
        for (var weekday = 1; weekday <= 7; weekday++) targetForWeekday(weekday),
      ].fold(Duration.zero, (a, b) => a + b);

  double get weeklyTargetHours => weeklyTarget.inMinutes / 60;

  /// True if every day asks for the same total amount.
  bool get isUniformAcrossWeek => <Duration>{
        for (var weekday = 1; weekday <= 7; weekday++) targetForWeekday(weekday),
      }.length <= 1;

  factory Goal.fromMap(String id, Map<String, dynamic> map) => Goal(
        id: id,
        name: map['name'] as String,
        categoryId: map['categoryId'] as String,
        type: GoalType.values.byName(map['type'] as String),
        scheduleByWeekday: {
          for (final entry
              in (map['scheduleByWeekday'] as Map<String, dynamic>).entries)
            int.parse(entry.key): [
              for (final e in entry.value as List<dynamic>)
                DayScheduleEntry.fromMap(Map<String, dynamic>.from(e as Map)),
            ],
        },
        startDate: DateTime.parse(map['startDate'] as String),
        endDate: DateTime.parse(map['endDate'] as String),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'categoryId': categoryId,
        'type': type.name,
        'scheduleByWeekday': {
          for (final entry in scheduleByWeekday.entries)
            '${entry.key}': [for (final e in entry.value) e.toMap()],
        },
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
}
