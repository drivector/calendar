import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/goal_planned_blocks.dart';
import 'package:calendar_tracker/models/planned_block.dart';

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
        existingBlocksForDate: const [],
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.start, DateTime(2026, 8, 20, 9, 0));
      expect(blocks.single.end, DateTime(2026, 8, 20, 18, 0));
      expect(blocks.single.title, 'Work');
      expect(blocks.single.goalId, 'goal-work');
      expect(blocks.single.isGoalAutoPlaced, isFalse);
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
        existingBlocksForDate: const [],
      );

      expect(blocks, isEmpty);
    });

    test('a duration entry on an empty day places at the default anchor time', () {
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
        existingBlocksForDate: const [],
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.start, DateTime(2026, 8, 20, 6, 0));
      expect(blocks.single.duration, const Duration(minutes: 15));
      expect(blocks.single.isGoalAutoPlaced, isTrue);
    });

    test('a duration entry is placed after an existing block that occupies the anchor time', () {
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
        existingBlocksForDate: [
          PlannedBlock(
            id: 'manual-1',
            start: DateTime(2026, 8, 20, 6, 0),
            end: DateTime(2026, 8, 20, 7, 0),
            title: 'Something else',
            categoryId: 'other',
          ),
        ],
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.start, DateTime(2026, 8, 20, 7, 0));
      expect(blocks.single.end, DateTime(2026, 8, 20, 7, 15));
    });

    test('a duration entry that would overlap a later manual block is pushed past it entirely', () {
      final deepWork = Goal(
        id: 'goal-deep-work',
        name: 'Deep work',
        categoryId: 'deep_work',
        type: GoalType.target,
        scheduleByWeekday: _uniform(const Duration(hours: 4)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [deepWork],
        date: DateTime(2026, 8, 20),
        existingBlocksForDate: [
          // Starts inside where a naive 06:00 + 4h placement would land,
          // but the block itself starts even earlier than the anchor.
          PlannedBlock(
            id: 'manual-1',
            start: DateTime(2026, 8, 20, 8, 0),
            end: DateTime(2026, 8, 20, 9, 0),
            title: 'Standup',
            categoryId: 'meetings',
          ),
        ],
      );

      expect(blocks, hasLength(1));
      // 06:00 + 4h = 10:00, which is already past the 08:00-09:00 block —
      // so it should NOT have been pushed at all, and should not overlap it.
      final block = blocks.single;
      final manualStart = DateTime(2026, 8, 20, 8, 0);
      final manualEnd = DateTime(2026, 8, 20, 9, 0);
      final overlaps = block.start.isBefore(manualEnd) && block.end.isAfter(manualStart);
      expect(overlaps, isFalse);
    });

    test('a cap-type goal never generates a block, even with duration entries', () {
      final meetings = Goal(
        id: 'goal-meetings',
        name: 'Meetings',
        categoryId: 'meetings',
        type: GoalType.cap,
        scheduleByWeekday: _uniform(const Duration(hours: 2)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [meetings],
        date: DateTime(2026, 8, 20),
        existingBlocksForDate: const [],
      );

      expect(blocks, isEmpty);
    });

    test('a goal outside its active date range generates nothing', () {
      final challenge = Goal(
        id: 'goal-challenge',
        name: 'August challenge',
        categoryId: 'walking',
        type: GoalType.target,
        scheduleByWeekday: _uniform(const Duration(minutes: 30)),
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 15),
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [challenge],
        date: DateTime(2026, 8, 20), // after the challenge ended
        existingBlocksForDate: const [],
      );

      expect(blocks, isEmpty);
    });

    test('two goals with duration entries on the same day are placed back-to-back, not overlapping', () {
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
        existingBlocksForDate: const [],
      );

      expect(blocks, hasLength(2));
      expect(blocks[0].start, DateTime(2026, 8, 20, 6, 0));
      expect(blocks[0].end, DateTime(2026, 8, 20, 7, 0));
      expect(blocks[1].start, DateTime(2026, 8, 20, 7, 0));
      expect(blocks[1].end, DateTime(2026, 8, 20, 7, 30));
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
        existingBlocksForDate: const [],
      );

      expect(blocks, hasLength(2));
      expect(blocks[0].start, DateTime(2026, 8, 20, 9, 0));
      expect(blocks[0].end, DateTime(2026, 8, 20, 12, 0));
      expect(blocks[1].start, DateTime(2026, 8, 20, 14, 0));
      expect(blocks[1].end, DateTime(2026, 8, 20, 18, 0));
      expect(blocks.every((b) => !b.isGoalAutoPlaced), isTrue);
    });

    test('a day mixing a time range and extra duration generates both, not overlapping', () {
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
        existingBlocksForDate: const [],
      );

      expect(blocks, hasLength(2));
      final timeRangeBlock = blocks.firstWhere((b) => !b.isGoalAutoPlaced);
      final durationBlock = blocks.firstWhere((b) => b.isGoalAutoPlaced);
      expect(timeRangeBlock.start, DateTime(2026, 8, 20, 9, 0));
      expect(timeRangeBlock.end, DateTime(2026, 8, 20, 12, 0));
      // The duration entry's default 06:00 anchor is free (nothing placed
      // there yet — the time range starts at 09:00), so it lands there.
      expect(durationBlock.start, DateTime(2026, 8, 20, 6, 0));
      expect(durationBlock.end, DateTime(2026, 8, 20, 6, 30));
    });
  });
}
