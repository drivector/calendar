import 'clock_time.dart';

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
    return DayScheduleEntry.timeRange(
      ClockRange(
        ClockTime(startMinutes ~/ 60, startMinutes % 60),
        ClockTime(endMinutes ~/ 60, endMinutes % 60),
      ),
    );
  }

  Map<String, dynamic> toMap() => isTimeRange
      ? {
          'startMinutes': timeRange!.start.minutesSinceMidnight,
          'endMinutes': timeRange!.end.minutesSinceMidnight,
        }
      : {'durationMinutes': duration!.inMinutes};
}

/// Which of [Goal.scheduleByWeekday] or [Goal.scheduleByDate] actually
/// drives the goal's schedule — [byDate] only ever makes sense for a
/// date-bound goal (see [Goal.isDateBound]): there's no "every week"
/// pattern to repeat once the goal has a real end date you're specifying
/// individual days up to.
enum GoalScheduleMode { weekly, byDate }

/// Whether a goal still generates new planned blocks and shows up in goal
/// pickers. A goal with linked activities (see `goal_edit_sheet.dart`'s
/// delete flow) can't be hard-deleted — deleting it would orphan every
/// `PlannedBlock`/`TrackedBlock` that points at its id via [PlannedBlock
/// .goalId]/[TrackedBlock.goalId] — so it's deactivated instead. A
/// deactivated goal's own activities keep rendering (looked up by id
/// regardless of status), it just stops producing new ones and disappears
/// from lists/pickers. [active] is the default, including for every
/// already-written document that predates this field entirely.
enum GoalLifecycleStatus { active, deactivated }

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.scheduleByWeekday,
    required this.startDate,
    required this.endDate,
    this.scheduleMode = GoalScheduleMode.weekly,
    this.scheduleByDate = const {},
    this.reminderMinutesBefore,
    this.status = GoalLifecycleStatus.active,
  });

  final String id;
  final String name;
  final String categoryId;
  final GoalLifecycleStatus status;

  /// Which schedule below is actually in effect. Both fields are always
  /// present on a [Goal] regardless of mode (the inactive one just stays
  /// empty) — simpler than making either field nullable, and it means
  /// switching modes in the edit sheet never has to null out the other.
  final GoalScheduleMode scheduleMode;

  /// Each day's schedule, keyed by [DateTime.weekday] (Monday = 1 ..
  /// Sunday = 7) — a list of [DayScheduleEntry], possibly empty (day off).
  /// A day with no key at all is treated the same as an empty list. Only
  /// consulted when [scheduleMode] is [GoalScheduleMode.weekly].
  final Map<int, List<DayScheduleEntry>> scheduleByWeekday;

  /// Each individual calendar day's own schedule, keyed by that day's own
  /// date (year/month/day only, time-of-day zeroed) rather than a
  /// repeating weekday — for a goal like a 10-day challenge where day 3
  /// and day 7 genuinely call for different things, not just "whatever
  /// Wednesday always asks for." A date with no key is a day off, same
  /// convention as [scheduleByWeekday]. Only consulted when [scheduleMode]
  /// is [GoalScheduleMode.byDate].
  final Map<DateTime, List<DayScheduleEntry>> scheduleByDate;

  final DateTime startDate;
  final DateTime endDate;

  /// How long before a scheduled occurrence to send a reminder — same idea
  /// as a calendar meeting's reminder, `0` meaning "at the scheduled time"
  /// and `null` meaning no reminder at all (the default for a new goal).
  /// Only ever fires for time-range schedule entries — a plain-duration
  /// entry ("piano, 15 min, any time") has no clock time to count down to.
  final int? reminderMinutesBefore;

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

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<DayScheduleEntry> entriesForDate(DateTime date) =>
      scheduleByDate[_dateOnly(date)] ?? const <DayScheduleEntry>[];

  /// The entries that actually apply to [date] — [entriesForDate] in
  /// [GoalScheduleMode.byDate] mode, [entriesForWeekday] otherwise. The
  /// one call every date-driven consumer (generating a planned block for
  /// the calendar, summing untimed minutes, the pace calculation, ...)
  /// should go through instead of picking a schedule map directly, so
  /// adding a schedule mode never means hunting down every call site
  /// again.
  List<DayScheduleEntry> entriesForOccurrence(DateTime date) =>
      scheduleMode == GoalScheduleMode.byDate
          ? entriesForDate(date)
          : entriesForWeekday(date.weekday);

  Duration targetForWeekday(int weekday) =>
      entriesForWeekday(weekday)
          .fold(Duration.zero, (total, e) => total + e.effectiveDuration);

  Duration targetForDate(DateTime date) =>
      entriesForOccurrence(date)
          .fold(Duration.zero, (total, e) => total + e.effectiveDuration);

  /// The weekly pattern's own total, replayed once per week — meaningless
  /// for [GoalScheduleMode.byDate], where nothing repeats; use
  /// [totalTarget] there instead.
  Duration get weeklyTarget =>
      [for (var weekday = 1; weekday <= 7; weekday++) targetForWeekday(weekday)]
          .fold(Duration.zero, (a, b) => a + b);

  /// The single number everything that shows "the target" — the goal
  /// list's own card, the progress bar's denominator, the Capacity page's
  /// target line — actually divides by. For [GoalScheduleMode.weekly]
  /// that's [weeklyTarget]; for [GoalScheduleMode.byDate], which has no
  /// repeating week to speak of, it's the sum of every individual day's
  /// own entries across the whole [startDate]–[endDate] range instead —
  /// still named "weekly" for now so every existing call site (there are
  /// several) keeps working unchanged; it's the goal's own one target
  /// figure regardless of which schedule shape produced it.
  double get weeklyTargetHours => scheduleMode == GoalScheduleMode.byDate
      ? totalTarget.inMinutes / 60
      : weeklyTarget.inMinutes / 60;

  /// The sum of every entry across the goal's own schedule — for
  /// [GoalScheduleMode.byDate], every date actually given entries; for
  /// [GoalScheduleMode.weekly], the weekly pattern replayed once for each
  /// day the goal is actually active (so a partial first/last week still
  /// only counts the days genuinely in range).
  Duration get totalTarget {
    if (scheduleMode == GoalScheduleMode.byDate) {
      return scheduleByDate.values.fold(
        Duration.zero,
        (total, entries) => total +
            entries.fold(Duration.zero, (t, e) => t + e.effectiveDuration),
      );
    }
    var total = Duration.zero;
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      total += targetForWeekday(day.weekday);
    }
    return total;
  }

  /// True if every day asks for the same total amount — only meaningful
  /// for [GoalScheduleMode.weekly]; a [GoalScheduleMode.byDate] schedule
  /// is deliberately day-specific, so "uniform" isn't a question that
  /// applies to it.
  bool get isUniformAcrossWeek =>
      <Duration>{
        for (var weekday = 1; weekday <= 7; weekday++)
          targetForWeekday(weekday),
      }.length <=
      1;

  factory Goal.fromMap(String id, Map<String, dynamic> map) => Goal(
    id: id,
    name: map['name'] as String,
    categoryId: map['categoryId'] as String,
    scheduleMode: map['scheduleMode'] == 'byDate'
        ? GoalScheduleMode.byDate
        : GoalScheduleMode.weekly,
    scheduleByWeekday: {
      for (final entry
          in (map['scheduleByWeekday'] as Map<String, dynamic>).entries)
        int.parse(entry.key): [
          for (final e in entry.value as List<dynamic>)
            DayScheduleEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        ],
    },
    scheduleByDate: {
      for (final entry
          in (map['scheduleByDate'] as Map<String, dynamic>? ?? {}).entries)
        DateTime.parse(entry.key): [
          for (final e in entry.value as List<dynamic>)
            DayScheduleEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        ],
    },
    startDate: DateTime.parse(map['startDate'] as String),
    endDate: DateTime.parse(map['endDate'] as String),
    reminderMinutesBefore: map['reminderMinutesBefore'] as int?,
    status: GoalLifecycleStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => GoalLifecycleStatus.active,
    ),
  );

  /// A copy with [status] changed — used to deactivate a goal that has
  /// linked activities instead of hard-deleting it. Every other field is
  /// reconstructed in full, same convention as `TrackedBlock.copyWithStatus`.
  Goal copyWithStatus(GoalLifecycleStatus status) => Goal(
    id: id,
    name: name,
    categoryId: categoryId,
    scheduleByWeekday: scheduleByWeekday,
    startDate: startDate,
    endDate: endDate,
    scheduleMode: scheduleMode,
    scheduleByDate: scheduleByDate,
    reminderMinutesBefore: reminderMinutesBefore,
    status: status,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'categoryId': categoryId,
    'status': status.name,
    'scheduleMode': scheduleMode == GoalScheduleMode.byDate
        ? 'byDate'
        : 'weekly',
    'scheduleByWeekday': {
      for (final entry in scheduleByWeekday.entries)
        '${entry.key}': [for (final e in entry.value) e.toMap()],
    },
    'scheduleByDate': {
      for (final entry in scheduleByDate.entries)
        entry.key.toIso8601String(): [
          for (final e in entry.value) e.toMap(),
        ],
    },
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'reminderMinutesBefore': reminderMinutesBefore,
  };
}
