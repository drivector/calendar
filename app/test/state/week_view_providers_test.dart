import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/models/untracked_gap.dart';
import 'package:calendar_tracker/models/user_settings.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/derived_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';
import 'package:calendar_tracker/state/week_view_providers.dart';

import '../support/firestore_test_fixtures.dart';

Future<ProviderContainer> _signedInContainer({
  List<Override> extraOverrides = const [],
}) async {
  const uid = 'test-uid';
  final firestore = await seededFirestore(uid);
  final container = ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      ),
      firestoreProvider.overrideWithValue(firestore),
      ...extraOverrides,
    ],
  );
  // The mock auth stream's first emission is asynchronous, and every
  // per-user repository provider depends on it via currentUidProvider — so
  // wait for that first, then for the first Firestore snapshot on each
  // collection this suite reads, before any synchronous `container.read`.
  // Goals in particular matter now: every block's category is resolved by
  // looking up its goalId in the live goals list, not stored on the block
  // itself, so a summary computed before goals has loaded would silently
  // resolve every category to nothing.
  await container.read(authStateChangesProvider.future);
  await container.read(allPlannedBlocksStreamProvider.future);
  await container.read(allTrackedBlocksStreamProvider.future);
  await container.read(goalsStreamProvider.future);
  return container;
}

void main() {
  group('weekDaySummariesProvider', () {
    test('covers the 7 days of the week containing the selected date, Monday first', () async {
      final container = await _signedInContainer();
      addTearDown(container.dispose);
      container.read(selectedDateProvider.notifier).state = DateTime(
        2026,
        8,
        20,
      ); // Thursday

      final days = container.read(weekDaySummariesProvider);

      expect(days, hasLength(7));
      expect(days.first.date, DateTime(2026, 8, 17)); // Monday
      for (var i = 0; i < 7; i++) {
        expect(days[i].date, DateTime(2026, 8, 17).add(Duration(days: i)));
      }
    });

    test('a day with real blocks reports real per-category hours, not synthetic ones', () async {
      final container = await _signedInContainer();
      addTearDown(container.dispose);
      container.read(selectedDateProvider.notifier).state = DateTime(
        2026,
        8,
        20,
      );

      final days = container.read(weekDaySummariesProvider);
      final thursday = days.firstWhere((d) => d.date == DateTime(2026, 8, 20));

      // From mock_day_20aug.dart's tracked blocks for 20 Aug.
      expect(
        thursday.actualHoursByCategory[walkingCategoryId],
        closeTo(0.8, 0.001),
      );
      expect(
        thursday.actualHoursByCategory[deepWorkCategoryId],
        closeTo(1.75, 0.001),
      );
      expect(
        thursday.actualHoursByCategory[meetingsCategoryId],
        closeTo(40 / 60 + 125 / 60, 0.001),
      );
    });

    test('untracked hours match computeUntrackedGaps run against that day directly', () async {
      final container = await _signedInContainer();
      addTearDown(container.dispose);
      final date = DateTime(2026, 8, 20);
      container.read(selectedDateProvider.notifier).state = date;

      final days = container.read(weekDaySummariesProvider);
      final thursday = days.firstWhere((d) => d.date == date);

      final tracked = container
          .read(allTrackedBlocksProvider)
          .where((b) => isSameDay(b.start, date))
          .toList();
      // No settings saved — defaults to the full day, one range.
      final (windowStart, windowEnd) = dayWindowsFor(
        date,
        windows: const [fullDayWindow],
      ).single;
      final expectedGaps = computeUntrackedGaps(
        tracked: tracked,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      final expectedHours = expectedGaps.fold<double>(
        0,
        (t, g) => t + g.duration.inMinutes / 60,
      );

      expect(thursday.untrackedHours, closeTo(expectedHours, 0.001));
    });

    test('a week with no logged activity reports honest empty days', () async {
      // The fixture's own Walking/Deep work goals are ongoing (a 2020–2099
      // span), so they'd otherwise still contribute their own daily
      // untimed schedule to any date's planned hours regardless of how far
      // it is from any actual logged/manual data — overridden away here so
      // this test isolates the thing it actually means to check.
      final container = await _signedInContainer(
        extraOverrides: [goalsProvider.overrideWith((ref) => const [])],
      );
      addTearDown(container.dispose);
      // Far from any seeded mock/dummy data.
      container.read(selectedDateProvider.notifier).state = DateTime(
        2030,
        1,
        7,
      );

      final days = container.read(weekDaySummariesProvider);

      for (final day in days) {
        expect(day.plannedHoursByCategory, isEmpty);
        expect(day.actualHoursByCategory, isEmpty);
        expect(
          day.untrackedHours,
          closeTo(24.0, 0.001),
        ); // no settings saved — defaults to the full 24h window
      }
    });

    test(
      'navigating to a different week changes which days are shown',
      () async {
        final container = await _signedInContainer();
        addTearDown(container.dispose);
        container.read(selectedDateProvider.notifier).state = DateTime(
          2026,
          8,
          20,
        );
        final firstWeek = container.read(weekDaySummariesProvider);

        container.read(selectedDateProvider.notifier).state = DateTime(
          2026,
          8,
          27,
        );
        final nextWeek = container.read(weekDaySummariesProvider);

        expect(
          nextWeek.first.date,
          firstWeek.first.date.add(const Duration(days: 7)),
        );
      },
    );
  });
}
