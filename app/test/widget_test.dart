import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show UserMetadata;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';
import 'package:calendar_tracker/features/account/account_screen.dart';
import 'package:calendar_tracker/features/categories/categories_screen.dart';
import 'package:calendar_tracker/features/day_view/widgets/actual_block_widget.dart';
import 'package:calendar_tracker/features/day_view/widgets/day_header_bar.dart';
import 'package:calendar_tracker/features/day_view/widgets/time_body_grid.dart';
import 'package:calendar_tracker/features/goals/goals_screen.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_block.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_detail_sheet.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/features/log_activity/widgets/log_activity_sheet.dart';
import 'package:calendar_tracker/shell/root_shell.dart';
import 'package:calendar_tracker/features/account/capacity_view.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/shared/widgets/app_tab_bar.dart';
import 'package:calendar_tracker/shared/widgets/dashed_border.dart';
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

/// GoalEditSheet is a 4-step wizard (Category → Name & dates → Schedule →
/// Reminders) — steps are strictly linear, reached only via "NEXT", so any
/// test that needs a field past step 1 has to walk there first.
Future<void> _goalSheetNext(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }
}

/// Taps a bottom tab by its label, scoped to [AppTabBar].
///
/// Scoped rather than a bare `find.text` because tab labels are sentence
/// case since the Outlook restyle, so they can collide with body copy
/// elsewhere on screen. (The sharpest case is gone — the first tab is
/// "Calendar" now, not "Day", which used to also match the Day view's own
/// view-mode button — but staying scoped keeps the next rename safe.)
Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppTabBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// The Day view's mode switcher is a single button (showing the current
/// mode) that opens a dropdown menu of the other options — tap the button,
/// then the target option's menu item.
Future<void> _selectDayViewMode(WidgetTester tester, String label) async {
  await tester.tap(find.byType(PopupMenuButton<DayViewMode>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
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
  });

  testWidgets(
    'Day view: an actual block linked to a plan renders with a dashed '
    'outline, an unplanned one does not',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // mock_day_20aug.dart: 'actual-walk' carries plannedBlockId
      // 'plan-walk' (its own plan block); 'actual-unplanned-call' has none.
      final linked = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );
      final unplanned = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-unplanned-call',
      );
      await tester.ensureVisible(linked);
      await tester.ensureVisible(unplanned);
      expect(linked, findsOneWidget);
      expect(unplanned, findsOneWidget);

      expect(
        find.descendant(of: linked, matching: find.byType(DashedRectBorder)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unplanned,
          matching: find.byType(DashedRectBorder),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Day view: a manually-logged entry with no plannedBlockId still gets '
    "the dashed outline when it overlaps a planned block's own category "
    'and time',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await container.read(plannedBlocksRepositoryProvider).upsert(
        PlannedBlock(
          id: 'test-fuzzy-plan',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
          title: 'Test plan',
          categoryId: walkingCategoryId,
        ),
      );
      await container.read(trackedBlocksRepositoryProvider).upsert(
        TrackedBlock(
          id: 'test-fuzzy-actual',
          start: DateTime(2026, 8, 20, 16, 5),
          end: DateTime(2026, 8, 20, 16, 25),
          title: 'Test actual',
          categoryId: walkingCategoryId,
          sourceId: 'manual',
        ),
      );
      await tester.pumpAndSettle();

      final fuzzy = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'test-fuzzy-actual',
      );
      await tester.ensureVisible(fuzzy);
      expect(fuzzy, findsOneWidget);
      expect(
        find.descendant(of: fuzzy, matching: find.byType(DashedRectBorder)),
        findsOneWidget,
      );
    },
  );

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

  testWidgets(
    'Day view: tapping the date opens a picker that jumps to the picked date',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('20 Aug'), findsOneWidget);

      await tester.tap(find.text('20 Aug'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('15'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('15 Aug'), findsOneWidget);
    },
  );

  testWidgets(
    'Day view: switching the mode toggle changes the number of visible day columns',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Day mode: the per-column header row is collapsed — a single day is
      // already named by the header above.
      expect(find.text('THU 20'), findsNothing);

      await _selectDayViewMode(tester, '3 Day');
      expect(tester.takeException(), isNull);
      expect(find.text('THU 20'), findsOneWidget);
      expect(find.text('FRI 21'), findsOneWidget);
      expect(find.text('SAT 22'), findsOneWidget);
      expect(find.text('SUN 23'), findsNothing);

      await _selectDayViewMode(tester, 'Working week');
      expect(tester.takeException(), isNull);
      // Anchored at the Monday of the selected day's week (17 Aug), 5 days.
      expect(find.text('MON 17'), findsOneWidget);
      expect(find.text('FRI 21'), findsOneWidget);
      expect(find.text('SAT 22'), findsNothing);

      await _selectDayViewMode(tester, 'Week');
      expect(tester.takeException(), isNull);
      expect(find.text('MON 17'), findsOneWidget);
      expect(find.text('SUN 23'), findsOneWidget);
    },
  );

  testWidgets(
    'Day view: tapping empty space in a non-first day-column creates a '
    'block dated to that column, not the selected date',
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

      await _selectDayViewMode(tester, '3 Day');

      // 3-Day mode starting on mockDay (20 Aug): columns are 20/21/22 Aug —
      // tap into the third column (22 Aug). The fixture has no blocks at
      // all, so any tap in that column is "empty space".
      final gridTopLeft = tester.getTopLeft(find.byType(TimeBodyGrid));
      final gridSize = tester.getSize(find.byType(TimeBodyGrid));
      final columnWidth = (gridSize.width - kGutterWidth) / 3;
      final tapPoint = Offset(
        gridTopLeft.dx + kGutterWidth + columnWidth * 2 + columnWidth / 2,
        gridTopLeft.dy + gridSize.height / 2,
      );
      await tester.tapAt(tapPoint);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New actual activity'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'Third column entry',
      );
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final saved = container
          .read(allTrackedBlocksProvider)
          .firstWhere((b) => b.title == 'Third column entry');
      expect(
        DateTime(saved.start.year, saved.start.month, saved.start.day),
        DateTime(2026, 8, 22),
      );
    },
  );

  testWidgets('Tab bar switches through all 3 tabs without layout errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['Goals', 'Account', 'Calendar']) {
      await _tapTab(tester, tab);
      expect(tester.takeException(), isNull, reason: 'after tapping $tab');
    }
  });

  testWidgets('Goals: a leftward swipe steps to the next tab (Account)', (
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

    await _tapTab(tester, 'Goals');
    expect(container.read(currentTabIndexProvider), 1);

    // Goals has no competing horizontal gesture (unlike Day, which uses
    // swipe for date navigation), so a swipe here is free to mean
    // "next/previous tab".
    await tester.fling(find.byType(GoalsScreen), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 2);
  });

  testWidgets(
    'Account: a rightward swipe steps to the previous tab (Goals)',
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

      await _tapTab(tester, 'Account');
      expect(container.read(currentTabIndexProvider), 2);

      await tester.fling(
        find.byType(AccountScreen),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(currentTabIndexProvider), 1);
    },
  );

  testWidgets('Account: swiping left at the last tab clamps, not wraps', (
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

    await _tapTab(tester, 'Account');
    expect(container.read(currentTabIndexProvider), 2);

    // Account is already the last tab — swiping further "next" should
    // stay put, not wrap around to Day.
    await tester.fling(
      find.byType(AccountScreen),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 2);
  });

  testWidgets(
    'Account: the Capacity menu item shows per-day free time and per-goal '
    'room, and switching back to Details returns to the account details',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');

      await tester.tap(find.text('Capacity'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CapacityView), findsOneWidget);

      // Free time per day — every day of the mock week shows up.
      expect(find.text('FREE TIME PER DAY'), findsOneWidget);
      expect(find.text('MON 17'), findsOneWidget);
      expect(find.text('SUN 23'), findsOneWidget);

      // Room toward goals — a target goal appears with its planned/target
      // split, e.g. "Walking · planned X / Y h".
      expect(find.text('ROOM TOWARD GOALS'), findsOneWidget);
      expect(find.textContaining('Walking · planned'), findsOneWidget);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.byType(CapacityView), findsNothing);
      expect(find.text('EMAIL'), findsOneWidget);
    },
  );

  testWidgets(
    'Capacity: a day planned past its window reports overplanned instead of negative free time',
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

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Capacity'));
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

    await _tapTab(tester, 'Goals');

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

      await _tapTab(tester, 'Goals');

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

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
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

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No activity yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'Activities: tapping edit on a row opens it prefilled, and saving '
    'updates that same entry in place',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      // 'actual-walk' (mock_day_20aug.dart): "Walk 48 m", 07:00–07:48,
      // Walking goal.
      final row = find.byKey(const ValueKey('actual-walk'));
      await tester.ensureVisible(row);
      await tester.tap(find.descendant(of: row, matching: find.text('edit')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit activity'), findsOneWidget);
      // Prefilled from the existing block, not a blank form — scoped to
      // the sheet since "Walk 48 m" also still shows on the Activities
      // row behind the modal.
      final activityField = find.descendant(
        of: find.byType(LogActivitySheet),
        matching: find.text('Walk 48 m'),
      );
      expect(activityField, findsOneWidget);
      expect(find.text('7:00 AM'), findsOneWidget);
      expect(find.text('7:48 AM'), findsOneWidget);

      await tester.enterText(activityField, 'Morning walk, edited');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Same id, new title — an edit, not a second entry alongside the
      // original.
      final blocks = container
          .read(allTrackedBlocksProvider)
          .where((b) => b.id == 'actual-walk');
      expect(blocks, hasLength(1));
      expect(blocks.single.title, 'Morning walk, edited');
      expect(find.text('Morning walk, edited'), findsOneWidget);
      expect(find.text('Walk 48 m'), findsNothing);
    },
  );

  testWidgets(
    "Activities: the edit sheet's own Delete activity row also confirms "
    'before soft-deleting',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('actual-walk'));
      await tester.ensureVisible(row);
      await tester.tap(find.descendant(of: row, matching: find.text('edit')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete activity'));
      await tester.tap(find.text('Delete activity'));
      await tester.pumpAndSettle();

      // Cancel first — the entry must survive untouched.
      expect(find.text('Delete activity?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit activity'), findsOneWidget);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isNotEmpty,
      );

      // Now confirm — the entry disappears and the document is soft-deleted.
      await tester.ensureVisible(find.text('Delete activity'));
      await tester.tap(find.text('Delete activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit activity'), findsNothing);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isEmpty,
      );
      final raw = container.read(allTrackedBlocksStreamProvider).value!;
      expect(
        raw.firstWhere((b) => b.id == 'actual-walk').status,
        TrackedBlockStatus.deleted,
      );
    },
  );

  testWidgets(
    'Activities: tapping delete on a row removes just that entry',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      expect(find.text('Walk 48 m'), findsOneWidget);
      expect(find.text('Deep work 1 h 45'), findsOneWidget);

      final row = find.byKey(const ValueKey('actual-walk'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.text('delete')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete activity?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isEmpty,
      );
      expect(find.text('Walk 48 m'), findsNothing);
      // A different row on the same day survives untouched.
      expect(find.text('Deep work 1 h 45'), findsOneWidget);
    },
  );

  testWidgets(
    'Activities: cancelling the delete confirmation leaves the entry untouched',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('actual-walk'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.text('delete')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete activity?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isNotEmpty,
      );
      expect(find.text('Walk 48 m'), findsOneWidget);
    },
  );

  testWidgets(
    'Activities: deleting an activity soft-deletes it — the Firestore document survives with status "deleted"',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('actual-walk'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.text('delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Filtered provider treats it as gone...
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isEmpty,
      );
      // ...but the unfiltered stream shows the document is still there,
      // just flagged deleted rather than physically removed.
      final raw = container.read(allTrackedBlocksStreamProvider).value!;
      final deleted = raw.firstWhere((b) => b.id == 'actual-walk');
      expect(deleted.status, TrackedBlockStatus.deleted);
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

    await _tapTab(tester, 'Account');
    await tester.tap(find.text('Activities'));
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

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
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

    await tester.tap(find.text('+ Log'));
    await tester.pumpAndSettle();

    // Day defaults to whatever the app is currently showing (mockDay, a
    // Thursday) — asking the user to pick it explicitly, rather than
    // silently assuming it, but not making them do so for the common case.
    expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // duration, empty

    // Scoped to the sheet — the Day view behind it (now visible, since
    // "+ LOG" lives there) has its own "deep work" text in the drift
    // footer whenever that category has nonzero drift for the day.
    await tester.tap(
      find.descendant(
        of: find.byType(LogActivitySheet),
        matching: find.text('deep work'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('20h/wk'), findsOneWidget);
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

    await _tapTab(tester, 'Goals');

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

    await _tapTab(tester, 'Goals');

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
    await _tapTab(tester, 'Calendar');

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

      await _tapTab(tester, 'Goals');

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

      await _tapTab(tester, 'Goals');
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

      await _tapTab(tester, 'Goals');
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

    await _tapTab(tester, 'Goals');

    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsOneWidget);

    await tester.ensureVisible(find.text('Delete goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
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

      await _tapTab(tester, 'Goals');
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

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // step 1 (Category) -> step 2 (Name & dates)

      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Walking (evenings)');
      await tester.pumpAndSettle();

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(find.text('Save changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
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

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // step 1 (Category) -> step 2 (Name & dates)

      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Walking (evenings)');
      await tester.pumpAndSettle();

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
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

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // step 1 (Category) -> step 2 (Name & dates)

      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Walking (evenings)');
      await tester.pumpAndSettle();

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
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

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // step 1 (Category) -> step 2 (Name & dates)

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

      await tester.tap(find.text('Keep editing'));
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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      // Schedule is step 3 (Category -> Name & dates -> Schedule).
      await _goalSheetNext(tester, 2);

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

    await _tapTab(tester, 'Goals');

    await tester.tap(find.text('+ New goal'));
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget);
    // Step 1: Category — nothing to do, a default is already selected.
    await _goalSheetNext(tester);

    // Step 2: Name & dates.
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
    await _goalSheetNext(tester);

    // Step 3: Schedule. Every day defaults to one 30-min entry — both the
    // day's own total and its single entry's stepper read "30 m", so 7
    // days × 2 = 14.
    expect(find.text('30m'), findsNWidgets(14));

    // Bump Monday's target by 3 steps of 5 minutes (30m -> 45m). Scrolling
    // happens before tapping — "Mon" and its entry's "+" sit in different
    // rows now (header row vs. entry row), sharing the day section's
    // Column as their nearest common ancestor.
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

    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await _goalSheetNext(tester);

    // Step 4: Reminders — submit without touching it.
    await tester.ensureVisible(find.text('Create goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create goal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('Goals: a reminder lead time can be picked and is saved with the goal', (
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

    await _tapTab(tester, 'Goals');
    await tester.tap(find.text('+ New goal'));
    await tester.pumpAndSettle();

    // Step 1: Category -> Step 2: Name & dates.
    await _goalSheetNext(tester);
    final nameField = find.descendant(
      of: find.byType(GoalEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Reminder test');
    await tester.pumpAndSettle();

    // Step 3: Schedule -> Step 4: Reminders.
    await _goalSheetNext(tester, 2);

    // Defaults to no reminder.
    expect(find.text('None'), findsOneWidget);

    await tester.ensureVisible(find.text('15 min before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 min before'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create goal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final created = container
        .read(goalsProvider)
        .firstWhere((g) => g.name == 'Reminder test');
    expect(created.reminderMinutesBefore, 15);
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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      // Schedule is step 3 (Category -> Name & dates -> Schedule).
      await _goalSheetNext(tester, 2);

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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      // Schedule is step 3 (Category -> Name & dates -> Schedule).
      await _goalSheetNext(tester, 2);

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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // step 1 (Category) -> step 2 (Name & dates)

      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Piano');
      await tester.pumpAndSettle();
      await _goalSheetNext(tester, 2); // -> step 3 (Schedule) -> step 4 (Reminders)

      await tester.ensureVisible(find.text('Create goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Back on the Day tab automatically (creating a goal doesn't navigate,
      // but the app opens on Day and the sheet closes onto whatever's behind
      // it — Goals in this case, so switch to Day explicitly).
      await _tapTab(tester, 'Calendar');

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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // step 1 (Category) -> step 2 (Name & dates)

      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Piano');
      await tester.pumpAndSettle();
      await _goalSheetNext(tester, 2); // -> step 3 (Schedule) -> step 4 (Reminders)

      await tester.ensureVisible(find.text('Create goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create goal'));
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

    await _tapTab(tester, 'Goals');

    await tester.tap(find.text('+ New goal'));
    await tester.pumpAndSettle();
    // Schedule is step 3 (Category -> Name & dates -> Schedule).
    await _goalSheetNext(tester, 2);

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

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      // Day defaults, but activity/start/end/goal are all still unset.
      await tester.enterText(find.byType(TextField).first, 'Forgot the rest');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Stays open — a silent no-op would have popped the sheet here.
      expect(find.text('Log activity'), findsOneWidget);
      expect(find.textContaining('before saving'), findsOneWidget);
      // Inline, not a SnackBar — a SnackBar shown while this sheet is open
      // renders behind it (invisible), which is the exact bug this guards.
      expect(find.byType(SnackBar), findsNothing);
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

    await tester.tap(find.text('+ Log'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Sunday walk');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 9, minute: 0))
      ..setEnd(const TimeOfDay(hour: 9, minute: 30));
    // Deliberately no setGoal — this is the exact real-world repro: day,
    // activity, and time all filled in, goal chip never tapped.
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Log activity'), findsOneWidget);
    expect(find.text('Set a goal before saving'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
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

    await tester.tap(find.text('+ Log'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'No time set');
    // Scoped to the sheet — the Day view's drift footer also shows
    // "walking" whenever that category has nonzero drift for the day.
    await tester.tap(
      find.descendant(
        of: find.byType(LogActivitySheet),
        matching: find.text('walking'),
      ),
    );
    // Deliberately no start/end.
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Log activity'), findsOneWidget);
    expect(find.text('Set a start and end time before saving'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
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

    await tester.tap(find.text('+ Log'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Recovered entry');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 18, minute: 0))
      ..setEnd(const TimeOfDay(hour: 18, minute: 15));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    // First attempt fails (no goal) — same as the test above.
    expect(find.text('Set a goal before saving'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Now actually pick a goal and try again. Scoped to the sheet — the
    // Day view's drift footer also shows "walking" when that category
    // has nonzero drift for the day.
    await tester.tap(
      find.descendant(
        of: find.byType(LogActivitySheet),
        matching: find.text('walking'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      container
          .read(allTrackedBlocksProvider)
          .any((b) => b.title == 'Recovered entry'),
      isTrue,
    );
    // Sheet closed this time — back on the Day view, entry visible there
    // (same day, same title text shown on the block itself).
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

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      // No text entered in the Activity field at all.
      container.read(draftLogEntryProvider.notifier)
        ..setStart(const TimeOfDay(hour: 6, minute: 30))
        ..setEnd(const TimeOfDay(hour: 7, minute: 0))
        ..setGoal('goal-walking');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
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

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      // Scoped to the sheet — the Day view's drift footer also shows
      // "deep work" when that category has nonzero drift for the day.
      await tester.tap(
        find.descendant(
          of: find.byType(LogActivitySheet),
          matching: find.text('deep work'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY TARGET'), findsOneWidget); // a goal is selected

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // No goal selected this time — closing threw the draft away.
      expect(find.text('WEEKLY TARGET'), findsNothing);
    },
  );

  testWidgets(
    'Log activity: dismissing the sheet via the barrier (not the close '
    "link) still resets the draft — the next open defaults to today's "
    'date, not a stale leftover one',
    (WidgetTester tester) async {
      final container = ProviderContainer(overrides: await _signedInOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      // Defaults to the app's currently selected day (mockDay: 20 Aug).
      expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);

      // Simulate the draft having drifted away from that default (e.g. the
      // user picked a different day for a one-off entry), then dismiss via
      // the modal barrier rather than the "close" link — the bug this
      // guards against was that only "close" reset the draft, so a scrim
      // tap or drag-to-dismiss left this leftover date for the next open.
      container.read(draftLogEntryProvider.notifier).setDate(
        DateTime(2026, 8, 17),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mon, 17 Aug 2026'), findsOneWidget);

      // A tap near the very top of the screen lands on the modal barrier
      // above the sheet, not on the sheet's own content (same trick used
      // for the add-block sheet's own barrier-tap tests).
      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();
      expect(find.byType(LogActivitySheet), findsNothing);

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
      expect(find.text('Mon, 17 Aug 2026'), findsNothing);
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

    await tester.tap(find.text('+ Log'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Evening walk');
    container.read(draftLogEntryProvider.notifier)
      ..setStart(const TimeOfDay(hour: 20, minute: 0))
      ..setEnd(const TimeOfDay(hour: 20, minute: 30))
      ..setGoal('goal-walking');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tracked = container.read(allTrackedBlocksProvider);
    expect(
      tracked.any((b) => b.title == 'Evening walk' && b.sourceId == 'manual'),
      isTrue,
    );
    // Saving closes the sheet, back on the Day view — the new entry's
    // block should now render there too.
    expect(find.text('Evening walk'), findsOneWidget);
  });

  testWidgets(
    "Log activity: a note is saved with the entry and shown in the Activities list",
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

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      container.read(draftLogEntryProvider.notifier)
        ..setStart(const TimeOfDay(hour: 20, minute: 0))
        ..setEnd(const TimeOfDay(hour: 20, minute: 30))
        ..setGoal('goal-walking')
        ..setNote('felt great, new personal best pace');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tracked = container
          .read(allTrackedBlocksProvider)
          .firstWhere((b) => b.title == 'Evening walk');
      expect(tracked.note, 'felt great, new personal best pace');

      // The Day view's block only shows title + source, not the note — the
      // Activities list is where the note itself renders.
      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(find.text('felt great, new personal best pace'), findsOneWidget);
    },
  );

  testWidgets(
    'Log activity: leaving the note blank saves no note, and nothing extra renders',
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

      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Quiet walk');
      container.read(draftLogEntryProvider.notifier)
        ..setStart(const TimeOfDay(hour: 20, minute: 0))
        ..setEnd(const TimeOfDay(hour: 20, minute: 30))
        ..setGoal('goal-walking');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      final tracked = container
          .read(allTrackedBlocksProvider)
          .firstWhere((b) => b.title == 'Quiet walk');
      expect(tracked.note, isNull);
    },
  );

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

      await tester.tap(find.text('+ Log'));
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

      await tester.ensureVisible(find.text('Save entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tracked = container.read(allTrackedBlocksProvider);
      final saved = tracked.singleWhere((b) => b.title == 'Yesterday\'s walk');
      expect(saved.start, DateTime(2026, 8, 19, 20, 0));

      // The app's own selected date (still 20 Aug, mockDay) was never
      // touched — picking a day for this one entry is local to the sheet.
      expect(container.read(selectedDateProvider), DateTime(2026, 8, 20));

      // The Day view is still showing the 20th, so this entry (dated the
      // 19th) doesn't render there — the Activities list shows every day,
      // so the entry does show up there, filed under the 19th's own
      // section, not the 20th's.
      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
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

      await _tapTab(tester, 'Goals');

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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('categories'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);

      await tester.tap(find.text('+ New category'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Reading');
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Reading'), findsOneWidget); // category row, as typed

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      // Logging is goal-first now — the bare category alone isn't enough to
      // log against; there needs to be a goal for it too. Logging itself now
      // lives on the Day tab, not Account.
      await _tapTab(tester, 'Calendar');
      await tester.tap(find.text('+ Log'));
      await tester.pumpAndSettle();
      expect(find.text('reading'), findsNothing);
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();

      // Step 1: Category.
      final readingCategoryChip = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.text('reading'),
      );
      await tester.ensureVisible(readingCategoryChip);
      await tester.pumpAndSettle();
      await tester.tap(readingCategoryChip);
      await tester.pumpAndSettle();
      await _goalSheetNext(tester);

      // Step 2: Name & dates.
      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Reading');
      await tester.pumpAndSettle();
      await _goalSheetNext(tester, 2); // -> step 3 (Schedule) -> step 4 (Reminders)

      await tester.ensureVisible(find.text('Create goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Calendar');
      await tester.tap(find.text('+ Log'));
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

    await _tapTab(tester, 'Goals');

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

      await _tapTab(tester, 'Goals');

      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();

      expect(find.text('Create a category first'), findsOneWidget);
      expect(find.text('Create goal'), findsNothing);
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
      // No goal pre-selected — picking one is a real, required choice now.
      expect(find.text('set goal'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Morning walk');
      await tester.pumpAndSettle();

      // "test goal" — the fixture's one goal, in the picker list. Not the
      // category name ("Work") — goals and categories happen to differ here
      // specifically so this can't pass by coincidence.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test goal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save'));
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
    'Day view: the add-block sheet has no date field — it always uses '
    'whichever day the Day view is showing — and the goal picker is a '
    'dropdown, not chips',
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
      expect(find.text('START DATE'), findsNothing);
      expect(find.text('END DATE'), findsNothing);
      expect(find.text('START TIME'), findsOneWidget);
      expect(find.text('END TIME'), findsOneWidget);

      // No goal pre-selected — the closed field reads "set goal" until one
      // is actually picked, not the Wrap of chips this used to be.
      expect(find.text('set goal'), findsOneWidget);
      expect(find.text('test goal'), findsNothing);

      // Tapping opens a flat picker list rather than a native dropdown menu.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      expect(find.text('test goal'), findsOneWidget); // the one list row

      await tester.tap(find.text('test goal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Picker closed, field now shows the picked goal.
      expect(find.text('set goal'), findsNothing);
      expect(find.text('test goal'), findsOneWidget);

      // The bottom save button is gone — "save" now lives in the header,
      // next to the title, to keep the sheet as short as possible.
      expect(find.text('save'), findsOneWidget);
      expect(find.text('ADD PLAN'), findsNothing);
      expect(find.text('Save activity'), findsNothing);
    },
  );

  testWidgets(
    'Day view: the add-block sheet shows a computed duration next to '
    'its title',
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

      // End time defaults to 30 minutes after start.
      expect(find.text('· 30m'), findsOneWidget);
    },
  );

  testWidgets(
    'Day view: the add-block sheet requires an activity name before saving',
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

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      // A goal is picked, but the activity name is left blank.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test goal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Enter an activity name before saving'),
        findsOneWidget,
      );
      // Inline, not a SnackBar — a SnackBar shown while this sheet is open
      // renders behind it (invisible), which is the exact bug this guards.
      expect(find.byType(SnackBar), findsNothing);
      // Stays open — a silent no-op or a fallback title would have popped
      // the sheet instead.
      expect(find.text('save'), findsOneWidget);
      expect(
        container.read(allTrackedBlocksProvider).isEmpty &&
            container.read(allPlannedBlocksProvider).isEmpty,
        isTrue,
      );
    },
  );

  testWidgets(
    'Day view: the add-block sheet requires a goal before saving',
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

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      // A name is entered, but no goal is picked — still defaults to none.
      await tester.enterText(find.byType(TextField).first, 'Morning walk');
      await tester.pumpAndSettle();

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Set a goal before saving'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('save'), findsOneWidget);
      expect(
        container.read(allTrackedBlocksProvider).isEmpty &&
            container.read(allPlannedBlocksProvider).isEmpty,
        isTrue,
      );
    },
  );

  testWidgets(
    'Day view: tapping outside the add-block sheet with no changes closes '
    'it immediately, no confirmation',
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
      // Whichever lane the tap landed in — "save" in the header is common
      // to both the planned and actual variant.
      expect(find.text('save'), findsOneWidget);

      // A tap near the very top of the screen lands on the modal barrier
      // above the sheet, not on the sheet's own content.
      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save this activity?'), findsNothing);
      expect(find.text('save'), findsNothing);
    },
  );

  testWidgets(
    'Day view: tapping outside the add-block sheet with unsaved changes '
    'asks to save — Cancel discards',
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

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save this activity?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('save'), findsNothing);
      expect(
        container
            .read(allPlannedBlocksProvider)
            .any((b) => b.title == 'Evening walk'),
        isFalse,
      );
      expect(
        container
            .read(allTrackedBlocksProvider)
            .any((b) => b.title == 'Evening walk'),
        isFalse,
      );
    },
  );

  testWidgets(
    'Day view: tapping outside the add-block sheet with unsaved changes '
    'asks to save — Save saves it',
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

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      await tester.pumpAndSettle();
      // A goal is required to save now — pick the fixture's one goal.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test goal'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();

      expect(find.text('Save this activity?'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('save'), findsNothing);
      final plannedMatch = container
          .read(allPlannedBlocksProvider)
          .any((b) => b.title == 'Evening walk');
      final trackedMatch = container
          .read(allTrackedBlocksProvider)
          .any((b) => b.title == 'Evening walk');
      expect(plannedMatch || trackedMatch, isTrue);
    },
  );

  testWidgets(
    'Day view: tapping outside the add-block sheet then SAVE with no '
    'activity name set shows the validation error, not a silent no-op',
    (WidgetTester tester) async {
      // The exact bug report this guards: closing via the outside-tap
      // prompt used to route into the same validation as the header
      // "save" link, but showed it as a SnackBar — invisible behind the
      // still-open sheet, so it looked like tapping SAVE did nothing.
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

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();

      // A goal is picked (enough to count as "unsaved changes"), but the
      // activity name is deliberately left blank.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test goal'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();

      expect(find.text('Save this activity?'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Stays open with a visible, inline error — not closed, and not a
      // SnackBar hidden behind the sheet.
      expect(find.text('save'), findsOneWidget);
      expect(find.text('Enter an activity name before saving'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(container.read(allTrackedBlocksProvider), isEmpty);
      expect(container.read(allPlannedBlocksProvider), isEmpty);
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

  testWidgets(
    'Goals: editing a goal that has a reminder shows it already selected, and '
    'saving without touching it keeps it',
    (WidgetTester tester) async {
      // Guards a prefill bug this exact sheet has had before (time ranges
      // used to open empty when editing) — if `_reminderMinutesBefore`
      // didn't seed from the existing goal, an unrelated edit would
      // silently wipe the user's reminder.
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

      final walking = container
          .read(goalsProvider)
          .firstWhere((g) => g.name == 'Walking');
      await container.read(goalsRepositoryProvider).upsert(
        Goal(
          id: walking.id,
          name: walking.name,
          categoryId: walking.categoryId,
          scheduleByWeekday: walking.scheduleByWeekday,
          startDate: walking.startDate,
          endDate: walking.endDate,
          reminderMinutesBefore: 30,
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      // Reminders is step 4 (Category -> Name & dates -> Schedule -> Reminders).
      await _goalSheetNext(tester, 3);

      // Selected chips are a solid accent fill; unselected ones are only
      // bordered — so the fill is what proves it prefilled.
      await tester.ensureVisible(find.text('30 min before'));
      await tester.pumpAndSettle();
      final chip = find
          .ancestor(
            of: find.text('30 min before'),
            matching: find.byType(Container),
          )
          .first;
      final decoration =
          tester.widget<Container>(chip).decoration as BoxDecoration;
      expect(
        decoration.color,
        isNotNull,
        reason: 'the stored 30-minute lead time should open pre-selected',
      );

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        container
            .read(goalsProvider)
            .firstWhere((g) => g.name == 'Walking')
            .reminderMinutesBefore,
        30,
      );
    },
  );

  testWidgets('Categories: renaming a category updates it in the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Goals');
    await tester.tap(find.text('categories'));
    await tester.pumpAndSettle();

    // The whole row is the tap target, so tapping the name opens its edit
    // sheet — no separate "edit" hit needed.
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Strolling');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Strolling'), findsOneWidget);
    expect(find.text('Walking'), findsNothing);
  });

  testWidgets(
    'Categories: deleting a category still leaves its existing blocks '
    'readable rather than crashing',
    (WidgetTester tester) async {
      // resolveCategory falls back to a neutral "Unknown" placeholder for a
      // category deleted out from under existing blocks — this pins that
      // graceful degradation, since blocks keep a bare categoryId with no
      // foreign-key guarantee behind it.
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('categories'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Walking'), findsNothing);

      // Back out to the Day view, which still holds blocks pointing at the
      // now-deleted category — it must render, not throw.
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Calendar');

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Account: shows the signed-in email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Account');

    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets(
    'Account: shows the account creation date when the user has one',
    (WidgetTester tester) async {
      const uid = 'test-uid-with-creation-date';
      final firestore = await seededFirestore(uid);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(
                  uid: uid,
                  email: 'joined@example.com',
                  // UTC noon, not midnight — the screen converts
                  // .toLocal() before formatting, and a midnight UTC input
                  // would land on the wrong calendar day for a negative
                  // host timezone offset. Noon gives real-world margin
                  // either direction.
                  metadata: UserMetadata(
                    DateTime.utc(2025, 3, 14, 12).millisecondsSinceEpoch,
                    DateTime.utc(2025, 3, 14, 12).millisecondsSinceEpoch,
                  ),
                ),
              ),
            ),
            firestoreProvider.overrideWithValue(firestore),
            selectedDateProvider.overrideWith((ref) => mockDay),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');

      expect(find.text('MEMBER SINCE'), findsOneWidget);
      expect(find.text('14 March 2025'), findsOneWidget);
    },
  );

  testWidgets(
    "Account: a user with no real creation timestamp doesn't show a "
    'fabricated one',
    (WidgetTester tester) async {
      // The shared _signedInOverrides fixture's MockUser never sets
      // metadata, so this covers the everyday test path — MockUser then
      // defaults to UserMetadata(0, 0), the epoch, which must not render
      // as if it were a real date.
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');

      expect(find.text('MEMBER SINCE'), findsNothing);
    },
  );

  testWidgets('Account: sign out returns to the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await _signedInOverrides(),
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Account');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(RootShell), findsNothing);
  });
}
