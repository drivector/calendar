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

    test(
      'a goal with no schedule for a weekday generates nothing that day',
      () {
        final work = Goal(
          id: 'goal-work',
          name: 'Work',
          categoryId: 'work',
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
      },
    );

    test('a plain-duration entry never generates a block — no clock time to place it at', () {
      final piano = Goal(
        id: 'goal-piano',
        name: 'Piano',
        categoryId: 'piano',
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

    test('a goal outside its active date range generates nothing', () {
      final challenge = Goal(
        id: 'goal-challenge',
        name: 'August challenge',
        categoryId: 'walking',
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

    test(
      'multiple goals with only plain-duration entries generate nothing',
      () {
        final walking = Goal(
          id: 'goal-walking',
          name: 'Walking',
          categoryId: 'walking',
          scheduleByWeekday: _uniform(const Duration(hours: 1)),
          startDate: _ongoingStart,
          endDate: _ongoingEnd,
        );
        final reading = Goal(
          id: 'goal-reading',
          name: 'Reading',
          categoryId: 'reading',
          scheduleByWeekday: _uniform(const Duration(minutes: 30)),
          startDate: _ongoingStart,
          endDate: _ongoingEnd,
        );

        final blocks = generateGoalPlannedBlocksForDate(
          goals: [walking, reading],
          date: DateTime(2026, 8, 20),
        );

        expect(blocks, isEmpty);
      },
    );

    test('a day with two time ranges (a split shift) generates two blocks', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
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
      'an overnight entry (end earlier in the day than start) rolls its '
      'end into the next calendar day, instead of a negative duration',
      () {
        final walking = Goal(
          id: 'goal-walking',
          name: 'Walking',
          categoryId: 'walking',
          startDate: _ongoingStart,
          endDate: _ongoingEnd,
          scheduleByWeekday: {
            DateTime.friday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(23, 0), ClockTime(0, 10)),
              ),
            ],
          },
        );

        final blocks = generateGoalPlannedBlocksForDate(
          goals: [walking],
          date: DateTime(2026, 9, 4), // a Friday
        );

        expect(blocks, hasLength(1));
        expect(blocks.single.start, DateTime(2026, 9, 4, 23, 0));
        // Not DateTime(2026, 9, 4, 0, 10) — that would be *before* start,
        // producing a negative Duration once end.difference(start) runs
        // (the exact bug: it read as +22h50m of unplanned-but-"tracked"
        // drift for a goal nothing was ever logged against).
        expect(blocks.single.end, DateTime(2026, 9, 5, 0, 10));
        expect(blocks.single.duration, const Duration(hours: 1, minutes: 10));
      },
    );

    test('a day mixing a time range and extra duration only generates a block for the time range', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
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

  group('untimedPlannedDurationByCategoryForDate', () {
    test('sums a plain-duration entry into its category', () {
      final piano = Goal(
        id: 'goal-piano',
        name: 'Piano',
        categoryId: 'piano',
        scheduleByWeekday: _uniform(const Duration(minutes: 15)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );

      final totals = untimedPlannedDurationByCategoryForDate(
        goals: [piano],
        date: DateTime(2026, 8, 20),
      );

      expect(totals, {'piano': const Duration(minutes: 15)});
    });

    test('a time-range entry contributes nothing here — it already has a block', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
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

      final totals = untimedPlannedDurationByCategoryForDate(
        goals: [work],
        date: DateTime(2026, 8, 20), // a Thursday
      );

      expect(totals, isEmpty);
    });

    test('a day mixing a time range and extra duration counts only the duration part here', () {
      final work = Goal(
        id: 'goal-work',
        name: 'Work',
        categoryId: 'work',
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

      final totals = untimedPlannedDurationByCategoryForDate(
        goals: [work],
        date: DateTime(2026, 8, 20),
      );

      expect(totals, {'work': const Duration(minutes: 30)});
    });

    test('two goals sharing a category sum together', () {
      final morningWalk = Goal(
        id: 'goal-walk-1',
        name: 'Morning walk',
        categoryId: 'walking',
        scheduleByWeekday: _uniform(const Duration(minutes: 20)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );
      final eveningWalk = Goal(
        id: 'goal-walk-2',
        name: 'Evening walk',
        categoryId: 'walking',
        scheduleByWeekday: _uniform(const Duration(minutes: 25)),
        startDate: _ongoingStart,
        endDate: _ongoingEnd,
      );

      final totals = untimedPlannedDurationByCategoryForDate(
        goals: [morningWalk, eveningWalk],
        date: DateTime(2026, 8, 20),
      );

      expect(totals, {'walking': const Duration(minutes: 45)});
    });

    test('a goal outside its active date range contributes nothing', () {
      final challenge = Goal(
        id: 'goal-challenge',
        name: 'August challenge',
        categoryId: 'reading',
        scheduleByWeekday: _uniform(const Duration(minutes: 30)),
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 15),
      );

      final totals = untimedPlannedDurationByCategoryForDate(
        goals: [challenge],
        date: DateTime(2026, 8, 20), // after the challenge ended
      );

      expect(totals, isEmpty);
    });
  });

  group('GoalScheduleMode.byDate', () {
    test(
      'generateGoalPlannedBlocksForDate uses the exact date\'s own entries, '
      'not a repeating weekday pattern',
      () {
        final challenge = Goal(
          id: 'goal-challenge',
          name: '10k steps challenge',
          categoryId: 'walking',
          scheduleMode: GoalScheduleMode.byDate,
          scheduleByWeekday: const {},
          scheduleByDate: {
            DateTime(2026, 8, 20): [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(7, 0), ClockTime(7, 45)),
              ),
            ],
            DateTime(2026, 8, 22): [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(8, 0), ClockTime(8, 30)),
              ),
            ],
          },
          startDate: DateTime(2026, 8, 20),
          endDate: DateTime(2026, 8, 24),
        );

        final onDay1 = generateGoalPlannedBlocksForDate(
          goals: [challenge],
          date: DateTime(2026, 8, 20),
        );
        expect(onDay1, hasLength(1));
        expect(onDay1.single.start, DateTime(2026, 8, 20, 7, 0));
        expect(onDay1.single.end, DateTime(2026, 8, 20, 7, 45));

        // A day in range but with no entries of its own generates
        // nothing at all — a byDate schedule has no repeating pattern to
        // fall back to for a day it wasn't explicitly given.
        final onDay2 = generateGoalPlannedBlocksForDate(
          goals: [challenge],
          date: DateTime(2026, 8, 21),
        );
        expect(onDay2, isEmpty);

        final onDay3 = generateGoalPlannedBlocksForDate(
          goals: [challenge],
          date: DateTime(2026, 8, 22),
        );
        expect(onDay3, hasLength(1));
        expect(onDay3.single.start, DateTime(2026, 8, 22, 8, 0));
      },
    );

    test(
      'a plain-duration entry for a specific date sums into '
      'untimedPlannedDurationByCategoryForDate only on that date',
      () {
        final challenge = Goal(
          id: 'goal-piano-challenge',
          name: 'Piano practice week',
          categoryId: 'piano',
          scheduleMode: GoalScheduleMode.byDate,
          scheduleByWeekday: const {},
          scheduleByDate: {
            DateTime(2026, 8, 20): [
              const DayScheduleEntry.duration(Duration(minutes: 15)),
            ],
          },
          startDate: DateTime(2026, 8, 20),
          endDate: DateTime(2026, 8, 22),
        );

        expect(
          untimedPlannedDurationByCategoryForDate(
            goals: [challenge],
            date: DateTime(2026, 8, 20),
          ),
          {'piano': const Duration(minutes: 15)},
        );
        expect(
          untimedPlannedDurationByCategoryForDate(
            goals: [challenge],
            date: DateTime(2026, 8, 21),
          ),
          isEmpty,
        );
      },
    );

    test('still respects isActiveOn even with a byDate schedule', () {
      final challenge = Goal(
        id: 'goal-challenge',
        name: 'Challenge',
        categoryId: 'walking',
        scheduleMode: GoalScheduleMode.byDate,
        scheduleByWeekday: const {},
        scheduleByDate: {
          DateTime(2026, 8, 20): [
            const DayScheduleEntry.timeRange(
              ClockRange(ClockTime(7, 0), ClockTime(7, 30)),
            ),
          ],
        },
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 15), // ended before the entry's own date
      );

      final blocks = generateGoalPlannedBlocksForDate(
        goals: [challenge],
        date: DateTime(2026, 8, 20),
      );
      expect(blocks, isEmpty);
    });
  });
}
