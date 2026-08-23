import '../../models/goal.dart';
import 'mock_categories.dart';

// Well past the [ongoingGoalSpan] threshold, so these 5 read as ongoing
// habits rather than dated challenges — no start/end shown in the UI.
final _ongoingStart = DateTime(2020, 1, 1);
final _ongoingEnd = DateTime(2099, 12, 31);

/// Wraps a plain weekday->Duration map (the natural way to write these
/// mocks) into the goal model's per-day entry lists — a zero-duration day
/// becomes an empty list (day off), rather than a zero-length entry.
Map<int, List<DayScheduleEntry>> _durationSchedule(Map<int, Duration> targets) => {
      for (final entry in targets.entries)
        entry.key: entry.value == Duration.zero
            ? const <DayScheduleEntry>[]
            : [DayScheduleEntry.duration(entry.value)],
    };

Map<int, Duration> _weekdayVsWeekend(Duration weekday, Duration weekend) => {
      DateTime.monday: weekday,
      DateTime.tuesday: weekday,
      DateTime.wednesday: weekday,
      DateTime.thursday: weekday,
      DateTime.friday: weekday,
      DateTime.saturday: weekend,
      DateTime.sunday: weekend,
    };

/// The 5 goals named in the handoff README, given a per-day target that
/// sums to roughly the original spec's weekly figure — the split itself
/// (more walking on weekends, no deep work on weekends, ...) is illustrative.
final mockGoals = [
  Goal(
    id: 'goal-walking',
    startDate: _ongoingStart,
    endDate: _ongoingEnd,
    name: 'Walking',
    categoryId: walkingCategoryId,
    type: GoalType.target,
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
    type: GoalType.target,
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
  Goal(
    id: 'goal-meetings',
    startDate: _ongoingStart,
    endDate: _ongoingEnd,
    name: 'Meetings',
    categoryId: meetingsCategoryId,
    type: GoalType.cap,
    // 2h + 4×1h30 = 8h/wk cap
    scheduleByWeekday: _durationSchedule({
      DateTime.monday: Duration(hours: 2),
      DateTime.tuesday: Duration(hours: 1, minutes: 30),
      DateTime.wednesday: Duration(hours: 1, minutes: 30),
      DateTime.thursday: Duration(hours: 1, minutes: 30),
      DateTime.friday: Duration(hours: 1, minutes: 30),
      DateTime.saturday: Duration.zero,
      DateTime.sunday: Duration.zero,
    }),
  ),
  Goal(
    id: 'goal-admin',
    startDate: _ongoingStart,
    endDate: _ongoingEnd,
    name: 'Admin',
    categoryId: adminCategoryId,
    type: GoalType.cap,
    // 1h + 4×45m = 4h/wk cap
    scheduleByWeekday: _durationSchedule({
      DateTime.monday: Duration(hours: 1),
      DateTime.tuesday: Duration(minutes: 45),
      DateTime.wednesday: Duration(minutes: 45),
      DateTime.thursday: Duration(minutes: 45),
      DateTime.friday: Duration(minutes: 45),
      DateTime.saturday: Duration.zero,
      DateTime.sunday: Duration.zero,
    }),
  ),
  Goal(
    id: 'goal-screen-time',
    startDate: _ongoingStart,
    endDate: _ongoingEnd,
    name: 'Screen after 21:00',
    categoryId: screenTimeCategoryId,
    type: GoalType.cap,
    // 5×20m + 2×40m = 3h/wk cap, more slack on weekends
    scheduleByWeekday: _durationSchedule(_weekdayVsWeekend(
      const Duration(minutes: 20),
      const Duration(minutes: 40),
    )),
  ),
];

/// This week's actual hours per goal — the canonical numbers, taken from the
/// handoff's desktop "Week 34 ledger" (screen 7), reused across the Week and
/// Goals screens so their totals reconcile with each other. (They're a
/// different set of numbers than the mobile Week screen's own illustrative
/// header text in the README, which — like the Day view's screenshot totals
/// — doesn't arithmetically reconcile with anything else in the handoff
/// either; this mock picks one canonical source rather than chasing that.)
const mockGoalActualHours = {
  walkingCategoryId: 7.5,
  deepWorkCategoryId: 18.0,
  meetingsCategoryId: 11.0,
  adminCategoryId: 3.2,
  screenTimeCategoryId: 1.4,
};

Goal? goalForCategory(String categoryId) {
  for (final goal in mockGoals) {
    if (goal.categoryId == categoryId) return goal;
  }
  return null;
}
