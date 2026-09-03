import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
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
import 'package:calendar_tracker/features/day_view/widgets/legend_row.dart';
import 'package:calendar_tracker/features/day_view/widgets/live_activity_button.dart';
import 'package:calendar_tracker/features/day_view/widgets/live_activity_running_block.dart';
import 'package:calendar_tracker/features/day_view/widgets/start_activity_sheet.dart';
import 'package:calendar_tracker/features/day_view/widgets/plan_block_widget.dart';
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
import 'package:calendar_tracker/models/running_activity.dart';
import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/models/user_settings.dart';
import 'package:calendar_tracker/shared/widgets/app_tab_bar.dart';
import 'package:calendar_tracker/shared/widgets/dashed_border.dart';
import 'package:calendar_tracker/shared/widgets/step_arrow_button.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';
import 'package:calendar_tracker/state/log_entry_providers.dart';
import 'package:calendar_tracker/state/root_shell_providers.dart';
import 'package:calendar_tracker/state/running_activity_providers.dart';
import 'package:calendar_tracker/state/user_settings_providers.dart';

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

/// A goal's own name can collide with plain body text elsewhere on screen
/// once drift is grouped by goal rather than category (e.g. the drift
/// footer's own "test goal" row, always visible whenever that goal is
/// behind) — scoped to any open [BottomSheet] (the add-block sheet itself,
/// and/or its nested goal-picker sheet) sidesteps that ambiguity for the
/// add-block sheet's goal field/picker specifically.
Finder _goalTextInSheet(String name) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(name));

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

