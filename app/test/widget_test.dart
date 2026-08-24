import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';
import 'package:calendar_tracker/features/categories/categories_screen.dart';
import 'package:calendar_tracker/features/day_view/widgets/day_header_bar.dart';
import 'package:calendar_tracker/features/day_view/widgets/time_body_grid.dart';
import 'package:calendar_tracker/features/goals/goals_screen.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_block.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_detail_sheet.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/features/log_activity/activities_screen.dart';
import 'package:calendar_tracker/shell/root_shell.dart';
import 'package:calendar_tracker/features/week_view/capacity_screen.dart';
import 'package:calendar_tracker/features/week_view/week_view_screen.dart';
import 'package:calendar_tracker/models/category.dart';
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

Goal _minimalGoal({required String id, required String categoryId}) => Goal(
  id: id,
  name: 'Test goal',
  categoryId: categoryId,
  startDate: DateTime(2020, 1, 1),
  endDate: DateTime(2099, 12, 31),
  scheduleByWeekday: {
    for (var weekday = 1; weekday <= 7; weekday++)
      weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
  },
);

/// A signed-in account with one goal but **zero categories** — reachable
/// in the real app if every category is later deleted while a goal that
/// referenced one survives (onboarding itself only ever guards against
/// zero *goals*, not zero categories, so this state is real, just not the
/// brand-new-account one). Exercises the "create a category first" guard
/// in Goals/Day without tripping onboarding, since it has a goal.
Future<List<Override>> _signedInNoCategoriesOverrides() async {
  const uid = 'no-categories-uid';
  final firestore = FakeFirebaseFirestore();
  final goal = _minimalGoal(
    id: 'goal-orphaned',
    categoryId: 'deleted-category',
  );
  await firestore
      .collection('users')
      .doc(uid)
      .collection('goals')
      .doc(goal.id)
      .set(goal.toMap());

  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'nocats@example.com'),
      ),
    ),
    firestoreProvider.overrideWithValue(firestore),
    selectedDateProvider.overrideWith((ref) => mockDay),
  ];
}

/// A signed-in account with one category and one matching goal — just
/// enough to have finished onboarding and land in [RootShell] — but no
/// planned or tracked blocks at all, the state a real account is in right
/// after onboarding, before logging any actual activity.
Future<List<Override>> _signedInOnboardedNoActivityOverrides() async {
  const uid = 'onboarded-no-activity-uid';
  final firestore = FakeFirebaseFirestore();
  final userDoc = firestore.collection('users').doc(uid);
  const category = Category(
    id: 'cat-1',
    name: 'Work',
    color: Color(0xFF0278E7),
  );
  final goal = _minimalGoal(id: 'goal-1', categoryId: category.id);
  await userDoc.collection('categories').doc(category.id).set(category.toMap());
  await userDoc.collection('goals').doc(goal.id).set(goal.toMap());

  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'onboarded@example.com'),
      ),
    ),
    firestoreProvider.overrideWithValue(firestore),
    selectedDateProvider.overrideWith((ref) => mockDay),
  ];
}

