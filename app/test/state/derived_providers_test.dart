import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/derived_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';

/// Wed 22:00 -> Thu 06:00. Eight real hours, spanning midnight.
final _nightShift = TrackedBlock(
  id: 'night-shift',
  start: DateTime(2026, 8, 19, 22, 0),
  end: DateTime(2026, 8, 20, 6, 0),
  title: 'Night shift',
  goalId: 'goal-1',
  sourceId: 'manual',
);

Goal _goal() => Goal(
  id: 'goal-1',
  name: 'Test goal',
  categoryId: 'cat-1',
  startDate: DateTime(2020, 1, 1),
  endDate: DateTime(2099, 12, 31),
  scheduleByWeekday: {
    for (var weekday = 1; weekday <= 7; weekday++)
      weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
  },
);

ProviderContainer _containerWith({
  required DateTime selectedDate,
  required DayViewMode mode,
}) => ProviderContainer(
  overrides: [
    allTrackedBlocksProvider.overrideWithValue([_nightShift]),
    allPlannedBlocksProvider.overrideWithValue([]),
    goalsProvider.overrideWithValue([_goal()]),
    selectedDateProvider.overrideWith((ref) => selectedDate),
    dayViewModeProvider.overrideWith((ref) => mode),
  ],
);

void main() {
  group('dayTotalsProvider: an overnight block counts once per window', () {
    test(
      'registered time across a 3-day window equals the block\'s real '
      'duration, even though it is drawn on both columns it touches',
      () {
        final container = _containerWith(
          selectedDate: DateTime(2026, 8, 19),
          mode: DayViewMode.threeDay,
        );
        addTearDown(container.dispose);

        final (_, _, registered, _) = container.read(dayTotalsProvider);

        expect(registered, const Duration(hours: 8));
      },
    );

    test('the same block in single-day mode is unaffected', () {
      final container = _containerWith(
        selectedDate: DateTime(2026, 8, 19),
        mode: DayViewMode.day,
      );
      addTearDown(container.dispose);

      final (_, _, registered, _) = container.read(dayTotalsProvider);

      expect(registered, const Duration(hours: 8));
    });
  });
}
