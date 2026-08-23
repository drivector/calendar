import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/features/categories/categories_screen.dart';
import 'package:calendar_tracker/features/day_view/widgets/day_header_bar.dart';
import 'package:calendar_tracker/features/day_view/widgets/time_body_grid.dart';
import 'package:calendar_tracker/features/goals/goals_screen.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_detail_sheet.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/features/log_activity/log_activity_screen.dart';
import 'package:calendar_tracker/features/week_view/week_view_screen.dart';
import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/shared/widgets/step_arrow_button.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';
import 'package:calendar_tracker/state/log_entry_providers.dart';
import 'package:calendar_tracker/state/root_shell_providers.dart';

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

  testWidgets('Goals: a leftward swipe steps to the next tab (+ Log)',
      (WidgetTester tester) async {
    final container = ProviderContainer();
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
    final container = ProviderContainer();
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
    final container = ProviderContainer();
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

  testWidgets(
      "Goals: editing a time-range goal shows its existing per-day ranges, not empty",
      (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

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
    container.read(goalsProvider.notifier).addGoal(workGoal);

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
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
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
      const ProviderScope(child: CalendarTrackerApp()),
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
      'Goals: creating a new goal makes it show up as a planned block in the Day view',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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

    // The new goal is a duration-mode target with no fixed time, so it's
    // scheduled by the same generator as any other duration goal — it
    // should render as a real plan block on today, not vanish.
    expect(
      find.descendant(of: find.byType(TimeBodyGrid), matching: find.text('Piano')),
      findsOneWidget,
    );
  });

  testWidgets(
      "Goals: a duration goal's generated block shows its day and is marked auto-placed",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalendarTrackerApp()),
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
    // Thursday 20 Aug: Walking (06:00-07:00) and Deep work (17:30-21:30,
    // per mock_day_20aug.dart's manual blocks) are placed ahead of it, so
    // Piano lands right after Deep work — both the day and the
    // "auto-placed" marker matter here, since a bare clock range with no
    // day is ambiguous across a 7-day list, and an unmarked auto-placed
    // time reads as a fixed commitment when it isn't one.
    expect(find.text('THU 21:30–22:00 · auto-placed'), findsOneWidget);
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
            scheduleByWeekday: {
              for (var weekday = 1; weekday <= 7; weekday++)
                weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
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
