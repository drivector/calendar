import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';
import 'package:calendar_tracker/features/categories/categories_screen.dart';
import 'package:calendar_tracker/features/day_view/widgets/day_header_bar.dart';
import 'package:calendar_tracker/features/day_view/widgets/time_body_grid.dart';
import 'package:calendar_tracker/features/goals/goals_screen.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_detail_sheet.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/features/log_activity/log_activity_screen.dart';
import 'package:calendar_tracker/features/week_view/capacity_screen.dart';
import 'package:calendar_tracker/features/week_view/week_view_screen.dart';
import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/shared/widgets/step_arrow_button.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';
import 'package:calendar_tracker/state/log_entry_providers.dart';
import 'package:calendar_tracker/state/root_shell_providers.dart';

import 'support/firestore_test_fixtures.dart';

/// Every screen test below exercises [RootShell] content, which sits behind
/// the Firebase auth gate — so each pump needs a fake signed-in user with a
/// Firestore backing it. A fresh [MockFirebaseAuth]/[FakeFirebaseFirestore]
/// pair per call keeps state from leaking between tests. The fake Firestore
/// is pre-seeded with the same mock/dummy data the old in-memory providers
/// used to boot with, so existing screen assertions ("Walk 45 m", "20 Aug",
/// ...) still hold — a real account starts empty; only tests seed data.
Future<List<Override>> _signedInOverrides() async {
  const uid = 'test-uid';
  final firestore = await seededFirestore(uid);

  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'test@example.com'),
      ),
    ),
    firestoreProvider.overrideWithValue(firestore),
    selectedDateProvider.overrideWith((ref) => mockDay),
  ];
}

/// Same as [_signedInOverrides] but with a bare, unseeded Firestore — for
/// exercising the brand-new-account (no categories yet) paths.
Future<List<Override>> _signedInEmptyOverrides() async {
  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'empty-test-uid', email: 'empty@example.com'),
      ),
    ),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    selectedDateProvider.overrideWith((ref) => mockDay),
  ];
}