void main() {
  testWidgets('Day view renders the mock day without layout errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walk 45 m'), findsOneWidget);
    expect(find.text('2h 35m untracked'), findsOneWidget);
  });

  testWidgets('Day view: the header arrows step to the next/previous day', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
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

  testWidgets(
    'Day view: a leftward swipe on the timeline advances to the next day',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('20 Aug'), findsOneWidget);

      await tester.fling(
        find.byType(TimeBodyGrid),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('21 Aug'), findsOneWidget);
    },
  );

  testWidgets('Tapping the untracked gap opens the claim sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The timeline auto-scrolls to the first event, so the gap being
    // tapped may start outside the viewport — bring it into view first.
    await tester.ensureVisible(find.text('2h 35m untracked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2h 35m untracked'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
  });

  testWidgets('Tab bar switches through all 4 tabs without layout errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['WEEK', 'GOALS', 'ACTIVITIES', 'DAY']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after tapping $tab');
    }
  });

  testWidgets('Goals: a leftward swipe steps to the next tab (Activities)', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
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

  testWidgets(
    'Activities: a rightward swipe steps to the previous tab (Goals)',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      expect(container.read(currentTabIndexProvider), 3);

      await tester.fling(
        find.byType(ActivitiesScreen),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(currentTabIndexProvider), 2);
    },
  );

  testWidgets('Activities: swiping left at the last tab clamps, not wraps', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();
    expect(container.read(currentTabIndexProvider), 3);

    // Activities is already the last tab — swiping further "next" should
    // stay put, not wrap around to Day.
    await tester.fling(
      find.byType(ActivitiesScreen),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 3);
  });

  testWidgets('Week screen renders day rows and the goals footer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WEEK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tracked'), findsOneWidget);
    expect(find.text('Against goals'), findsOneWidget);
  });

  testWidgets('Week view: the header arrows step to the next/previous week', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
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
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
    },
  );

  testWidgets(
    'Week: a day planned past its window reports overplanned instead of negative free time',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 12 hours of manually planned time on Monday — more than the 11h
      // 07:00–18:00 window — on top of whatever the seed data already has.
      await container
          .read(plannedBlocksRepositoryProvider)
          .upsert(
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
    },
  );

  testWidgets('Goals screen renders a block per mock goal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    // Pace status is computed from real tracked-block data now (not a
    // fabricated baseline) — just confirm every goal shows some status,
    // without pinning to which one.
    final hasStatusText =
        find.textContaining('on pace').evaluate().isNotEmpty ||
        find.textContaining('behind pace').evaluate().isNotEmpty;
    expect(hasStatusText, isTrue);
  });

  testWidgets(
    'Goals: the complete button appears only when there is unfinished planned '
    'activity, and tapping it fills the gap',
    (WidgetTester tester) async {
      // Every planned block in the standard seeded fixture already has a
      // matching tracked block (by plannedBlockId) — nothing pending, no
      // complete button anywhere, by design. Add one extra Walking-category
      // planned block with no tracked counterpart, so exactly one goal has
      // something to complete.
      const uid = 'test-uid-complete';
      final firestore = await seededFirestore(uid);
      final extraPlan = PlannedBlock(
        id: 'test-extra-walk',
        start: DateTime(2026, 8, 21, 6, 0),
        end: DateTime(2026, 8, 21, 6, 20),
        title: 'Extra walk',
        categoryId: walkingCategoryId,
      );
      await firestore
          .collection('users')
          .doc(uid)
          .collection('plannedBlocks')
          .doc(extraPlan.id)
          .set(extraPlan.toMap());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: uid, email: 'complete@example.com'),
              ),
            ),
            firestoreProvider.overrideWithValue(firestore),
            selectedDateProvider.overrideWith((ref) => mockDay),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();

      // Only Walking has anything pending — Deep work's planned blocks are
      // all already covered.
      final completeButton = find.byWidgetPredicate(
        (w) => w is CompleteGoalButton,
      );
      expect(completeButton, findsOneWidget);

      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The gap is filled — nothing left pending anywhere.
      expect(
        find.byWidgetPredicate((w) => w is CompleteGoalButton),
        findsNothing,
      );
      // A tracked block now exists mirroring the planned one — "Extra
      // walk" now shows twice in Walking's detail sheet: once under
      // PLANNED (the original block, unchanged) and once under ACTUAL
      // (the new tracked block completing it).
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(GoalDetailSheet),
          matching: find.text('Extra walk'),
        ),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'Activities: groups every tracked block into a day-by-day list, most recent day first',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // mockDay (Thu 20 Aug) and the dummy fixture's Monday both have
      // seeded tracked blocks — each should get its own day section.
      expect(find.text('THURSDAY, 20 AUG'), findsOneWidget);
      expect(find.text('MONDAY, 17 AUG'), findsOneWidget);
      // mockDay's tracked blocks (mock_day_20aug.dart), in start-time order
      // within their own day section.
      expect(find.text('Walk 48 m'), findsOneWidget);
      expect(find.text('Deep work 1 h 45'), findsOneWidget);
      expect(find.text('Unplanned call 40 m'), findsOneWidget);
      expect(find.textContaining('07:00–07:48'), findsOneWidget);
      // A block from a different day (dummy_data.dart's Monday).
      expect(find.text('Walk 25 m'), findsOneWidget);

      final walkPosition = tester.getTopLeft(find.text('Walk 48 m')).dy;
      final callPosition = tester
          .getTopLeft(find.text('Unplanned call 40 m'))
          .dy;
      expect(walkPosition, lessThan(callPosition));

      // Thursday (20th) is more recent than Monday (17th) — its section
      // should render above Monday's.
      final thursdayHeaderY = tester
          .getTopLeft(find.text('THURSDAY, 20 AUG'))
          .dy;
      final mondayHeaderY = tester.getTopLeft(find.text('MONDAY, 17 AUG')).dy;
      expect(thursdayHeaderY, lessThan(mondayHeaderY));
    },
  );

  testWidgets(
    'Activities: no activity anywhere says so instead of showing a blank list',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOnboardedNoActivityOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No activity yet.'), findsOneWidget);
    },
  );

  testWidgets("Activities: each row shows its goal next to the title, and tapping it opens "
      "that goal's detail", (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();

    // "Walk 48 m" (mock_day_20aug.dart) is in the Walking category, which
    // backs the "Walking" goal — its name should show right next to the
    // block's own title, scoped to that row so it can't be confused with
    // the "Walking" label sitting next to any of the week's other walks.
    final titleRow = find
        .ancestor(of: find.text('Walk 48 m'), matching: find.byType(Row))
        .first;
    final goalLabel = find.descendant(
      of: titleRow,
      matching: find.text('Walking'),
    );
    expect(goalLabel, findsOneWidget);

    await tester.ensureVisible(goalLabel);
    await tester.pumpAndSettle();
    await tester.tap(goalLabel);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GoalDetailSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('EDIT'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    "Activities: a block whose category backs no goal shows no goal label — "
    "nothing to tap",
    (WidgetTester tester) async {
      const uid = 'test-uid-no-goal';
      final firestore = await seededFirestore(uid);
      // Delete the Walking goal itself — its category and tracked blocks
      // stay, same as if the goal had been removed after logging.
      await firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc('goal-walking')
          .delete();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: uid, email: 'nogoal@example.com'),
              ),
            ),
            firestoreProvider.overrideWithValue(firestore),
            selectedDateProvider.overrideWith((ref) => mockDay),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Walk 48 m'),
        findsOneWidget,
      ); // the block itself is still there
      final titleRow = find
          .ancestor(of: find.text('Walk 48 m'), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: titleRow, matching: find.text('Walking')),
        findsNothing,
      );
    },
  );

  testWidgets('Log activity: filling the form computes a duration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    // Day defaults to whatever the app is currently showing (mockDay, a
    // Thursday) — asking the user to pick it explicitly, rather than
    // silently assuming it, but not making them do so for the common case.
    expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // duration, empty

    await tester.tap(find.text('deep work'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('20h/wk'), findsOneWidget);
  });

  testWidgets('Tapping a day in the Week view opens that day in Day view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
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

  testWidgets('Goals: tapping a goal opens its detail with activity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.text('ACTUAL'), findsOneWidget);
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

  testWidgets('Goals: stepping to next week in the detail sheet shows that week\'s own activity, '
      'and stepping back restores this week\'s', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    // mockDay (20 Aug 2026) sits in the 17–23 Aug week, which has seeded
    // Walking activity every day (dummy_data.dart) plus the built-in
    // "Walk 48 m" tracked block on the 20th itself.
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('Walk 48 m'),
      ),
      findsOneWidget,
    );

    final nextArrow = find.descendant(
      of: find.byType(GoalDetailSheet),
      matching: find.byWidgetPredicate(
        (w) => w is StepArrowButton && w.direction == StepDirection.next,
      ),
    );
    expect(nextArrow, findsOneWidget);

    await tester.tap(nextArrow);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 24–30 Aug has no seeded activity at all.
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('Walk 48 m'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('Nothing planned this week.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('No activity this week.'),
      ),
      findsOneWidget,
    );

    final prevArrow = find.descendant(
      of: find.byType(GoalDetailSheet),
      matching: find.byWidgetPredicate(
        (w) => w is StepArrowButton && w.direction == StepDirection.previous,
      ),
    );
    await tester.tap(prevArrow);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(GoalDetailSheet),
        matching: find.text('Walk 48 m'),
      ),
      findsOneWidget,
    );

    // Browsing weeks inside the sheet must not have touched the app's
    // globally selected date — close the sheet and confirm Day view still
    // shows the original mock day untouched.
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY'));
    await tester.pumpAndSettle();

    expect(find.text('20 Aug'), findsOneWidget);
  });

  testWidgets(
    'Goals: a leftward swipe on the detail sheet also steps to next week, no button needed',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(GoalDetailSheet),
          matching: find.text('Walk 48 m'),
        ),
        findsOneWidget,
      );

      await tester.fling(
        find.byType(GoalDetailSheet),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Same "next week is empty" signal the button-tap test checks — a
      // fling should land on the same state a next-arrow tap would.
      expect(
        find.descendant(
          of: find.byType(GoalDetailSheet),
          matching: find.text('Walk 48 m'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(GoalDetailSheet),
          matching: find.text('Nothing planned this week.'),
        ),
        findsOneWidget,
      );

      await tester.fling(
        find.byType(GoalDetailSheet),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(GoalDetailSheet),
          matching: find.text('Walk 48 m'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "Goals: an ongoing goal's detail sheet shows its start and end date in one row",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Walking')); // ongoing, per mock_goals.dart
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('runs'), findsNothing);
      // mock_goals.dart's ongoing goals run 1 Jan 2020 – 31 Dec 2099, both in
      // the one "active" row.
      expect(find.text('1 Jan 2020 – 31 Dec 2099'), findsOneWidget);
    },
  );

  testWidgets(
    "Goals: a goal's detail sheet shows every weekday's own target and actual, not just today's",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();
      // Walking: 1h Mon-Fri, 2h30 Sat-Sun, per mock_goals.dart.
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final perDayRow = find.byKey(const Key('goalDetailTargetPerDayRow'));
      for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
        expect(
          find.descendant(of: perDayRow, matching: find.text(day)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: perDayRow, matching: find.text('1h')),
        findsNWidgets(5),
      ); // Mon-Fri target
      expect(
        find.descendant(of: perDayRow, matching: find.text('2h 30m')),
        findsNWidgets(2),
      ); // Sat-Sun target
      // Actual walked, per day, from mock_day_20aug.dart + dummy_data.dart —
      // scoped to the per-day row specifically, since the same durations
      // also (separately, correctly) appear on each block's own row further
      // down in "ACTUAL THIS WEEK".
      // Mon 25m, Tue 35m, Wed 20m, Thu 48m, Fri 20m, Sat 1h15, Sun 1h20.
      expect(
        find.descendant(of: perDayRow, matching: find.text('25m')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: perDayRow, matching: find.text('35m')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: perDayRow, matching: find.text('20m')),
        findsNWidgets(2),
      ); // Wed and Fri
      expect(
        find.descendant(of: perDayRow, matching: find.text('48m')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: perDayRow, matching: find.text('1h 15m')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: perDayRow, matching: find.text('1h 20m')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Goals: editing from the detail sheet and deleting removes it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
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
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
    },
  );

  testWidgets(
    'Goals: closing an edit with unsaved changes asks to save — Keep editing stays on the sheet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
    },
  );

  testWidgets(
    'Goals: confirming Discard closes the edit sheet without saving',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
    },
  );

  testWidgets(
    'Goals: confirming Save from the close prompt saves the changes',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
    },
  );

  testWidgets(
    'Goals: tapping outside the edit sheet with unsaved changes also asks to save',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
    },
  );

  testWidgets(
    "Goals: editing a time-range goal shows its existing per-day ranges, not empty",
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);
      // The mock auth stream's first emission is asynchronous — wait for it
      // before touching anything keyed by the signed-in uid.
      await container.read(authStateChangesProvider.future);

      final workGoal = Goal(
        id: 'goal-work-test',
        name: 'Work',
        categoryId: adminCategoryId,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2099, 12, 31),
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 5; weekday++)
            weekday: [
              const DayScheduleEntry.timeRange(
                ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
              ),
            ],
          DateTime.saturday: const [],
          DateTime.sunday: const [],
        },
      );
      await container.read(goalsRepositoryProvider).upsert(workGoal);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
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
      expect(find.text('9h'), findsNWidgets(10));
    },
  );

  testWidgets('Goals: creating a new goal with per-day targets adds it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget);
    // Every day defaults to one 30-min entry — both the day's own total and
    // its single entry's stepper read "30 m", so 7 days × 2 = 14.
    expect(find.text('30m'), findsNWidgets(14));

    // Bump Monday's target by 3 steps of 5 minutes (30m -> 45m). Scrolling
    // happens before text entry — a drag gesture landing on the Name field
    // afterwards can disturb its content, so do all scrolling first. "Mon"
    // and its entry's "+" sit in different rows now (header row vs. entry
    // row), sharing the day section's Column as their nearest common
    // ancestor.
    final mondaySection = find
        .ancestor(
          of: find.textContaining('Mon'), // now "Mon d MMM", e.g. "Mon 17 Aug"
          matching: find.byType(Column),
        )
        .first;
    final mondayPlus = find.descendant(
      of: mondaySection,
      matching: find.text('+'),
    );
    await tester.ensureVisible(mondayPlus);
    await tester.pumpAndSettle();
    await tester.tap(mondayPlus);
    await tester.tap(mondayPlus);
    await tester.tap(mondayPlus);
    await tester.pumpAndSettle();

    // Monday's total and its one entry both now read "45m".
    expect(find.text('45m'), findsNWidgets(2));

    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    expect(
      nameField,
      findsOneWidget,
      reason: 'exactly one Name field in the goal sheet',
    );
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
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
          (tester.widget<Container>(removeContainerFinder).decoration
              as BoxDecoration);
      expect(removeDecoration.border, isNotNull);

      // "+ duration": bordered, with a real (>=32pt) touch target, not just
      // the text's own bounding box.
      final addDurationFinder = find
          .ancestor(
            of: find.text('+ duration').first,
            matching: find.byType(Container),
          )
          .first;
      expect(
        tester.getSize(addDurationFinder).height,
        greaterThanOrEqualTo(32),
      );
      final addDurationDecoration =
          (tester.widget<Container>(addDurationFinder).decoration
              as BoxDecoration);
      expect(addDurationDecoration.border, isNotNull);

      // "same every day": same bordered-button treatment.
      final sameEveryDayFinder = find
          .ancestor(
            of: find.text('same every day'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        tester.getSize(sameEveryDayFinder).height,
        greaterThanOrEqualTo(32),
      );
      final sameEveryDayDecoration =
          (tester.widget<Container>(sameEveryDayFinder).decoration
              as BoxDecoration);
      expect(sameEveryDayDecoration.border, isNotNull);
    },
  );

  testWidgets(
    "Goals: a day can hold multiple entries that sum together, and each can be removed",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ NEW GOAL'));
      await tester.pumpAndSettle();

      final mondaySection = find
          .ancestor(
            of: find.textContaining(
              'Mon',
            ), // now "Mon d MMM", e.g. "Mon 17 Aug"
            matching: find.byType(Column),
          )
          .first;

      // Monday starts with one 30-min entry. Add a second duration entry —
      // the day's total should become the sum of both, not just the last one.
      final addDuration = find.descendant(
        of: mondaySection,
        matching: find.text('+ duration'),
      );
      await tester.ensureVisible(addDuration);
      await tester.pumpAndSettle();
      await tester.tap(addDuration);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Day total: 30m + 30m = 1h. The two entries still each read "30 m".
      expect(
        find.descendant(of: mondaySection, matching: find.text('1h')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mondaySection, matching: find.text('30m')),
        findsNWidgets(2),
      );

      // Removing one entry (its own "×") brings the day back to a single
      // 30-min entry — total and entry both read "30 m" again.
      final removeButtons = find.descendant(
        of: mondaySection,
        matching: find.text('×'),
      );
      await tester.ensureVisible(removeButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: mondaySection, matching: find.text('30m')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: mondaySection, matching: find.text('1h')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Goals: creating a new duration-only goal does not show up as a planned block in the Day view',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
        find.descendant(
          of: find.byType(TimeBodyGrid),
          matching: find.text('Piano'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    "Goals: a duration-only goal's detail sheet shows nothing planned, even though it has a weekly target",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
        find.descendant(
          of: find.byType(GoalDetailSheet),
          matching: find.text('Piano'),
        ),
        findsOneWidget,
      );
      expect(find.text('3h 30m'), findsWidgets);
    },
  );

  testWidgets('Goals: "same every day" applies Monday to every day', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final mondaySection = find
        .ancestor(
          of: find.textContaining('Mon'), // now "Mon d MMM", e.g. "Mon 17 Aug"
          matching: find.byType(Column),
        )
        .first;
    final mondayPlus = find.descendant(
      of: mondaySection,
      matching: find.text('+'),
    );
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
    expect(find.text('35m'), findsNWidgets(14));
  });

  testWidgets(
    'Log activity: saving with a start/end or goal missing says so instead '
    'of silently closing without saving',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();

      // Day defaults, but activity/start/end/goal are all still unset.
      await tester.enterText(find.byType(TextField).first, 'Forgot the rest');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Stays open — a silent no-op would have popped the sheet here.
      expect(find.text('Log activity'), findsOneWidget);
      expect(find.textContaining('before saving'), findsOneWidget);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .any((b) => b.title == 'Forgot the rest'),
        isFalse,
      );
    },
  );

  testWidgets('Log activity: a start/end set but no goal picked is called out '
      'specifically as "a goal" — the exact bug a real user hit', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Sunday walk');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 9, minute: 0))
      ..setEnd(const TimeOfDay(hour: 9, minute: 30));
    // Deliberately no setGoal — this is the exact real-world repro: day,
    // activity, and time all filled in, goal chip never tapped.
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Log activity'), findsOneWidget);
    expect(find.text('Set a goal before saving'), findsOneWidget);
    expect(
      container
          .read(allTrackedBlocksProvider)
          .any((b) => b.title == 'Sunday walk'),
      isFalse,
    );
  });

  testWidgets('Log activity: a goal picked but no start/end set is called out '
      'specifically as "a start and end time"', (WidgetTester tester) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'No time set');
    await tester.tap(find.text('walking'));
    // Deliberately no start/end.
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Log activity'), findsOneWidget);
    expect(find.text('Set a start and end time before saving'), findsOneWidget);
    expect(
      container
          .read(allTrackedBlocksProvider)
          .any((b) => b.title == 'No time set'),
      isFalse,
    );
  });

  testWidgets('Log activity: fixing the missing field after a failed save then '
      'succeeds — the sheet is still fully usable, not stuck', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Recovered entry');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 18, minute: 0))
      ..setEnd(const TimeOfDay(hour: 18, minute: 15));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();

    // First attempt fails (no goal) — same as the test above.
    expect(find.text('Set a goal before saving'), findsOneWidget);

    // Now actually pick a goal and try again.
    await tester.tap(find.text('walking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      container
          .read(allTrackedBlocksProvider)
          .any((b) => b.title == 'Recovered entry'),
      isTrue,
    );
    // Sheet closed this time — back on Activities, entry visible there.
    expect(find.text('Recovered entry'), findsOneWidget);
  });

  testWidgets(
    "Log activity: leaving the activity name blank falls back to the goal's own name",
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();

      // No text entered in the Activity field at all.
      container.read(draftLogEntryProvider.notifier)
        ..setStart(const TimeOfDay(hour: 6, minute: 30))
        ..setEnd(const TimeOfDay(hour: 7, minute: 0))
        ..setGoal('goal-walking');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final saved = container
          .read(allTrackedBlocksProvider)
          .singleWhere((b) => b.start == DateTime(2026, 8, 20, 6, 30));
      expect(saved.title, 'Walking'); // the goal's own name, not blank
    },
  );

  testWidgets(
    'Log activity: closing the sheet resets the draft — reopening starts fresh',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('deep work'));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY TARGET'), findsOneWidget); // a goal is selected

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // No goal selected this time — closing threw the draft away.
      expect(find.text('WEEKLY TARGET'), findsNothing);
    },
  );

  testWidgets('Log activity: saving actually creates a tracked block', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITIES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Evening walk');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 20, minute: 0))
      ..setEnd(const TimeOfDay(hour: 20, minute: 30))
      ..setGoal('goal-walking');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tracked = container.read(allTrackedBlocksProvider);
    expect(
      tracked.any((b) => b.title == 'Evening walk' && b.sourceId == 'manual'),
      isTrue,
    );
    // Saving closes the sheet, back on Activities — the new entry should
    // now render there.
    expect(find.text('Evening walk'), findsOneWidget);
  });

  testWidgets(
    'Log activity: picking a different day logs the entry there, not the '
    'app\'s currently selected day',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();

      // mockDay is 20 Aug 2026 — log this one for the day before instead.
      await tester.enterText(find.byType(TextField).first, 'Yesterday\'s walk');
      container.read(draftLogEntryProvider.notifier)
        ..setDate(DateTime(2026, 8, 19))
        ..setStart(const TimeOfDay(hour: 20, minute: 0))
        ..setEnd(const TimeOfDay(hour: 20, minute: 30))
        ..setGoal('goal-walking');
      await tester.pumpAndSettle();

      expect(find.text('Wed, 19 Aug 2026'), findsOneWidget);

      await tester.ensureVisible(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tracked = container.read(allTrackedBlocksProvider);
      final saved = tracked.singleWhere((b) => b.title == 'Yesterday\'s walk');
      expect(saved.start, DateTime(2026, 8, 19, 20, 0));

      // The app's own selected date (still 20 Aug, mockDay) was never
      // touched — picking a day for this one entry is local to the sheet.
      expect(container.read(selectedDateProvider), DateTime(2026, 8, 20));
      // The Activities list shows every day, so the entry does show up —
      // but filed under the 19th's own section, not the 20th's.
      expect(find.text('WEDNESDAY, 19 AUG'), findsOneWidget);
      expect(find.text('Yesterday\'s walk'), findsOneWidget);
      final entryY = tester.getTopLeft(find.text('Yesterday\'s walk')).dy;
      final wed19HeaderY = tester.getTopLeft(find.text('WEDNESDAY, 19 AUG')).dy;
      final thu20HeaderY = tester.getTopLeft(find.text('THURSDAY, 20 AUG')).dy;
      expect(entryY, greaterThan(wed19HeaderY));
      expect(wed19HeaderY, greaterThan(thu20HeaderY));
    },
  );

  testWidgets(
    'Goals: a planned block for a goal\'s category shows as planned hours',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final selectedDate = container.read(selectedDateProvider);
      await container
          .read(plannedBlocksRepositoryProvider)
          .upsert(
            PlannedBlock(
              id: 'test-plan-walk',
              start: DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                21,
                0,
              ),
              end: DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                22,
                30,
              ),
              title: 'Evening walk',
              categoryId: walkingCategoryId,
            ),
          );
      await tester.pump();

      final progressList = container.read(goalProgressListProvider);
      final walking = progressList.firstWhere(
        (p) => p.goal.categoryId == walkingCategoryId,
      );
      // The new 1.5h planned block is on top of whatever was already planned.
      expect(walking.plannedHours, greaterThanOrEqualTo(1.5));

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('planned'), findsWidgets);
    },
  );

  testWidgets(
    'Categories: a new category needs a goal of its own before it shows up as a Log activity chip',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
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
      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();
      expect(find.text('reading'), findsNothing);
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('ACTIVITIES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ LOG'));
      await tester.pumpAndSettle();

      expect(find.text('reading'), findsOneWidget); // now selectable, by goal
    },
  );

  testWidgets('Goals: a date-bound goal only appears in its window', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(overrides: await _signedInOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final selectedDate = container.read(selectedDateProvider);
    await container
        .read(goalsRepositoryProvider)
        .upsert(
          Goal(
            id: 'test-challenge',
            name: 'Next month challenge',
            categoryId: walkingCategoryId,
            scheduleByWeekday: {
              for (var weekday = 1; weekday <= 7; weekday++)
                weekday: [
                  const DayScheduleEntry.duration(Duration(minutes: 30)),
                ],
            },
            startDate: selectedDate.add(const Duration(days: 30)),
            endDate: selectedDate.add(const Duration(days: 60)),
          ),
        );
    await tester.pump();

    // Not active today — shouldn't show up yet.
    expect(
      container
          .read(goalProgressListProvider)
          .any((p) => p.goal.id == 'test-challenge'),
      isFalse,
    );

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Next month challenge'), findsNothing);

    // Jump the selected date forward into the goal's window.
    container.read(selectedDateProvider.notifier).state = selectedDate.add(
      const Duration(days: 45),
    );
    await tester.pumpAndSettle();

    expect(
      container
          .read(goalProgressListProvider)
          .any((p) => p.goal.id == 'test-challenge'),
      isTrue,
    );
    expect(find.text('Next month challenge'), findsOneWidget);
  });

  testWidgets(
    'Goals: tapping + New goal with no categories shows a message instead of opening the sheet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInNoCategoriesOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GOALS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ NEW GOAL'));
      await tester.pumpAndSettle();

      expect(find.text('Create a category first'), findsOneWidget);
      expect(find.text('CREATE GOAL'), findsNothing);
    },
  );

  testWidgets(
    'Day view: tapping empty space opens a sheet with goal chips (not category '
    "chips), and saving files the block under that goal's category",
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInOnboardedNoActivityOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // The seeded fixture has no blocks at all, so any tap on the timeline
      // is "empty space" — no need to dodge existing blocks.
      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // "test goal" — the fixture's one goal, shown as a chip. Not the
      // category name ("Work") — goals and categories happen to differ here
      // specifically so this can't pass by coincidence.
      expect(find.text('test goal'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Morning walk');
      await tester.pumpAndSettle();

      // Whichever lane the tap landed in — the button reads ADD PLAN or ADD
      // ACTUAL, and either is a valid outcome for this test.
      await tester.tap(find.textContaining('ADD '));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final plannedMatch = container
          .read(allPlannedBlocksProvider)
          .where((b) => b.title == 'Morning walk');
      final trackedMatch = container
          .read(allTrackedBlocksProvider)
          .where((b) => b.title == 'Morning walk');
      expect(plannedMatch.length + trackedMatch.length, 1);
      final categoryId = plannedMatch.isNotEmpty
          ? plannedMatch.single.categoryId
          : trackedMatch.single.categoryId;
      expect(categoryId, 'cat-1'); // the goal's own category
    },
  );

  testWidgets(
    'Day view: the add-block sheet has independent start/end date fields, '
    'defaulting to today and opening the date picker',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOnboardedNoActivityOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('START DATE'), findsOneWidget);
      expect(find.text('END DATE'), findsOneWidget);
      // The fixture pins selectedDateProvider to mockDay — both fields
      // default to that, independently of each other.
      final today = DateFormat('EEE, d MMM y').format(mockDay);
      expect(find.text(today), findsNWidgets(2));

      // Opens the real date picker — dismissing it with CANCEL should leave
      // the add-block sheet exactly as it was, not crash or lose state.
      await tester.tap(find.text(today).last);
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(today), findsNWidgets(2));
    },
  );

  testWidgets(
    'Day view: tapping empty space with no goals shows a message instead of opening the sheet',
    (WidgetTester tester) async {
      // RootShell pumped directly, bypassing AuthGate/onboarding — a
      // zero-goal account would otherwise never reach Day view at all
      // (onboarding intercepts it first, see auth_gate.dart). This test is
      // specifically about add_block_sheet's own "nothing to file this
      // under" guard, not the onboarding gate.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'no-goals-uid'),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            selectedDateProvider.overrideWith((ref) => mockDay),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SafeArea(child: RootShell())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap well into the empty timeline, away from any header controls.
      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      expect(find.text('Create a goal first'), findsOneWidget);
      expect(find.text('ADD PLAN'), findsNothing);
      expect(find.text('ADD ACTUAL'), findsNothing);
    },
  );
}
