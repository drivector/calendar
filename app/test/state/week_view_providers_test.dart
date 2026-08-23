import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/models/untracked_gap.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/derived_providers.dart';
import 'package:calendar_tracker/state/week_view_providers.dart';

void main() {
  group('weekDaySummariesProvider', () {
    test('covers the 7 days of the week containing the selected date, Monday first', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedDateProvider.notifier).state = DateTime(2026, 8, 20); // Thursday

      final days = container.read(weekDaySummariesProvider);

      expect(days, hasLength(7));
      expect(days.first.date, DateTime(2026, 8, 17)); // Monday
      for (var i = 0; i < 7; i++) {
        expect(days[i].date, DateTime(2026, 8, 17).add(Duration(days: i)));
      }
    });

    test('a day with real blocks reports real per-category hours, not synthetic ones', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedDateProvider.notifier).state = DateTime(2026, 8, 20);

      final days = container.read(weekDaySummariesProvider);
      final thursday = days.firstWhere((d) => d.date == DateTime(2026, 8, 20));

      // From mock_day_20aug.dart's tracked blocks for 20 Aug.
      expect(thursday.actualHoursByCategory[walkingCategoryId], closeTo(0.8, 0.001));
      expect(thursday.actualHoursByCategory[deepWorkCategoryId], closeTo(1.75, 0.001));
      expect(
        thursday.actualHoursByCategory[meetingsCategoryId],
        closeTo(40 / 60 + 125 / 60, 0.001),
      );
    });

    test('untracked hours match computeUntrackedGaps run against that day directly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final date = DateTime(2026, 8, 20);
      container.read(selectedDateProvider.notifier).state = date;

      final days = container.read(weekDaySummariesProvider);
      final thursday = days.firstWhere((d) => d.date == date);

      final tracked = container
          .read(allTrackedBlocksProvider)
          .where((b) => isSameDay(b.start, date))
          .toList();
      final (windowStart, windowEnd) = dayWindowFor(date);
      final expectedGaps = computeUntrackedGaps(
        tracked: tracked,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      final expectedHours =
          expectedGaps.fold<double>(0, (t, g) => t + g.duration.inMinutes / 60);

      expect(thursday.untrackedHours, closeTo(expectedHours, 0.001));
    });

    test('a week with no logged activity reports honest empty days', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Far from any seeded mock/dummy data.
      container.read(selectedDateProvider.notifier).state = DateTime(2030, 1, 7);

      final days = container.read(weekDaySummariesProvider);

      for (final day in days) {
        expect(day.plannedHoursByCategory, isEmpty);
        expect(day.actualHoursByCategory, isEmpty);
        expect(day.untrackedHours, closeTo(11.0, 0.001)); // the full 07:00-18:00 window
      }
    });

    test('navigating to a different week changes which days are shown', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedDateProvider.notifier).state = DateTime(2026, 8, 20);
      final firstWeek = container.read(weekDaySummariesProvider);

      container.read(selectedDateProvider.notifier).state = DateTime(2026, 8, 27);
      final nextWeek = container.read(weekDaySummariesProvider);

      expect(nextWeek.first.date, firstWeek.first.date.add(const Duration(days: 7)));
    });
  });
}
