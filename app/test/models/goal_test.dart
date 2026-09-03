import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';

void main() {
  group('Goal.toMap / fromMap', () {
    test('a weekly-mode goal round-trips with an empty scheduleByDate', () {
      final goal = Goal(
        id: 'goal-1',
        name: 'Walking',
        categoryId: 'walking',
        scheduleByWeekday: {
          DateTime.monday: [
            const DayScheduleEntry.duration(Duration(minutes: 30)),
          ],
        },
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      final restored = Goal.fromMap('goal-1', goal.toMap());

      expect(restored.scheduleMode, GoalScheduleMode.weekly);
      expect(
        restored.targetForWeekday(DateTime.monday),
        const Duration(minutes: 30),
      );
      expect(restored.scheduleByDate, isEmpty);
    });

    test(
      'a byDate-mode goal round-trips its per-date schedule, keyed back '
      'to the same real dates',
      () {
        final goal = Goal(
          id: 'goal-2',
          name: 'Challenge',
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
              const DayScheduleEntry.duration(Duration(minutes: 20)),
            ],
          },
          startDate: DateTime(2026, 8, 20),
          endDate: DateTime(2026, 8, 24),
        );

        final restored = Goal.fromMap('goal-2', goal.toMap());

        expect(restored.scheduleMode, GoalScheduleMode.byDate);
        expect(
          restored.targetForDate(DateTime(2026, 8, 20)),
          const Duration(minutes: 45),
        );
        expect(
          restored.targetForDate(DateTime(2026, 8, 22)),
          const Duration(minutes: 20),
        );
        expect(restored.targetForDate(DateTime(2026, 8, 21)), Duration.zero);
      },
    );

    test(
      'a map with no scheduleMode/scheduleByDate at all (data written '
      'before this feature existed) still parses as a weekly goal',
      () {
        final legacyMap = {
          'name': 'Old goal',
          'categoryId': 'work',
          'scheduleByWeekday': {
            '1': [
              {'durationMinutes': 30},
            ],
          },
          'startDate': DateTime(2026, 1, 1).toIso8601String(),
          'endDate': DateTime(2026, 12, 31).toIso8601String(),
        };

        final restored = Goal.fromMap('goal-legacy', legacyMap);

        expect(restored.scheduleMode, GoalScheduleMode.weekly);
        expect(
          restored.targetForWeekday(DateTime.monday),
          const Duration(minutes: 30),
        );
        expect(restored.scheduleByDate, isEmpty);
      },
    );
  });
}
