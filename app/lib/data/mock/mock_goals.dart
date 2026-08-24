import '../../models/goal.dart';
import 'mock_categories.dart';

// Well past the [ongoingGoalSpan] threshold, so these read as ongoing
// habits rather than dated challenges — no start/end shown in the UI.
final _ongoingStart = DateTime(2020, 1, 1);
final _ongoingEnd = DateTime(2099, 12, 31);

/// Wraps a plain weekday->Duration map (the natural way to write these
/// mocks) into the goal model's per-day entry lists — a zero-duration day
/// becomes an empty list (day off), rather than a zero-length entry.
Map<int, List<DayScheduleEntry>> _durationSchedule(
  Map<int, Duration> targets,
) => {
  for (final entry in targets.entries)
    entry.key: entry.value == Duration.zero
        ? const <DayScheduleEntry>[]
        : [DayScheduleEntry.duration(entry.value)],
};

/// The 2 target-type goals named in the handoff README, given a per-day
/// target that sums to roughly the original spec's weekly figure — the
/// split itself (more walking on weekends, no deep work on weekends, ...)
/// is illustrative. The handoff's other 3 (Meetings, Admin, Screen after
/// 21:00) only made sense as cap goals — a ceiling to stay under — which
/// this app no longer models, and recasting them as targets (a minimum to
/// reach) would misrepresent them: nobody wants a *minimum* amount of
/// screen time. Dropped rather than fabricated into something they never
/// were.
final mockGoals = [
  Goal(
    id: 'goal-walking',
    startDate: _ongoingStart,
    endDate: _ongoingEnd,
    name: 'Walking',
    categoryId: walkingCategoryId,
    // 5×1h + 2×2h30 = 10h/wk
    scheduleByWeekday: _durationSchedule({
      DateTime.monday: Duration(hours: 1),
      DateTime.tuesday: Duration(hours: 1),
      DateTime.wednesday: Duration(hours: 1),
      DateTime.thursday: Duration(hours: 1),
      DateTime.friday: Duration(hours: 1),
      DateTime.saturday: Duration(hours: 2, minutes: 30),
      DateTime.sunday: Duration(hours: 2, minutes: 30),
    }),
  ),
  Goal(
    id: 'goal-deep-work',
    startDate: _ongoingStart,
    endDate: _ongoingEnd,
    name: 'Deep work',
    categoryId: deepWorkCategoryId,
    // 5×4h = 20h/wk, none on weekends
    scheduleByWeekday: _durationSchedule({
      DateTime.monday: Duration(hours: 4),
      DateTime.tuesday: Duration(hours: 4),
      DateTime.wednesday: Duration(hours: 4),
      DateTime.thursday: Duration(hours: 4),
      DateTime.friday: Duration(hours: 4),
      DateTime.saturday: Duration.zero,
      DateTime.sunday: Duration.zero,
    }),
  ),
];
