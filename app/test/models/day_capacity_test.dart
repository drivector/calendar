import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/day_capacity.dart';

void main() {
  group('computeDayCapacity', () {
    test('available is the window minus what is planned', () {
      final day = computeDayCapacity(
        date: DateTime(2026, 8, 17),
        plannedHours: 6.5,
        actualHours: 5,
        windowHours: 11,
      );

      expect(day.availableHours, closeTo(4.5, 0.001));
      expect(day.overplannedHours, 0);
    });

    test('an empty day is fully available', () {
      final day = computeDayCapacity(
        date: DateTime(2026, 8, 17),
        plannedHours: 0,
        actualHours: 0,
      );

      expect(day.availableHours, defaultCapacityWindowHours);
      expect(day.overplannedHours, 0);
    });

    test('planning right up to the window leaves nothing available', () {
      final day = computeDayCapacity(
        date: DateTime(2026, 8, 17),
        plannedHours: 11,
        actualHours: 0,
        windowHours: 11,
      );

      expect(day.availableHours, 0);
      expect(day.overplannedHours, 0);
    });

    test(
      'planning past the window reports overplanned, not negative available',
      () {
        final day = computeDayCapacity(
          date: DateTime(2026, 8, 17),
          plannedHours: 13,
          actualHours: 0,
          windowHours: 11,
        );

        expect(day.availableHours, 0);
        expect(day.overplannedHours, closeTo(2, 0.001));
      },
    );

    test(
      'defaults to the 07:00–18:00 window used elsewhere for "untracked"',
      () {
        final day = computeDayCapacity(
          date: DateTime(2026, 8, 17),
          plannedHours: 0,
          actualHours: 0,
        );
        expect(day.windowHours, 11);
      },
    );
  });
}
