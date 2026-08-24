import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/goal_reminders.dart';

final _ongoingStart = DateTime(2020, 1, 1);
final _ongoingEnd = DateTime(2099, 12, 31);

void main() {
  group('computeReminderOccurrences', () {
    test('a goal with no reminder set produces nothing', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      final occurrences = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 7),
      );

      expect(occurrences, isEmpty);
    });

    test('a time-range entry with a reminder set is offset by the lead time', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 15,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      final occurrences = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 7), // Thursday, before the reminder fires
        windowDays: 3, // just this Thursday — next one is 7 days out
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.single.goalId, 'goal-work');
      expect(occurrences.single.title, 'Work');
      expect(occurrences.single.scheduledTime, DateTime(2026, 8, 20, 8, 45));
    });

    test('reminderMinutesBefore: 0 fires exactly at the scheduled time', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 0,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      final occurrences = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 7),
        windowDays: 3,
      );

      expect(occurrences.single.scheduledTime, DateTime(2026, 8, 20, 9, 0));
    });

    test('a plain-duration entry has no clock time and generates no reminder', () {
      final piano = Goal(
        id: 'goal-piano',
        name: 'Piano',
        categoryId: 'piano',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 15,
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: [const DayScheduleEntry.duration(Duration(minutes: 15))],
        },
      );

      final occurrences = computeReminderOccurrences(
        goals: [piano],
        now: DateTime(2026, 8, 20, 7),
      );

      expect(occurrences, isEmpty);
    });

    test('an occurrence whose reminder time has already passed is dropped', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 15,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      // now is after this Thursday's 08:45 reminder time, so today's
      // occurrence is dropped — but next Thursday's still comes through
      // inside the default 14-day window.
      final occurrences = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 10),
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.single.scheduledTime, DateTime(2026, 8, 27, 8, 45));
    });

    test('a goal outside its active date range produces no reminders', () {
      final challenge = Goal(
        id: 'goal-challenge',
        name: 'August challenge',
        categoryId: 'walking',
        reminderMinutesBefore: 10,
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(7, 0), ClockTime(7, 30)),
              ),
            ],
        },
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 15),
      );

      final occurrences = computeReminderOccurrences(
        goals: [challenge],
        now: DateTime(2026, 8, 20, 7), // after the challenge ended
      );

      expect(occurrences, isEmpty);
    });

    test('two goals with reminders each produce their own occurrences', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 30,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );
      final walking = Goal(
        id: 'goal-walking',
        name: 'Walking',
        categoryId: 'walking',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 5,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(7, 0), ClockTime(7, 30)),
            ),
          ],
        },
      );

      final occurrences = computeReminderOccurrences(
        goals: [work, walking],
        now: DateTime(2026, 8, 20, 6), // Thursday, before both
      );

      final goalIds = occurrences.map((o) => o.goalId).toSet();
      expect(goalIds, {'goal-work', 'goal-walking'});
    });

    test('ids are stable per source block, so a resync would replace, not duplicate', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 15,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      final first = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 7),
        windowDays: 3,
      );
      final second = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 7),
        windowDays: 3,
      );

      expect(first.single.id, second.single.id);
      expect(first.single.id, greaterThanOrEqualTo(0));
    });

    test('windowDays limits how far ahead occurrences are computed', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        reminderMinutesBefore: 15,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      final occurrences = computeReminderOccurrences(
        goals: [work],
        now: DateTime(2026, 8, 20, 10), // just past today's reminder
        windowDays: 3,
      );

      expect(occurrences, isEmpty); // next Thursday is 7 days out
    });
  });
}
