import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/goal_planned_blocks.dart';

final _ongoingStart = DateTime(2020, 1, 1);
final _ongoingEnd = DateTime(2099, 12, 31);

Map<int, List<DayScheduleEntry>> _uniform(Duration perDay) => {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: [DayScheduleEntry.duration(perDay)],
    };

void main() {
  group('generateGoalPlannedBlocksForDate', () {
    test('a time-range entry generates a block at its exact clock time', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        type: GoalType.target,
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 5; weekday++)
            weekday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
              ),
            ],
        },
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [work],
        date: DateTime(2026, 8, 20), // a Thursday
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.start, DateTime(2026, 8, 20, 9, 0));
      expect(blocks.single.end, DateTime(2026, 8, 20, 18, 0));
      expect(blocks.single.title, 'Work');
      expect(blocks.single.goalId, 'goal-work');
    });

    test('a goal with no schedule for a weekday generates nothing that day', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        type: GoalType.target,
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 5; weekday++)
            weekday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
              ),
            ],
        },
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [work],
        date: DateTime(2026, 8, 22), // a Saturday — not in the map
      );

      expect(blocks, isEmpty);
    });

    test('a plain-duration entry never generates a block — no clock time to place it at', () {
      final piano = Goal(
        id: 'goal-piano',
        name: 'Piano',
        categoryId: 'piano',
        type: GoalType.target,
        scheduleByWeekday: _uniform(const Duration(minutes: 15)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [piano],
        date: DateTime(2026, 8, 20),
      );

      expect(blocks, isEmpty);
    });

    test('a cap-type goal never generates a block, even with a time-range entry', () {
      final meetings = Goal(
        id: 'goal-meetings',
        name: 'Meetings',
        categoryId: 'meetings',
        type: GoalType.cap,
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(9, 0), ClockTime(11, 0)),
              ),
            ],
        },
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [meetings],
        date: DateTime(2026, 8, 20),
      );

      expect(blocks, isEmpty);
    });

    test('a goal outside its active date range generates nothing', () {
      final challenge = Goal(
        id: 'goal-challenge',
        name: 'August challenge',
        categoryId: 'walking',
        type: GoalType.target,
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

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [challenge],
        date: DateTime(2026, 8, 20), // after the challenge ended
      );

      expect(blocks, isEmpty);
    });

    test('multiple goals with only plain-duration entries generate nothing', () {
      final walking = Goal(
        id: 'goal-walking',
        name: 'Walking',
        categoryId: 'walking',
        type: GoalType.target,
        scheduleByWeekday: _uniform(const Duration(hours: 1)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      final reading = Goal(
        id: 'goal-reading',
        name: 'Reading',
        categoryId: 'reading',
        type: GoalType.target,
        scheduleByWeekday: _uniform(const Duration(minutes: 30)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [walking, reading],
        date: DateTime(2026, 8, 20),
      );

      expect(blocks, isEmpty);
    });

    test('a day with two time ranges (a split shift) generates two blocks', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        type: GoalType.target,
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(12, 0)),
            ),
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(14, 0), ClockTime(18, 0)),
            ),
          ],
        },
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [work],
        date: DateTime(2026, 8, 20), // a Thursday
      );

      expect(blocks, hasLength(2));
      expect(blocks[0].start, DateTime(2026, 8, 20, 9, 0));
      expect(blocks[0].end, DateTime(2026, 8, 20, 12, 0));
      expect(blocks[1].start, DateTime(2026, 8, 20, 14, 0));
      expect(blocks[1].end, DateTime(2026, 8, 20, 18, 0));
    });

    test(
        'a day mixing a time range and extra duration only generates a block for the time range',
        () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
        type: GoalType.target,
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
        scheduleByWeekday: {
          DateTime.thursday: [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(9, 0), ClockTime(12, 0)),
            ),
            const DayScheduleEntry.duration(Duration(minutes: 30)),
          ],
        },
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [work],
        date: DateTime(2026, 8, 20),
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.start, DateTime(2026, 8, 20, 9, 0));
      expect(blocks.single.end, DateTime(2026, 8, 20, 12, 0));
    });
  });
}