void main() {
  testWidgets('Day view renders the mock day without layout errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walk 45 m'), findsOneWidget);
    expect(find.text('2 h 35 untracked'), findsOneWidget);
  });

  testWidgets('Day view: the header arrows step to the next/previous day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 Aug'), findsOneWidget);

    final arrows = find.descendant(
      of: find.byType(DayHeaderBar),
      matching: find.byType(StepArrowButton),
    );
    expect(arrows, findsNWidgets(2)); // previous, then next

    await tester.tap(arrows.at(1)); // next
    await tester.pumpAndSettle();
    expect(find.text('21 Aug'), findsOneWidget);

    await tester.tap(arrows.at(0)); // previous
    await tester.tap(arrows.at(0)); // previous
    await tester.pumpAndSettle();
    expect(find.text('19 Aug'), findsOneWidget);
  });

  testWidgets('Day view: a leftward swipe on the timeline advances to the next day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 Aug'), findsOneWidget);

    await tester.fling(find.byType(TimeBodyGrid), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('21 Aug'), findsOneWidget);
  });

  testWidgets('Tapping the untracked gap opens the claim sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    // The timeline auto-scrolls to the first event, so the gap being
    // tapped may start outside the viewport — bring it into view first.
    await tester.ensureVisible(find.text('2 h 35 untracked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 h 35 untracked'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
  });

  testWidgets('Tab bar switches through all 4 tabs without layout errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    for (final tab in ['WEEK', 'GOALS', '+ LOG', 'DAY']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after tapping $tab');
    }
  });

  testWidgets('Goals: a leftward swipe steps to the next tab (+ Log)',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    expect(container.read(currentTabIndexProvider), 2);

    // Goals has no competing horizontal gesture (unlike Day/Week, which use
    // swipe for date navigation), so a swipe here is free to mean
    // "next/previous tab".
    await tester.fling(find.byType(GoalsScreen), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 3);
  });

  testWidgets('Log activity: a rightward swipe steps to the previous tab (Goals)',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();
    expect(container.read(currentTabIndexProvider), 3);

    await tester.fling(find.byType(LogActivityScreen), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 2);
  });

  testWidgets('Log activity: swiping left at the last tab clamps, not wraps',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();
    expect(container.read(currentTabIndexProvider), 3);

    // + Log is already the last tab — swiping further "next" should stay
    // put, not wrap around to Day.
    await tester.fling(find.byType(LogActivityScreen), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 3);
  });

  testWidgets('Week screen renders day rows and the goals footer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WEEK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tracked'), findsOneWidget);
    expect(find.text('Against goals'), findsOneWidget);
  });

  testWidgets('Week view: the header arrows step to the next/previous week',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WEEK'));
    await tester.pumpAndSettle();

    expect(find.text('Week 17 – 23 Aug'), findsOneWidget);

    final arrows = find.descendant(
      of: find.byType(WeekViewScreen),
      matching: find.byType(StepArrowButton),
    );
    expect(arrows, findsNWidgets(2)); // previous, then next

    await tester.tap(arrows.at(1)); // next
    await tester.pumpAndSettle();
    expect(find.text('Week 24 – 30 Aug'), findsOneWidget);

    await tester.tap(arrows.at(0)); // previous
    await tester.pumpAndSettle();
    expect(find.text('Week 17 – 23 Aug'), findsOneWidget);
  });

  testWidgets(
      'Week: the capacity link opens per-day free time and per-goal room, and close returns to Week',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WEEK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('capacity'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CapacityScreen), findsOneWidget);
    expect(find.text('Capacity'), findsOneWidget);

    // Free time per day — every day of the mock week shows up.
    expect(find.text('FREE TIME PER DAY'), findsOneWidget);
    expect(find.text('MON 17'), findsOneWidget);
    expect(find.text('SUN 23'), findsOneWidget);

    // Room toward goals — a target goal appears with its planned/target
    // split, e.g. "Walking · planned X / Y h".
    expect(find.text('ROOM TOWARD GOALS'), findsOneWidget);
    expect(find.textContaining('Walking · planned'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(find.byType(CapacityScreen), findsNothing);
    expect(find.byType(WeekViewScreen), findsOneWidget);
  });

  testWidgets(
      'Week: a day planned past its window reports overplanned instead of negative free time',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    // 12 hours of manually planned time on Monday — more than the 11h
    // 07:00–18:00 window — on top of whatever the seed data already has.
    await container.read(plannedBlocksRepositoryProvider).upsert(
          PlannedBlock(
            id: 'test-overplan-mon',
            start: DateTime(2026, 8, 17, 6, 0),
            end: DateTime(2026, 8, 17, 18, 0),
            title: 'Everything',
            categoryId: walkingCategoryId,
          ),
        );
    await tester.pump();

    await tester.tap(find.text('WEEK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('capacity'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('over by'), findsWidgets);
  });

  testWidgets('Goals screen renders a block per mock goal',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    // Pace/cap status is computed from real tracked-block data now (not a
    // fabricated baseline) — just confirm every goal shows some status,
    // without pinning to which one.
    final hasStatusText = find.textContaining('on pace').evaluate().isNotEmpty ||
        find.textContaining('behind pace').evaluate().isNotEmpty ||
        find.textContaining('over cap by').evaluate().isNotEmpty;
    expect(hasStatusText, isTrue);
  });

  testWidgets('Log activity: filling the form computes a duration',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget); // duration, empty

    await tester.tap(find.text('deep work'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('20.0 h/wk'), findsOneWidget);
  });

  testWidgets('Tapping a day in the Week view opens that day in Day view',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WEEK'));
    await tester.pumpAndSettle();

    // mockWeekStart is the Monday before the mock day (20 Aug) — 17 Aug.
    await tester.tap(find.text('MON 17'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('17 Aug'), findsOneWidget);
  });

  testWidgets('Goals: tapping a goal opens its detail with activity',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PLANNED THIS WEEK'), findsOneWidget);
    expect(find.text('ACTUAL THIS WEEK'), findsOneWidget);
    // Walking's one tracked block on the mock day, shown as an actual row.
    // The same title also exists (off-stage) in the underlying Day view, so
    // scope the search to the detail sheet itself.
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('Walk 48 m'),
      ),
      findsOneWidget,
    );
    expect(find.text('EDIT'), findsOneWidget);
  });

  testWidgets(
      "Goals: an ongoing goal's detail sheet shows its start and end date in one row",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walking')); // ongoing, per mock_goals.dart
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('active since'), findsOneWidget);
    expect(find.text('runs'), findsNothing);
    // mock_goals.dart's ongoing goals run 1 Jan 2020 – 31 Dec 2099, both in
    // the one "active since" row.
    expect(find.text('1 Jan 2020 – 31 Dec 2099'), findsOneWidget);
  });

  testWidgets(
      "Goals: a goal's detail sheet shows every weekday's own target, not just today's",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    // Walking: 1h Mon-Fri, 2h30 Sat-Sun, per mock_goals.dart.
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('1 h'), findsNWidgets(5)); // Mon-Fri
    expect(find.text('2 h 30'), findsNWidgets(2)); // Sat-Sun
  });

  testWidgets('Goals: editing from the detail sheet and deleting removes it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsOneWidget);

    await tester.ensureVisible(find.text('DELETE GOAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE GOAL'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walking'), findsNothing);
  });

  testWidgets(
      'Goals: closing an edit with no changes closes immediately, no confirmation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save changes?'), findsNothing);
    expect(find.text('Edit goal'), findsNothing);
  });

  testWidgets(
      'Goals: closing an edit with unsaved changes asks to save — Keep editing stays on the sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Walking (evenings)');
    await tester.pumpAndSettle();

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.text('KEEP EDITING'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save changes?'), findsNothing);
    // Still on the edit sheet, with the typed change intact.
    expect(find.text('Edit goal'), findsOneWidget);
    expect(find.text('Walking (evenings)'), findsOneWidget);
  });

  testWidgets(
      'Goals: confirming Discard closes the edit sheet without saving',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Walking (evenings)');
    await tester.pumpAndSettle();

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit goal'), findsNothing);
    // The original goal is untouched — the edited name was never saved.
    expect(find.text('Walking (evenings)'), findsNothing);
    expect(find.text('Walking'), findsOneWidget);
  });

  testWidgets(
      'Goals: confirming Save from the close prompt saves the changes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Walking (evenings)');
    await tester.pumpAndSettle();

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit goal'), findsNothing);
    // The edit was actually saved this time, not discarded.
    expect(find.text('Walking (evenings)'), findsOneWidget);
    expect(find.text('Walking'), findsNothing);
  });

  testWidgets(
      'Goals: tapping outside the edit sheet with unsaved changes also asks to save',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Piano');
    await tester.pumpAndSettle();

    // A tap near the very top of the screen lands on the modal barrier
    // above the sheet, not on the sheet's own content.
    await tester.tapAt(const Offset(200, 10));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.text('KEEP EDITING'));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsNothing); // still "New goal"
    expect(find.text('New goal'), findsOneWidget);
    expect(find.text('Piano'), findsOneWidget);
  });

  testWidgets(
      "Goals: editing a time-range goal shows its existing per-day ranges, not empty",
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);
    // The mock auth stream's first emission is asynchronous — wait for it
    // before touching anything keyed by the signed-in uid.
    await container.read(authStateChangesProvider.future);

    final workGoal = Goal(
      id: 'goal-work-test',
      name: 'Work',
      categoryId: adminCategoryId,
      type: GoalType.target,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2099, 12, 31),
      scheduleByWeekday: {
        for (var weekday = 1; weekday <= 5; weekday++)
          weekday: [
            const DayScheduleEntry.timeRange(ClockRange(ClockTime(9, 0), ClockTime(18, 0))),
          ],
        DateTime.saturday: const [],
        DateTime.sunday: const [],
      },
    );
    await container.read(goalsRepositoryProvider).upsert(workGoal);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Mon-Fri should show the real 09:00-18:00 range chips; Sat/Sun have no
    // entries at all, so they read "off" with nothing to populate.
    expect(find.text('09:00'), findsWidgets);
    expect(find.text('18:00'), findsWidgets);
    expect(find.text('off'), findsNWidgets(2)); // Sat, Sun day totals only
    // Each weekday row shows the real calendar date, not just "Mon" — the
    // selected day (20 Aug 2026) is a Thursday, so its week runs 17-23 Aug.
    expect(find.textContaining('Mon 17 Aug'), findsOneWidget);
    expect(find.textContaining('Fri 21 Aug'), findsOneWidget);
    // A 09:00-18:00 range is 9h — shown both as the day's total (header)
    // and next to the range itself (derived, not separately editable), so
    // each of the 5 weekdays contributes two "9 h" texts.
    expect(find.text('9 h'), findsNWidgets(10));
  });

  testWidgets('Goals: creating a new goal with per-day targets adds it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget);
    // Every day defaults to one 30-min entry — both the day's own total and
    // its single entry's stepper read "30 m", so 7 days × 2 = 14.
    expect(find.text('30 m'), findsNWidgets(14));

    // Bump Monday's target by 3 steps of 5 minutes (30m -> 45m). Scrolling
    // happens before text entry — a drag gesture landing on the Name field
    // afterwards can disturb its content, so do all scrolling first. "Mon"
    // and its entry's "+" sit in different rows now (header row vs. entry
    // row), sharing the day section's Column as their nearest common
    // ancestor.
    final mondaySection = find.ancestor(
      of: find.textContaining('Mon'), // now "Mon d MMM", e.g. "Mon 17 Aug"
      matching: find.byType(Column),
    ).first;
    final mondayPlus = find.descendant(of: mondaySection, matching: find.text('+'));
    await tester.ensureVisible(mondayPlus);
    await tester.pumpAndSettle();
    await tester.tap(mondayPlus);
    await tester.tap(mondayPlus);
    await tester.tap(mondayPlus);
    await tester.pumpAndSettle();

    // Monday's total and its one entry both now read "45 m".
    expect(find.text('45 m'), findsNWidgets(2));

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    expect(nameField, findsOneWidget, reason: 'exactly one Name field in the goal sheet');
    await tester.enterText(nameField, 'Reading');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets(
      'Goals: the schedule entry buttons are bordered with a real tap target',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    // The "×" remove control: a real 32x32 bordered square, not a bare
    // glyph — same footprint family as the +/- steppers next to it.
    final removeContainerFinder = find
        .ancestor(of: find.text('×').first, matching: find.byType(Container))
        .first;
    expect(tester.getSize(removeContainerFinder), const Size(32, 32));
    final removeDecoration =
        (tester.widget<Container>(removeContainerFinder).decoration as BoxDecoration);
    expect(removeDecoration.border, isNotNull);

    // "+ duration": bordered, with a real (>=32pt) touch target, not just
    // the text's own bounding box.
    final addDurationFinder = find
        .ancestor(of: find.text('+ duration').first, matching: find.byType(Container))
        .first;
    expect(tester.getSize(addDurationFinder).height, greaterThanOrEqualTo(32));
    final addDurationDecoration =
        (tester.widget<Container>(addDurationFinder).decoration as BoxDecoration);
    expect(addDurationDecoration.border, isNotNull);

    // "same every day": same bordered-button treatment.
    final sameEveryDayFinder = find
        .ancestor(of: find.text('same every day'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(sameEveryDayFinder).height, greaterThanOrEqualTo(32));
    final sameEveryDayDecoration =
        (tester.widget<Container>(sameEveryDayFinder).decoration as BoxDecoration);
    expect(sameEveryDayDecoration.border, isNotNull);
  });

  testWidgets(
      "Goals: a day can hold multiple entries that sum together, and each can be removed",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final mondaySection = find.ancestor(
      of: find.textContaining('Mon'), // now "Mon d MMM", e.g. "Mon 17 Aug"
      matching: find.byType(Column),
    ).first;

    // Monday starts with one 30-min entry. Add a second duration entry —
    // the day's total should become the sum of both, not just the last one.
    final addDuration = find.descendant(of: mondaySection, matching: find.text('+ duration'));
    await tester.ensureVisible(addDuration);
    await tester.pumpAndSettle();
    await tester.tap(addDuration);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Day total: 30m + 30m = 1h. The two entries still each read "30 m".
    expect(find.descendant(of: mondaySection, matching: find.text('1 h')), findsOneWidget);
    expect(find.descendant(of: mondaySection, matching: find.text('30 m')), findsNWidgets(2));

    // Removing one entry (its own "×") brings the day back to a single
    // 30-min entry — total and entry both read "30 m" again.
    final removeButtons = find.descendant(of: mondaySection, matching: find.text('×'));
    await tester.ensureVisible(removeButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.descendant(of: mondaySection, matching: find.text('30 m')), findsNWidgets(2));
    expect(find.descendant(of: mondaySection, matching: find.text('1 h')), findsNothing);
  });

  testWidgets(
      'Goals: creating a new duration-only goal does not show up as a planned block in the Day view',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Piano');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Back on the Day tab automatically (creating a goal doesn't navigate,
    // but the app opens on Day and the sheet closes onto whatever's behind
    // it — Goals in this case, so switch to Day explicitly).
    await tester.tap(find.text('DAY'));
    await tester.pumpAndSettle();

    // The new goal is a duration-mode target with no fixed time — a plain
    // duration has nowhere real to be placed, so it must not appear on the
    // calendar at all, only count toward the goal's weekly target.
    expect(
      find.descendant(of: find.byType(TimeBodyGrid), matching: find.text('Piano')),
      findsNothing,
    );
  });

  testWidgets(
      "Goals: a duration-only goal's detail sheet shows nothing planned, even though it has a weekly target",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Piano');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Piano'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The goal still has a real weekly target (30 min/day, the sheet's
    // default) — it just never materializes as a block anywhere, since a
    // plain duration has no clock time to place it at. (Piano defaults into
    // the Walking category, which already has seeded planned blocks of its
    // own — those are unrelated to this goal and may still show up, per
    // goal_detail_sheet.dart's existing category-based matching; what
    // matters here is that no block titled "Piano" itself is among them.)
    // Just the sheet's own title — no planned-row duplicate of it within
    // the sheet (the Goals list row behind the sheet also says "Piano",
    // hence scoping to GoalDetailSheet rather than counting site-wide).
    expect(
      find.descendant(of: find.byType(GoalDetailSheet), matching: find.text('Piano')),
      findsOneWidget,
    );
    expect(find.textContaining('3 h 30 this week'), findsOneWidget);
  });

  testWidgets('Goals: "same every day" applies Monday to every day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final mondaySection = find.ancestor(
      of: find.textContaining('Mon'), // now "Mon d MMM", e.g. "Mon 17 Aug"
      matching: find.byType(Column),
    ).first;
    final mondayPlus = find.descendant(of: mondaySection, matching: find.text('+'));
    await tester.ensureVisible(mondayPlus);
    await tester.pumpAndSettle();
    await tester.tap(mondayPlus);
    await tester.pumpAndSettle(); // Monday now 35m, others still 30m

    await tester.ensureVisible(find.text('same every day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('same every day'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Every day's total and its one entry both now read "35 m".
    expect(find.text('35 m'), findsNWidgets(14));
  });

  testWidgets('Log activity: saving actually creates a tracked block',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Evening walk');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 20, minute: 0))
      ..setEnd(const TimeOfDay(hour: 20, minute: 30))
      ..setGoal('goal-walking');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tracked = container.read(allTrackedBlocksProvider);
    expect(tracked.any((b) => b.title == 'Evening walk' && b.sourceId == 'manual'), isTrue);
    // Saving returns to the Day tab, where the new block should now render.
    expect(find.text('Evening walk'), findsOneWidget);
  });

  testWidgets(
      'Goals: a planned block for a goal\'s category shows as planned hours',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    final selectedDate = container.read(selectedDateProvider);
    await container.read(plannedBlocksRepositoryProvider).upsert(
          PlannedBlock(
            id: 'test-plan-walk',
            start: DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 21, 0),
            end: DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 22, 30),
            title: 'Evening walk',
            categoryId: walkingCategoryId,
          ),
        );
    await tester.pump();

    final progressList = container.read(goalProgressListProvider);
    final walking = progressList.firstWhere((p) => p.goal.categoryId == walkingCategoryId);
    // The new 1.5h planned block is on top of whatever was already planned.
    expect(walking.plannedHours, greaterThanOrEqualTo(1.5));

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('planned'), findsWidgets);
  });

  testWidgets(
      'Categories: a new category needs a goal of its own before it shows up as a Log activity chip',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('categories'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);

    await tester.tap(find.text('+ NEW CATEGORY'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Reading');
    await tester.tap(find.text('CREATE CATEGORY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reading'), findsOneWidget); // category row, as typed

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    // Logging is goal-first now — the bare category alone isn't enough to
    // log against; there needs to be a goal for it too.
    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();
    expect(find.text('reading'), findsNothing);

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Reading');
    await tester.pumpAndSettle();

    final readingCategoryChip = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.text('reading'),
    );
    await tester.ensureVisible(readingCategoryChip);
    await tester.pumpAndSettle();
    await tester.tap(readingCategoryChip);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    expect(find.text('reading'), findsOneWidget); // now selectable, by goal
  });

  testWidgets(
      'Goals: a date-bound goal only appears in its window',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    final selectedDate = container.read(selectedDateProvider);
    await container.read(goalsRepositoryProvider).upsert(
          Goal(
            id: 'test-challenge',
            name: 'Next month challenge',
            categoryId: walkingCategoryId,
            type: GoalType.target,
            scheduleByWeekday: {
              for (var weekday = 1; weekday <= 7; weekday++)
                weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
            },
            startDate: selectedDate.add(const Duration(days: 30)),
            endDate: selectedDate.add(const Duration(days: 60)),
          ),
        );
    await tester.pump();

    // Not active today — shouldn't show up yet.
    expect(
      container.read(goalProgressListProvider).any((p) => p.goal.id == 'test-challenge'),
      isFalse,
    );

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Next month challenge'), findsNothing);

    // Jump the selected date forward into the goal's window.
    container.read(selectedDateProvider.notifier).state =
        selectedDate.add(const Duration(days: 45));
    await tester.pumpAndSettle();

    expect(
      container.read(goalProgressListProvider).any((p) => p.goal.id == 'test-challenge'),
      isTrue,
    );
    expect(find.text('Next month challenge'), findsOneWidget);
  });

  testWidgets(
      'Goals: tapping + New goal with no categories shows a message instead of opening the sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInEmptyOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    expect(find.text('Create a category first'), findsOneWidget);
    expect(find.text('CREATE GOAL'), findsNothing);
  });

  testWidgets(
      'Day view: tapping empty space with no categories shows a message instead of opening the sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: await _signedInEmptyOverrides(), child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    // Tap well into the empty timeline, away from any header controls.
    await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
    await tester.pumpAndSettle();

    expect(find.text('Create a category first'), findsOneWidget);
    expect(find.text('ADD PLAN'), findsNothing);
    expect(find.text('ADD ACTUAL'), findsNothing);
  });
}
