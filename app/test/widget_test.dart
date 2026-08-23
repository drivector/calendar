import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/features/categories/categories_screen.dart';
import 'package:calendar_tracker/features/day_view/widgets/day_header_bar.dart';
import 'package:calendar_tracker/features/day_view/widgets/time_body_grid.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_detail_sheet.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/features/week_view/week_view_screen.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/shared/widgets/step_arrow_button.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';
import 'package:calendar_tracker/state/log_entry_providers.dart';

void main() {
  testWidgets('Day view renders the mock day without layout errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walk 45 m'), findsOneWidget);
    expect(find.text('2 h 35 untracked'), findsOneWidget);
  });

  testWidgets('Day view: the header arrows step to the next/previous day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    for (final tab in ['WEEK', 'GOALS', '+ LOG', 'DAY']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after tapping $tab');
    }
  });

  testWidgets('Week screen renders day rows and the goals footer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
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

  testWidgets('Goals screen renders a block per mock goal',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.textContaining('over cap by'), findsWidgets);
  });

  testWidgets('Log activity: filling the form computes a duration',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets); // duration + counts-toward, empty

    await tester.tap(find.text('deep work'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Deep work 20 h/wk'), findsOneWidget);
  });

  testWidgets('Tapping a day in the Week view opens that day in Day view',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
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

  testWidgets('Goals: editing from the detail sheet and deleting removes it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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

  testWidgets('Goals: creating a new goal with per-day targets adds it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget);
    // Every day defaults to 30 min.
    expect(find.text('30 m'), findsNWidgets(7));

    // Bump Monday's target by 3 steps of 5 minutes (30m -> 45m). Scrolling
    // happens before text entry — a drag gesture landing on the Name field
    // afterwards can disturb its content, so do all scrolling first.
    final mondayRow = find.ancestor(
      of: find.text('Mon'),
      matching: find.byType(Row),
    ).first;
    final mondayPlus = find.descendant(of: mondayRow, matching: find.text('+'));
    await tester.ensureVisible(mondayPlus);
    await tester.pumpAndSettle();
    await tester.tap(mondayPlus);
    await tester.tap(mondayPlus);
    await tester.tap(mondayPlus);
    await tester.pumpAndSettle();

    expect(find.text('45 m'), findsOneWidget);

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

  testWidgets('Goals: "same every day" applies Monday to every day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW GOAL'));
    await tester.pumpAndSettle();

    final mondayRow = find.ancestor(
      of: find.text('Mon'),
      matching: find.byType(Row),
    ).first;
    final mondayPlus = find.descendant(of: mondayRow, matching: find.text('+'));
    await tester.ensureVisible(mondayPlus);
    await tester.pumpAndSettle();
    // ensureVisible can leave the target sitting right on the viewport
    // edge; nudge the sheet up a bit further so its center clears the edge.
    await tester.dragFrom(const Offset(400, 400), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(mondayPlus);
    await tester.pumpAndSettle(); // Monday now 35m, others still 30m

    await tester.ensureVisible(find.text('same every day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('same every day'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('35 m'), findsNWidgets(7));
  });

  testWidgets('Log activity: saving actually creates a tracked block',
      (WidgetTester tester) async {
    final container = ProviderContainer();
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
      ..setCategory(walkingCategoryId);
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    final selectedDate = container.read(selectedDateProvider);
    container.read(allPlannedBlocksProvider.notifier).addBlock(
          PlannedBlock(
            id: 'test-plan-walk',
            start: DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 21, 0),
            end: DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 22, 30),
            title: 'Evening walk',
            categoryId: walkingCategoryId,
          ),
        );

    final progressList = container.read(goalProgressListProvider);
    final walking = progressList.firstWhere((p) => p.goal.categoryId == walkingCategoryId);
    // The new 1.5h planned block is on top of whatever was already planned.
    expect(walking.plannedHours, greaterThanOrEqualTo(1.5));

    await tester.tap(find.text('GOALS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('planned'), findsWidgets);
  });

  testWidgets('Categories: creating one makes it available as a chip',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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

    await tester.tap(find.text('+ LOG'));
    await tester.pumpAndSettle();

    expect(find.text('reading'), findsOneWidget); // now selectable as a chip
  });

  testWidgets(
      'Goals: a date-bound goal only appears in its window',
      (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CalendarTrackerApp()),
    );
    await tester.pumpAndSettle();

    final selectedDate = container.read(selectedDateProvider);
    container.read(goalsProvider.notifier).addGoal(
          Goal(
            id: 'test-challenge',
            name: 'Next month challenge',
            categoryId: walkingCategoryId,
            type: GoalType.target,
            targetsByWeekday: {
              for (var weekday = 1; weekday <= 7; weekday++) weekday: const Duration(minutes: 30),
            },
            startDate: selectedDate.add(const Duration(days: 30)),
            endDate: selectedDate.add(const Duration(days: 60)),
          ),
        );

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
}