Future<void> _selectBlockFilter(WidgetTester tester, String label) async {
  await tester.tap(find.byType(PopupMenuButton<DayViewBlockFilter>));
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
        overrides: [
          ...await _signedInOverrides(),
          // Fixed-scale mode — full-day (the new default) compresses every
          // block down small enough to force the compact label style,
          // which is a different concern from this test's own (rendering
          // without layout errors, with the block's full-style label).
          dayViewFullDayProvider.overrideWith((ref) => false),
        ],
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

  testWidgets(
    'Day view: a block always renders at the height its own real start/end '
    "time implies — a 15-minute actual no longer inflates to a 30-minute "
    "planned block's height just because both used to clamp to the same "
    'fixed minimum',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          ...await _signedInOverrides(),
          // Fixed-scale mode — this test's exact pixel-height math (30m ×
          // 1.2 px/min = 36) assumes the fixed scale, not full-day's own
          // scale (fit-to-viewport, which the new default would otherwise
          // substitute here).
          dayViewFullDayProvider.overrideWith((ref) => false),
        ],
      );
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
          id: 'test-duration-plan',
          start: DateTime(2026, 8, 20, 14, 0),
          end: DateTime(2026, 8, 20, 14, 30), // 30m
          title: 'Test plan',
          categoryId: walkingCategoryId,
        ),
      );
      await container.read(trackedBlocksRepositoryProvider).upsert(
        TrackedBlock(
          id: 'test-duration-actual',
          start: DateTime(2026, 8, 20, 14, 0),
          end: DateTime(2026, 8, 20, 14, 15), // 15m — half the plan's own
          // duration, so its rendered height should be too.
          title: 'Test actual',
          categoryId: walkingCategoryId,
          sourceId: 'manual',
        ),
      );
      await tester.pumpAndSettle();

      final plan = find.byWidgetPredicate(
        (w) => w is PlanBlockWidget && w.block.id == 'test-duration-plan',
      );
      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'test-duration-actual',
      );
      await tester.ensureVisible(plan);
      await tester.ensureVisible(actual);

      // The 30m plan is short enough for the compact combined line, not
      // the usual two-line layout.
      expect(
        find.descendant(of: plan, matching: find.text('30m · Test plan')),
        findsOneWidget,
      );
      // The 15m actual is shorter still — too short for the block's own
      // real height to fit even one line, but the label still renders
      // (overflowing past the block's own tiny box) rather than going
      // missing.
      expect(
        find.descendant(of: actual, matching: find.text('15m · Test actual')),
        findsOneWidget,
      );

      // The actual point of this test: their rendered heights genuinely
      // differ, proportional to their real durations — not both clamped to
      // one shared minimum.
      final planHeight = tester
          .widget<Positioned>(
            find.ancestor(of: plan, matching: find.byType(Positioned)).first,
          )
          .height!;
      final actualHeight = tester
          .widget<Positioned>(
            find.ancestor(of: actual, matching: find.byType(Positioned)).first,
          )
          .height!;
      expect(planHeight, 36); // 30m * 1.2px/min
      expect(actualHeight, 18); // 15m * 1.2px/min
      expect(actualHeight, planHeight / 2);
    },
  );

  testWidgets(
    'Day view: an activity spanning midnight shows up on both days it '
    "touches, each showing only that day's own portion of it — the exact "
    'bug a real user hit: an activity registered Wednesday evening to '
    "Thursday 1:30am simply never appeared anywhere on Thursday's own "
    'column',
    (WidgetTester tester) async {
      final wednesday = DateTime(2026, 8, 19);
      final thursday = DateTime(2026, 8, 20); // mockDay
      final container = ProviderContainer(
        overrides: [
          ...await _signedInOverrides(),
          selectedDateProvider.overrideWith((ref) => wednesday),
          // Fixed scale, for exact pixel-height math below.
          dayViewFullDayProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await container.read(trackedBlocksRepositoryProvider).upsert(
        TrackedBlock(
          id: 'test-overnight',
          start: DateTime(2026, 8, 19, 23, 0),
          end: DateTime(2026, 8, 20, 1, 30), // 2h30m total
          title: 'Overnight walk',
          categoryId: walkingCategoryId,
          sourceId: 'manual',
        ),
      );
      await tester.pumpAndSettle();

      final onWednesday = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'test-overnight',
      );
      expect(onWednesday, findsOneWidget);
      // Clamped to Wednesday's own 23:00–24:00 — just the 1h portion that
      // actually falls on this day, not the block's full 2h30m duration.
      expect(
        tester
            .widget<Positioned>(
              find.ancestor(of: onWednesday, matching: find.byType(Positioned)).first,
            )
            .height,
        72, // 60m * 1.2px/min
      );

      container.read(selectedDateProvider.notifier).state = thursday;
      await tester.pumpAndSettle();

      final onThursday = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'test-overnight',
      );
      expect(
        onThursday,
        findsOneWidget,
        reason: "the exact bug: this used to find nothing on Thursday's "
            'own column at all',
      );
      // Clamped to Thursday's own 00:00–01:30 — the other 1h30m portion,
      // positioned from the top of the column rather than at 23:00 (which
      // would be the block's own absolute start time, wrong for this day).
      expect(
        tester
            .widget<Positioned>(
              find.ancestor(of: onThursday, matching: find.byType(Positioned)).first,
            )
            .height,
        108, // 90m * 1.2px/min
      );
      expect(
        tester
            .widget<Positioned>(
              find.ancestor(of: onThursday, matching: find.byType(Positioned)).first,
            )
            .top,
        0,
      );
    },
  );

  testWidgets(
    "Day view: an actual block is inset from its column's left edge — a "
    "planned block for the same time isn't fully covered by it",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // mock_day_20aug.dart: 'actual-walk' carries plannedBlockId
      // 'plan-walk' — both occupy the same day-column, at overlapping
      // times.
      final plan = find.byWidgetPredicate(
        (w) => w is PlanBlockWidget && w.block.id == 'plan-walk',
      );
      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );
      await tester.ensureVisible(plan);
      await tester.ensureVisible(actual);
      expect(plan, findsOneWidget);
      expect(actual, findsOneWidget);

      final planPositioned = tester.widget<Positioned>(
        find.ancestor(of: plan, matching: find.byType(Positioned)).first,
      );
      final actualPositioned = tester.widget<Positioned>(
        find.ancestor(of: actual, matching: find.byType(Positioned)).first,
      );

      // Planned still spans the column's full width, from its own left
      // edge — only the actual block is inset, by a tenth of that same
      // column width, so a tenth of the planned block stays visible
      // rather than being fully covered.
      const inset = 0.1;
      expect(
        actualPositioned.left,
        closeTo(planPositioned.left! + planPositioned.width! * inset, 0.01),
      );
      expect(
        actualPositioned.width,
        closeTo(planPositioned.width! * (1 - inset), 0.01),
      );
    },
  );

  testWidgets(
    'Day view: tapping an actual block opens a detail popup showing its '
    'date, start–end time, and duration',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );
      await tester.ensureVisible(actual);
      await tester.tap(actual);
      await tester.pumpAndSettle();

      // 'actual-walk' (mock_day_20aug.dart): 07:00–07:48 on 20 Aug 2026.
      expect(tester.takeException(), isNull);
      expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
      expect(find.text('07:00–07:48 · 48m'), findsOneWidget);
    },
  );

  testWidgets(
    "Day view: the detail popup also shows the block's own goal, and "
    "tapping it opens that goal's detail",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );
      await tester.ensureVisible(actual);
      await tester.tap(actual);
      await tester.pumpAndSettle();

      // 'actual-walk' is in the Walking category, which backs the
      // "Walking" goal — same pairing the Activities list shows.
      expect(tester.takeException(), isNull);
      final goalLabel = find.text('Walking');
      expect(goalLabel, findsOneWidget);

      await tester.tap(goalLabel);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(GoalDetailSheet), findsOneWidget);
    },
  );

  testWidgets(
    "Day view: the detail popup's edit icon opens the same edit sheet as "
    "the Activities list's own edit link, prefilled",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );
      await tester.ensureVisible(actual);
      await tester.tap(actual);
      await tester.pumpAndSettle();

      await tester.tap(find.text('✎'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit activity'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LogActivitySheet),
          matching: find.text('Walk 48 m'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "Day view: the detail popup's delete icon confirms before "
    'soft-deleting, and leaves the entry alone on Cancel',
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

      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );
      await tester.ensureVisible(actual);
      await tester.tap(actual);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🗑'));
      await tester.pumpAndSettle();

      // Cancel — the popup itself stays open, the entry is untouched.
      expect(find.text('Delete activity?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isNotEmpty,
      );

      // Delete again, this time confirming.
      await tester.tap(find.text('🗑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        container
            .read(allTrackedBlocksProvider)
            .where((b) => b.id == 'actual-walk'),
        isEmpty,
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
    'Day view: in 3 Day mode, the header arrows slide the window by one '
    "day, not by three — Working week/Week still jump by their whole "
    'window',
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

      await _selectDayViewMode(tester, '3 Day');
      await tester.pumpAndSettle();

      // mockDay is 20 Aug — 3 Day starts there: 20/21/22 Aug.
      expect(container.read(selectedDateProvider), DateTime(2026, 8, 20));

      final arrows = find.descendant(
        of: find.byType(DayHeaderBar),
        matching: find.byType(StepArrowButton),
      );
      await tester.tap(arrows.at(1)); // next
      await tester.pumpAndSettle();

      // A sliding window by one day (21 Aug), not a jump to a disjoint
      // next set of three (23 Aug).
      expect(container.read(selectedDateProvider), DateTime(2026, 8, 21));

      await _selectDayViewMode(tester, 'Week');
      await tester.pumpAndSettle();

      final weekStartBefore = container.read(selectedDateProvider);
      await tester.tap(
        find
            .descendant(
              of: find.byType(DayHeaderBar),
              matching: find.byType(StepArrowButton),
            )
            .at(1), // next
      );
      await tester.pumpAndSettle();

      // Week mode still jumps a full 7 days, unaffected by the 3 Day fix.
      expect(
        container.read(selectedDateProvider),
        weekStartBefore.add(const Duration(days: 7)),
      );
    },
  );

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
      await tester.tap(_goalTextInSheet('test goal'));
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

  testWidgets('Goals: a leftward swipe steps to the next tab (Planning)', (
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
    'Account: a rightward swipe steps to the previous tab (Planning)',
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
      expect(container.read(currentTabIndexProvider), 3);

      await tester.fling(
        find.byType(AccountScreen),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(currentTabIndexProvider), 2);
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
    expect(container.read(currentTabIndexProvider), 3);

    // Account is already the last tab — swiping further "next" should
    // stay put, not wrap around to Day.
    await tester.fling(
      find.byType(AccountScreen),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(currentTabIndexProvider), 3);
  });

  testWidgets(
    'Capacity: its own top-level tab shows per-day free time and per-goal '
    'room, and switching to Account still shows the account details',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Planning');
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

      await _tapTab(tester, 'Account');
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

      // Monday's own tracking window narrowed to 8h (09:00–17:00) — the
      // default is the full 24h, which nothing short of a fully-booked day
      // could ever exceed.
      await container.read(userSettingsDocProvider).set(
        const UserSettings(
          trackingWindowsByWeekday: {
            DateTime.monday: [
              ClockRange(ClockTime(9, 0), ClockTime(17, 0)),
            ],
          },
        ).toMap(),
      );
      // 12 hours of manually planned time on that same Monday — more than
      // its own 8h window — on top of whatever the seed data already has.
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

      await _tapTab(tester, 'Planning');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('over by'), findsWidgets);
    },
  );

  testWidgets(
    "Capacity: tapping a day opens a small read-only preview of that "
    "day's planned blocks",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Planning');
      await tester.pumpAndSettle();

      await tester.tap(find.text('MON 17'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Monday, 17 Aug'), findsOneWidget);
      // Monday's own 09:00–12:00 "Deep work 3 h" planned block shows up,
      // positioned and labelled the same way the real Day view would.
      expect(find.text('Deep work 3 h'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(find.text('Monday, 17 Aug'), findsNothing);
    },
  );

  testWidgets(
    "Capacity: a goal's own generated schedule counts as planned there "
    "too, not just on the Day view's own legend",
    (WidgetTester tester) async {
      // _signedInOnboardedNoActivityOverrides seeds one goal ("Test goal",
      // category "Work") with a plain 30m/day schedule and zero manually
      // created planned blocks — so this can only be coming from the
      // goal's own schedule, not a manual block. A real gap a user hit:
      // Capacity's own total silently didn't count it, since it only ever
      // read manually created PlannedBlocks — unlike the Day view legend,
      // which folds a goal's own schedule in too (though there, a
      // plain-duration entry like this one — no fixed clock time — counts
      // as "unscheduled", not "planned"; see dayTotalsProvider's own doc
      // comment).
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOnboardedNoActivityOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('planned 0m'), findsOneWidget);
      expect(find.text('unscheduled 30m'), findsOneWidget);

      await _tapTab(tester, 'Planning');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 30m/day * 7 days = 3h 30m for the week — not "0m".
      expect(find.text('3h 30m'), findsOneWidget);
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
    "Log activity: Save lives in the header next to close, not as a "
    'separate full-width button below the form',
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

      // Both "close" and "Save changes" sit in the same header Row as the
      // sheet's own title, not scattered elsewhere in the form.
      final headerRow = find
          .ancestor(
            of: find.text('Edit activity'),
            matching: find.byType(Row),
          )
          .first;
      expect(
        find.descendant(of: headerRow, matching: find.text('close')),
        findsOneWidget,
      );
      // Only one "Save changes" anywhere in the sheet — scoped to the
      // header, not duplicated as a separate full-width button elsewhere
      // in the form.
      expect(
        find.descendant(of: headerRow, matching: find.text('Save changes')),
        findsOneWidget,
      );
      expect(find.text('Save changes'), findsOneWidget);
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

  testWidgets(
    'Activities: the search field filters by title or goal name, hiding '
    'non-matching entries and days entirely',
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

      expect(find.text('Walk 48 m'), findsOneWidget);
      expect(find.text('Deep work 1 h 45'), findsOneWidget);

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'walk');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Title match, on two different days.
      expect(find.text('Walk 48 m'), findsOneWidget);
      expect(find.text('Walk 25 m'), findsOneWidget);
      // A day with nothing matching disappears entirely, not just its rows.
      expect(find.text('Deep work 1 h 45'), findsNothing);

      // Matches by goal name too, not just the block's own title.
      await tester.enterText(searchField, 'walking');
      await tester.pumpAndSettle();
      expect(find.text('Walk 48 m'), findsOneWidget);

      // Clearing the field shows everything again.
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('Deep work 1 h 45'), findsOneWidget);

      // A query matching nothing says so, instead of an empty blank list.
      await tester.enterText(searchField, 'zzz-nonexistent');
      await tester.pumpAndSettle();
      expect(find.textContaining('No activities match'), findsOneWidget);
      expect(find.text('Walk 48 m'), findsNothing);
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
    // Sheet closed this time — back on the Day view, entry visible there.
    // 15 minutes is too short to fit even a compact label (see
    // BlockLabelStyle.hidden), so the block itself — not its text — is
    // what's checked here.
    expect(
      find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.title == 'Recovered entry',
      ),
      findsOneWidget,
    );
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
    // block should now render there too. 30 minutes renders compact
    // (duration combined with title on one line), not the plain title
    // alone — see ActualBlockWidget's own `compact` doc comment.
    expect(find.text('30m · Evening walk'), findsOneWidget);
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
    "Goals: a second goal sharing a category with an existing one gets "
    "its own planned hours, not a copy of the first goal's — the exact "
    "bug a real user hit adding a second goal ('side project') under the "
    "same category as an existing one ('job')",
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

      // _signedInOnboardedNoActivityOverrides seeds 'goal-1' ("Test goal",
      // category "cat-1"/"Work") with a duration-only schedule, which never
      // generates a block (see generateGoalPlannedBlocksForDate), so its
      // own plannedHours is driven purely by manually planned blocks in
      // "cat-1". Add a second goal in the same category with no schedule
      // of its own, then manually plan one block in "cat-1" — a manually
      // planned block only ever carries a category, never a goal id, so
      // before the fix that block's hours got credited to *both* goals,
      // making their plannedHours identical (the exact bug: a real user's
      // new "side project" goal read the same planned hours as "job",
      // both sharing "work").
      final secondGoal = Goal(
        id: 'goal-2',
        name: 'Side project',
        categoryId: 'cat-1',
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2099, 12, 31),
        scheduleByWeekday: {for (var weekday = 1; weekday <= 7; weekday++) weekday: []},
      );
      await container.read(goalsRepositoryProvider).upsert(secondGoal);

      final selectedDate = container.read(selectedDateProvider);
      await container
          .read(plannedBlocksRepositoryProvider)
          .upsert(
            PlannedBlock(
              id: 'test-plan-work',
              start: DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                9,
                0,
              ),
              end: DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                11,
                0,
              ),
              title: 'Deep work',
              categoryId: 'cat-1',
            ),
          );
      await tester.pumpAndSettle();

      final progressList = container.read(goalProgressListProvider);
      final firstGoalProgress = progressList.firstWhere(
        (p) => p.goal.id == 'goal-1',
      );
      final secondGoalProgress = progressList.firstWhere(
        (p) => p.goal.id == 'goal-2',
      );

      // Exactly one of the two goals is credited with the 2h manual block
      // — never both, and never neither.
      final plannedTotals = [
        firstGoalProgress.plannedHours,
        secondGoalProgress.plannedHours,
      ]..sort();
      expect(plannedTotals, [0.0, 2.0]);
    },
  );

  testWidgets(
    "Day view: a goal's own schedule counts as planned even with no "
    'manually-created planned block and nothing tracked yet — both the '
    'legend total and the drift footer reflect it',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOnboardedNoActivityOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // _signedInOnboardedNoActivityOverrides seeds exactly one goal
      // ("Test goal", category "Work") with a plain 30m/day schedule and
      // zero planned/tracked blocks of any kind — so this total can only
      // be coming from the goal's own schedule, not a manual block. It has
      // no fixed clock time, so it counts as "unscheduled" rather than
      // "planned" — see dayTotalsProvider's own doc comment.
      expect(tester.takeException(), isNull);
      expect(find.text('planned 0m'), findsOneWidget);
      expect(find.text('unscheduled 30m'), findsOneWidget);
      // "tracked" is the configured tracking window (defaults to the full
      // 24h — no settings saved for this fixture); "registered" is what's
      // actually been logged, zero here.
      expect(find.text('tracked 24h'), findsOneWidget);
      expect(find.text('registered 0m'), findsOneWidget);

      // Drift footer: nothing tracked against a 30m target reads as −30m,
      // under the goal's own name (lowercased) — drift is grouped by goal,
      // not category, so a category backing more than one goal can show
      // each goal's drift on its own row.
      expect(find.text('test goal'), findsOneWidget);
      expect(find.text('−30m'), findsOneWidget);

      // The whole word still rendered in the goal's own category's color.
      final coloredWord = tester.widget<Text>(find.text('test goal'));
      expect(coloredWord.style?.color, const Color(0xFF0278E7));
    },
  );

  testWidgets(
    'Day view: a goal tracked past its own plan drops off the drift '
    "footer entirely — exceeding a target is fine, it's only falling "
    'short that counts as drift',
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

      // The fixture's one goal ("Test goal") targets 30m/day — log 45m
      // against it, past that target.
      final selectedDate = container.read(selectedDateProvider);
      await container
          .read(trackedBlocksRepositoryProvider)
          .upsert(
            TrackedBlock(
              id: 'test-tracked-exceeded',
              start: DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                7,
                0,
              ),
              end: DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                7,
                45,
              ),
              title: 'Test goal',
              categoryId: 'cat-1',
              sourceId: 'manual',
            ),
          );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Still labelled "DRIFT TODAY" — just with nothing under it, since
      // the one goal on screen is now ahead of its plan, not behind.
      expect(find.text('DRIFT TODAY'), findsOneWidget);
      expect(find.text('test goal'), findsNothing);
      expect(find.textContaining('+15m'), findsNothing);
    },
  );

  testWidgets(
    'Day view: the header legend totals every visible day, not just the '
    'selected one — switching to 3 Day should show 3 days of planned time, '
    'not still just one',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOnboardedNoActivityOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Day mode: one day's worth of the goal's own 30m/day schedule — no
      // fixed clock time, so it's "unscheduled" rather than "planned" (see
      // dayTotalsProvider's own doc comment).
      expect(find.text('planned 0m'), findsOneWidget);
      expect(find.text('unscheduled 30m'), findsOneWidget);

      await _selectDayViewMode(tester, '3 Day');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 3 Day (and beyond) collapses the legend to icon + value only —
      // the word ("planned"/etc.) is what's hidden by default and
      // revealed one at a time by tapping — see LegendRow's own doc
      // comment for why (the word prefixes are what overflow a real
      // phone width). The legend's own GestureDetectors, in item order:
      // tracked, planned, registered, unscheduled — that fourth one only
      // rendered here because this fixture actually has some.
      final legendTaps = find.descendant(
        of: find.byType(LegendRow),
        matching: find.byType(GestureDetector),
      );
      expect(legendTaps, findsNWidgets(4));

      // Three visible days, each with the same 30m/day schedule — the bug
      // this covers: the legend used to keep showing just one day's 30m
      // even with three days on screen. The value alone is already
      // visible next to the icon, with no tap needed. It's the
      // "unscheduled" total that carries this now, not "planned" — the
      // goal's schedule has no fixed clock time.
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('unscheduled 1h 30m'), findsNothing);
      expect(find.text('unscheduled 30m'), findsNothing);

      await tester.tap(legendTaps.at(3)); // unscheduled
      await tester.pumpAndSettle();
      // Tapping reveals the word alongside the same value.
      expect(find.text('unscheduled 1h 30m'), findsOneWidget);
      expect(find.text('1h 30m'), findsNothing);

      await tester.tap(legendTaps.at(0)); // tracked
      await tester.pumpAndSettle();
      // "tracked" (the window) sums the same way — 3 days at the default
      // full 24h each (formatDuration doesn't roll over into "days").
      expect(find.text('tracked 72h'), findsOneWidget);
    },
  );

  testWidgets(
    'Day view: the drift footer also totals every visible day, and drops '
    'the "TODAY" label once more than one day is on screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOnboardedNoActivityOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Day mode: nothing tracked against one day's 30m target reads as
      // −30m, labelled "DRIFT TODAY".
      expect(find.text('DRIFT TODAY'), findsOneWidget);
      expect(find.text('−30m'), findsOneWidget);

      await _selectDayViewMode(tester, '3 Day');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Three days' worth of the same 30m/day target, still nothing
      // tracked — the bug this covers: drift used to keep comparing
      // against just one day's target even with three days on screen. The
      // "TODAY" label is also gone now that it isn't just today.
      expect(find.text('DRIFT'), findsOneWidget);
      expect(find.text('DRIFT TODAY'), findsNothing);
      expect(find.text('−1h 30m'), findsOneWidget);
      expect(find.text('−30m'), findsNothing);
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

      // Scoped to the sheet — the new goal's own default schedule now also
      // gives it a nonzero planned total, so "reading" (lowercased) shows a
      // second time in the still-mounted Day view's own DRIFT TODAY footer
      // behind the sheet.
      expect(
        find.descendant(
          of: find.byType(LogActivitySheet),
          matching: find.text('reading'),
        ),
        findsOneWidget, // now selectable, by goal
      );
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
      // Opened from empty space, not a plan — no "matches a planned
      // activity" icon.
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Matches a planned activity',
        ),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField).first, 'Morning walk');
      await tester.pumpAndSettle();

      // "test goal" — the fixture's one goal, in the picker list. Not the
      // category name ("Work") — goals and categories happen to differ here
      // specifically so this can't pass by coincidence.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(_goalTextInSheet('test goal'));
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
    'Day view: tapping empty space on a future date opens it as a planned '
    'activity, not an actual one — logging something as already done '
    "before it's even happened doesn't make sense",
    (WidgetTester tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final container = ProviderContainer(
        overrides: [
          ...await _signedInOnboardedNoActivityOverrides(),
          selectedDateProvider.overrideWith((ref) => futureDate),
        ],
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
      expect(find.text('New planned activity'), findsOneWidget);
      expect(find.text('New actual activity'), findsNothing);
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
      expect(_goalTextInSheet('test goal'), findsNothing);

      // Tapping opens a flat picker list rather than a native dropdown menu.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      expect(_goalTextInSheet('test goal'), findsOneWidget); // the one list row

      await tester.tap(_goalTextInSheet('test goal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Picker closed, field now shows the picked goal.
      expect(find.text('set goal'), findsNothing);
      expect(_goalTextInSheet('test goal'), findsOneWidget);

      // The bottom save button is gone — "save" now lives in the header,
      // next to the title, to keep the sheet as short as possible.
      expect(find.text('save'), findsOneWidget);
      expect(find.text('ADD PLAN'), findsNothing);
      expect(find.text('Save activity'), findsNothing);
    },
  );

  testWidgets(
    'Day view: tapping an existing planned block also opens the add-actual '
    "sheet, prefilled with that plan's own title, time, and goal",
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

      await container.read(plannedBlocksRepositoryProvider).upsert(
        PlannedBlock(
          id: 'plan-lunch-test',
          start: DateTime(2026, 8, 20, 12, 0),
          end: DateTime(2026, 8, 20, 12, 30),
          title: 'Team sync',
          categoryId: 'cat-1',
        ),
      );
      await tester.pumpAndSettle();

      final planBlock = find.byWidgetPredicate(
        (w) => w is PlanBlockWidget && w.block.id == 'plan-lunch-test',
      );
      await tester.ensureVisible(planBlock);
      await tester.tap(planBlock);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New actual activity'), findsOneWidget);
      // Prefilled from the plan, not blank — title, a 30m duration derived
      // from the plan's own start/end, and the goal backing its category.
      // Scoped to the sheet since the still-mounted planned block behind
      // it also shows its own "Team sync" title text.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Team sync')),
        findsOneWidget,
      );
      expect(find.text('· 30m'), findsOneWidget);
      expect(_goalTextInSheet('test goal'), findsOneWidget); // dropdown lowercases
      expect(find.text('set goal'), findsNothing);
      // The "matches a planned activity" icon shows only because this sheet
      // was opened by tapping the plan, not an empty-space tap.
      expect(
        find.descendant(
          of: sheet,
          matching: find.byWidgetPredicate(
            (w) => w is Tooltip && w.message == 'Matches a planned activity',
          ),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('save'));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final created = container
          .read(allTrackedBlocksProvider)
          .where((b) => b.categoryId == 'cat-1');
      expect(created, hasLength(1));
      expect(created.single.title, 'Team sync');
      expect(created.single.start, DateTime(2026, 8, 20, 12, 0));
      expect(created.single.end, DateTime(2026, 8, 20, 12, 30));
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
    'Day view: the add-block sheet does not require an activity name — a '
    "blank one falls back to the goal's own name, same as Log Activity",
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
      await tester.tap(_goalTextInSheet('test goal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Saved and closed, not blocked — the sheet header is gone.
      expect(find.text('New actual activity'), findsNothing);
      final savedTitles = [
        ...container.read(allTrackedBlocksProvider).map((b) => b.title),
        ...container.read(allPlannedBlocksProvider).map((b) => b.title),
      ];
      expect(savedTitles, ['Test goal']);
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
      await tester.tap(_goalTextInSheet('test goal'));
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
    "activity name set also falls back to the goal's own name, the same "
    'as the header "save" link',
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

      // A goal is picked (enough to count as "unsaved changes"), but the
      // activity name is deliberately left blank.
      await tester.tap(find.text('set goal'));
      await tester.pumpAndSettle();
      await tester.tap(_goalTextInSheet('test goal'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();

      expect(find.text('Save this activity?'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final savedTitles = [
        ...container.read(allTrackedBlocksProvider).map((b) => b.title),
        ...container.read(allPlannedBlocksProvider).map((b) => b.title),
      ];
      expect(savedTitles, ['Test goal']);
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
    'Day view: the "24h" toggle switches the timeline to a non-scrolling '
    'full-day layout and back',
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

      // On by default now — see dayViewFullDayProvider's own doc comment.
      expect(container.read(dayViewFullDayProvider), isTrue);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      await tester.tap(find.text('24h'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(dayViewFullDayProvider), isFalse);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );

      await tester.tap(find.text('24h'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(dayViewFullDayProvider), isTrue);
    },
  );

  testWidgets(
    'Day view: the All/Planned/Registered filter hides the other kind of '
    "block from the timeline, without touching the legend's own totals",
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

      final plan = find.byWidgetPredicate(
        (w) => w is PlanBlockWidget && w.block.id == 'plan-walk',
      );
      final actual = find.byWidgetPredicate(
        (w) => w is ActualBlockWidget && w.block.id == 'actual-walk',
      );

      // All — the default — shows every planned and tracked block.
      expect(container.read(dayViewBlockFilterProvider), DayViewBlockFilter.both);
      expect(plan, findsOneWidget);
      expect(actual, findsOneWidget);

      await _selectBlockFilter(tester, 'Planned');
      expect(tester.takeException(), isNull);
      expect(
        container.read(dayViewBlockFilterProvider),
        DayViewBlockFilter.plannedOnly,
      );
      expect(plan, findsOneWidget);
      expect(actual, findsNothing);

      await _selectBlockFilter(tester, 'Registered');
      expect(tester.takeException(), isNull);
      expect(
        container.read(dayViewBlockFilterProvider),
        DayViewBlockFilter.registeredOnly,
      );
      expect(plan, findsNothing);
      expect(actual, findsOneWidget);

      // The legend's own totals are unaffected — they reflect the full
      // day's data regardless of what the grid currently hides. Captured
      // as whatever the fixture's real numbers are, rather than hardcoded,
      // since they're a sum over several seeded blocks.
      final plannedLegend = tester
          .widget<Text>(
            find.byWidgetPredicate(
              (w) => w is Text && (w.data?.startsWith('planned ') ?? false),
            ),
          )
          .data;
      final registeredLegend = tester
          .widget<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text && (w.data?.startsWith('registered ') ?? false),
            ),
          )
          .data;

      await _selectBlockFilter(tester, 'All');
      expect(tester.takeException(), isNull);
      expect(container.read(dayViewBlockFilterProvider), DayViewBlockFilter.both);
      expect(plan, findsOneWidget);
      expect(actual, findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byWidgetPredicate(
                (w) => w is Text && (w.data?.startsWith('planned ') ?? false),
              ),
            )
            .data,
        plannedLegend,
      );
      expect(
        tester
            .widget<Text>(
              find.byWidgetPredicate(
                (w) =>
                    w is Text && (w.data?.startsWith('registered ') ?? false),
              ),
            )
            .data,
        registeredLegend,
      );
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
    'Account: the tracking window sheet defaults every weekday to the full '
    "24 hours for an account that's never set one",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInOverrides(),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      expect(find.text('TRACKING WINDOW'), findsOneWidget);

      await tester.tap(find.text('Edit tracking window'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tracking window'), findsOneWidget);
      // Every one of the 7 weekdays defaults to the full day — "24h"
      // appears twice per day: once as the section's own summary label,
      // once as the single range row's own duration (00:00–24:00 is a
      // real 24h span).
      expect(find.text('24h'), findsNWidgets(14));

      // Closing with no changes made shouldn't prompt to save anything.
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(find.text('Tracking window'), findsNothing);
    },
  );

  testWidgets(
    'Account: a saved per-weekday tracking window shows in the sheet and '
    'feeds the Capacity page',
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

      // Every weekday narrowed to 8h (09:00–17:00) — saved directly,
      // bypassing the actual time-picker dialogs (Material's own picker
      // isn't practical to drive from a widget test) — this still
      // exercises the real Firestore doc and every provider downstream of
      // it, the same way other tests write through e.g.
      // plannedBlocksRepositoryProvider directly.
      await container.read(userSettingsDocProvider).set(
        UserSettings(
          trackingWindowsByWeekday: {
            for (var weekday = 1; weekday <= 7; weekday++)
              weekday: const [ClockRange(ClockTime(9, 0), ClockTime(17, 0))],
          },
        ).toMap(),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Edit tracking window'));
      await tester.pumpAndSettle();

      // 24-hour clock format (ClockTime.format()), not TimeOfDay's
      // localized "9:00 AM" — one row per weekday, all identical.
      expect(find.text('09:00'), findsNWidgets(7));
      expect(find.text('17:00'), findsNWidgets(7));
      expect(find.text('24h'), findsNothing);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Planning');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 8h/day * 7 days = 56h total window, not the default's 168h
      // (24h * 7).
      expect(find.textContaining('of 56h this week'), findsOneWidget);
    },
  );

  testWidgets(
    'Account: a failed tracking-window save shows an inline error and '
    'keeps the sheet open, rather than silently doing nothing — the exact '
    'bug this app shipped once (Firestore rules not deployed for the new '
    "collection, and nothing caught the resulting permission-denied)",
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          ...await _signedInOverrides(),
          // Everything else (snapshots(), used to seed the sheet) still
          // works normally — only the save call itself is broken here, so
          // this isolates that one path. `DocumentReference` is a sealed
          // class in cloud_firestore, so it can't be wrapped/faked
          // directly the way this app's other repository providers can be
          // — overriding this provider instead is the actual seam built
          // for exactly this.
          saveUserSettingsProvider.overrideWithValue(
            (settings) => Future.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
                message: 'The caller does not have permission.',
              ),
            ),
          ),
        ],
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
      await tester.tap(find.text('Edit tracking window'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The sheet is still open — a silent failure would have looked
      // identical to a successful save closing it.
      expect(find.text('Tracking window'), findsOneWidget);
      expect(
        find.textContaining("Couldn't save"),
        findsOneWidget,
      );
    },
  );

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

  testWidgets(
    'Live activity: Start opens a goal picker, and starting shows a live '
    'Stop button in place of Start',
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

      expect(container.read(runningActivityProvider), isNull);

      await tester.tap(find.text('▶ Start'));
      await tester.pumpAndSettle();

      expect(find.text('Start activity'), findsOneWidget);
      // Picking a goal is required — Start with none picked says so
      // instead of silently doing nothing.
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a goal before starting'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(StartActivitySheet),
          matching: find.text('walking'),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('Start activity'), findsNothing);
      final running = container.read(runningActivityProvider);
      expect(running, isNotNull);
      expect(running!.goalId, 'goal-walking');
      expect(running.categoryId, walkingCategoryId);
      expect(running.title, 'Walking');
      expect(find.textContaining('Stop'), findsOneWidget);
      expect(find.text('▶ Start'), findsNothing);

      // Stop the run before the test ends — liveActivityTickProvider's own
      // once-a-second timer stays alive for as long as something's
      // running, and flutter_test asserts no timer is still pending once
      // the widget tree is disposed at teardown.
      await tester.tap(find.byType(LiveActivityButton));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    "Live activity: the run itself shows up on today's calendar grid while "
    "it's still going, sized to its own real elapsed duration, and tapping "
    'it stops the run same as the header pill does',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          ...await _signedInOverrides(),
          // _signedInOverrides pins the Day view to the fixture's own
          // mock day (20 Aug 2026) — a run "started just now" needs
          // today actually on screen to show up at all.
          selectedDateProvider.overrideWith((ref) => DateTime.now()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing to show yet — findsNothing rather than an error, since the
      // widget simply isn't built at all while nothing's running.
      expect(find.byType(LiveActivityRunningBlock), findsNothing);

      Future<void> startedMinutesAgo(int minutes) =>
          container.read(runningActivityDocProvider).set(
            RunningActivity(
              startedAt: DateTime.now().subtract(Duration(minutes: minutes)),
              goalId: 'goal-walking',
              categoryId: walkingCategoryId,
              title: 'Walking',
            ).toMap(),
          );

      await startedMinutesAgo(2);
      await tester.pumpAndSettle();

      final block = find.byType(LiveActivityRunningBlock);
      expect(block, findsOneWidget);
      final shortHeight = tester
          .widget<Positioned>(
            find.ancestor(of: block, matching: find.byType(Positioned)).first,
          )
          .height!;

      // A run that's been going five times as long renders taller, in
      // real proportion to its own elapsed duration — not frozen at some
      // fixed placeholder size regardless of how long it's actually run
      // (DateTime.now() isn't virtualized by flutter_test, so this checks
      // two known elapsed durations rather than trying to simulate real
      // time passing mid-test).
      await startedMinutesAgo(10);
      await tester.pumpAndSettle();
      final longHeight = tester
          .widget<Positioned>(
            find.ancestor(of: block, matching: find.byType(Positioned)).first,
          )
          .height!;
      expect(longHeight, greaterThan(shortHeight));

      await tester.tap(block);
      await tester.pumpAndSettle();

      expect(container.read(runningActivityProvider), isNull);
      expect(find.byType(LiveActivityRunningBlock), findsNothing);
    },
  );

  testWidgets(
    'Live activity: Stop registers a real tracked block spanning start to '
    'stop, and clears the running state',
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

      final beforeCount = container.read(allTrackedBlocksProvider).length;

      await tester.tap(find.text('▶ Start'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(StartActivitySheet),
          matching: find.text('walking'),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LiveActivityButton));
      await tester.pumpAndSettle();

      expect(container.read(runningActivityProvider), isNull);
      expect(find.text('▶ Start'), findsOneWidget);

      final all = container.read(allTrackedBlocksProvider);
      expect(all.length, beforeCount + 1);
      final logged = all.firstWhere((b) => b.sourceId == 'manual' && b.id.startsWith('live-'));
      expect(logged.title, 'Walking');
      expect(logged.categoryId, walkingCategoryId);
      expect(logged.end.isBefore(logged.start), isFalse);
    },
  );

  testWidgets(
    'Live activity: a run started stays running across a simulated app '
    'restart (a fresh ProviderContainer over the same Firestore data)',
    (WidgetTester tester) async {
      const uid = 'restart-uid';
      final firestore = FakeFirebaseFirestore();
      final firestoreOverride = firestoreProvider.overrideWithValue(firestore);
      // A fresh MockFirebaseAuth per container, not one shared instance —
      // its sign-in event fires exactly once, at construction, onto a
      // broadcast stream with no replay for late subscribers, so reusing
      // one instance across two containers would leave the second one
      // waiting on an authStateChanges() event that already fired before
      // it existed and hang forever. Two separate (but both signed-in-as-
      // the-same-uid) instances is also the more faithful simulation
      // anyway — a real cold relaunch gets its own fresh
      // `authStateChanges()` emission from the persisted native session,
      // not a continuation of the previous run's stream.
      final container1 = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: uid, email: 'restart@example.com'),
            ),
          ),
          firestoreOverride,
        ],
      );
      await container1.read(authStateChangesProvider.future);
      await container1
          .read(runningActivityDocProvider)
          .set(
            RunningActivity(
              startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
              goalId: 'goal-walking',
              categoryId: walkingCategoryId,
              title: 'Walking',
            ).toMap(),
          );
      container1.dispose();

      // A brand-new container, same underlying Firestore data — the same
      // shape a real cold app relaunch takes (nothing carries over except
      // what's actually persisted).
      final container2 = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: uid, email: 'restart@example.com'),
            ),
          ),
          firestoreOverride,
        ],
      );
      addTearDown(container2.dispose);
      await container2.read(authStateChangesProvider.future);
      final running = await container2.read(
        runningActivityStreamProvider.future,
      );

      expect(running, isNotNull);
      expect(running!.goalId, 'goal-walking');
      expect(running.categoryId, walkingCategoryId);
      expect(running.title, 'Walking');
    },
  );
}
