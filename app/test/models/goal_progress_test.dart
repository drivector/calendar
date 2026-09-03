import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/goal_progress.dart';

Map<int, List<DayScheduleEntry>> _uniform(Duration perDay) => {
  for (var weekday = 1; weekday <= 7; weekday++)
    weekday: [DayScheduleEntry.duration(perDay)],
};

final _ongoingStart = DateTime(2020, 1, 1);
final _ongoingEnd = DateTime(2099, 12, 31);

void main() {
  group('Goal', () {
    test('weeklyTarget sums every day', () {
      final goal = Goal(
        id: 'g',
        name: 'Walking',
        categoryId: 'walking',
        scheduleByWeekday: {
          DateTime.monday: [
            const DayScheduleEntry.duration(Duration(hours: 1)),
          ],
          DateTime.saturday: [
            const DayScheduleEntry.duration(Duration(hours: 2, minutes: 30)),
          ],
          DateTime.sunday: [
            const DayScheduleEntry.duration(Duration(hours: 2, minutes: 30)),
          ],
        },
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      expect(goal.weeklyTarget, const Duration(hours: 6));
      expect(goal.isUniformAcrossWeek, isFalse);
    });

    test('isUniformAcrossWeek is true when every day matches', () {
      final goal = Goal(
        id: 'g',
        name: 'Reading',
        categoryId: 'reading',
        scheduleByWeekday: _uniform(const Duration(minutes: 30)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      expect(goal.isUniformAcrossWeek, isTrue);
    });

    test('a goal with a far-out end date reads as ongoing', () {
      final goal = Goal(
        id: 'g',
        name: 'Walking',
        categoryId: 'walking',
        scheduleByWeekday: _uniform(const Duration(minutes: 30)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      expect(goal.isDateBound, isFalse);
      expect(goal.isActiveOn(DateTime(2020, 1, 1)), isTrue);
      expect(goal.isActiveOn(DateTime(2099, 1, 1)), isTrue);
    });

    test('a goal is only active within its start/end range, inclusive', () {
      final goal = Goal(
        id: 'g',
        name: 'August challenge',
        categoryId: 'walking',
        scheduleByWeekday: _uniform(const Duration(minutes: 30)),
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );
      expect(goal.isDateBound, isTrue);
      expect(goal.isActiveOn(DateTime(2026, 7, 31)), isFalse);
      expect(goal.isActiveOn(DateTime(2026, 8, 1)), isTrue);
      expect(goal.isActiveOn(DateTime(2026, 8, 15, 23, 59)), isTrue);
      expect(goal.isActiveOn(DateTime(2026, 8, 31)), isTrue);
      expect(goal.isActiveOn(DateTime(2026, 9, 1)), isFalse);
    });

    test('a time-range entry derives its duration from the range', () {
      final goal = Goal(
        id: 'g',
        name: 'Work',
        categoryId: 'work',
        // 09:00-18:00 = 9h, Mon-Fri only.
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 5; weekday++)
            weekday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
              ),
            ],
          DateTime.saturday: const [],
          DateTime.sunday: const [],
        },
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      expect(goal.targetForWeekday(DateTime.monday), const Duration(hours: 9));
      expect(goal.targetForWeekday(DateTime.saturday), Duration.zero);
    });

    test('a day sums multiple entries, mixing duration and time range', () {
      final goal = Goal(
        id: 'g',
        name: 'Split shift',
        categoryId: 'work',
        // A morning shift, an afternoon shift, plus 30 min of untimed
        // admin on top — three entries, one day.
        scheduleByWeekday: {
          DateTime.monday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(12, 0)),
            ),
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(14, 0), ClockTime(18, 0)),
            ),
            const DayScheduleEntry.duration(Duration(minutes: 30)),
          ],
        },
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      // 3h + 4h + 30m = 7h30
      expect(
        goal.targetForWeekday(DateTime.monday),
        const Duration(hours: 7, minutes: 30),
      );
    });
  });

  group('GoalScheduleMode.byDate', () {
    test('entriesForOccurrence reads the exact date, not the weekday', () {
      final challenge = Goal(
        id: 'g',
        name: 'Challenge',
        categoryId: 'walking',
        scheduleMode: GoalScheduleMode.byDate,
        scheduleByWeekday: const {},
        scheduleByDate: {
          DateTime(2026, 8, 20): [
            const DayScheduleEntry.duration(Duration(minutes: 45)),
          ],
        },
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 22),
      );

      expect(
        challenge.targetForDate(DateTime(2026, 8, 20)),
        const Duration(minutes: 45),
      );
      // The 27th is also a Thursday (same weekday as the 20th) but has no
      // entry of its own — a byDate schedule never falls back to "what
      // this weekday usually gets."
      expect(challenge.targetForDate(DateTime(2026, 8, 27)), Duration.zero);
    });

    test(
      'totalTarget sums every date actually given entries, and '
      'weeklyTargetHours resolves to the same figure',
      () {
        final challenge = Goal(
          id: 'g',
          name: 'Challenge',
          categoryId: 'walking',
          scheduleMode: GoalScheduleMode.byDate,
          scheduleByWeekday: const {},
          scheduleByDate: {
            DateTime(2026, 8, 20): [
              const DayScheduleEntry.duration(Duration(minutes: 30)),
            ],
            DateTime(2026, 8, 22): [
              const DayScheduleEntry.duration(Duration(hours: 1)),
            ],
          },
          startDate: DateTime(2026, 8, 20),
          endDate: DateTime(2026, 8, 24),
        );

        expect(challenge.totalTarget, const Duration(hours: 1, minutes: 30));
        expect(challenge.weeklyTargetHours, closeTo(1.5, 0.001));
      },
    );

    test(
      'expectedByNowHours paces against days since the goal\'s own start, '
      'not the current calendar week',
      () {
        final challenge = Goal(
          id: 'g',
          name: 'Challenge',
          categoryId: 'walking',
          scheduleMode: GoalScheduleMode.byDate,
          scheduleByWeekday: const {},
          scheduleByDate: {
            DateTime(2026, 8, 20): [
              const DayScheduleEntry.duration(Duration(hours: 1)),
            ],
            DateTime(2026, 8, 21): [
              const DayScheduleEntry.duration(Duration(hours: 1)),
            ],
            DateTime(2026, 8, 22): [
              const DayScheduleEntry.duration(Duration(hours: 1)),
            ],
          },
          startDate: DateTime(2026, 8, 20),
          endDate: DateTime(2026, 8, 24),
        );

        // Midday on the 22nd (day 3): days 1 and 2 in full (2h) plus half
        // of day 3's own 1h = 2.5h.
        final hours = expectedByNowHours(
          challenge,
          DateTime(2026, 8, 22, 12, 0),
        );
        expect(hours, closeTo(2.5, 0.001));
      },
    );
  });

  group('expectedByNowHours', () {
    // Deep work: 4h Mon–Fri, 0 on weekends.
    final deepWork = Goal(
      id: 'g',
      name: 'Deep work',
      categoryId: 'deep_work',
      scheduleByWeekday: {
        DateTime.monday: [const DayScheduleEntry.duration(Duration(hours: 4))],
        DateTime.tuesday: [const DayScheduleEntry.duration(Duration(hours: 4))],
        DateTime.wednesday: [
          const DayScheduleEntry.duration(Duration(hours: 4)),
        ],
        DateTime.thursday: [
          const DayScheduleEntry.duration(Duration(hours: 4)),
        ],
        DateTime.friday: [const DayScheduleEntry.duration(Duration(hours: 4))],
        DateTime.saturday: const [],
        DateTime.sunday: const [],
      },
      startDate: _ongoingStart,
      endDate: _ongoingEnd,
    );

    test('Monday 00:00 expects nothing yet', () {
      expect(expectedByNowHours(deepWork, DateTime(2026, 8, 17, 0, 0)), 0.0);
    });

    test('Wednesday noon expects Mon+Tue in full plus half of Wednesday', () {
      // Mon 4h + Tue 4h + (Wed 4h * 0.5) = 10h
      final hours = expectedByNowHours(deepWork, DateTime(2026, 8, 19, 12, 0));
      expect(hours, closeTo(10.0, 0.001));
    });

    test(
      'Saturday expects the full Mon-Fri total, since Saturday asks for 0',
      () {
        final hours = expectedByNowHours(
          deepWork,
          DateTime(2026, 8, 22, 12, 0),
        );
        expect(hours, closeTo(20.0, 0.001));
      },
    );
  });

  group('computeGoalProgress', () {
    final target = Goal(
      id: 'g1',
      name: 'Walking',
      categoryId: 'walking',
      scheduleByWeekday: _uniform(
        const Duration(hours: 1, minutes: 26),
      ), // ~10h/wk
      startDate: _ongoingStart,
      endDate: _ongoingEnd,
    );

    test('on pace when actual meets or beats the expected-by-now pace', () {
      final progress = computeGoalProgress(
        goal: target,
        actualHours: 6,
        plannedHours: 0,
        date: DateTime(2026, 8, 20, 12, 0), // Thursday noon: ~half the week
      );
      expect(progress.status, GoalStatus.onPace);
    });

    test('behind pace when actual trails the expected-by-now pace', () {
      final progress = computeGoalProgress(
        goal: target,
        actualHours: 1,
        plannedHours: 0,
        date: DateTime(2026, 8, 20, 12, 0),
      );
      expect(progress.status, GoalStatus.behindPace);
    });
  });
}
