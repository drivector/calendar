import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/firestore/firestore_list_repository.dart';
import 'package:calendar_tracker/features/day_view/widgets/actual_block_widget.dart';
import 'package:calendar_tracker/features/day_view/widgets/plan_block_widget.dart';
import 'package:calendar_tracker/features/day_view/widgets/start_activity_sheet.dart';
import 'package:calendar_tracker/features/day_view/widgets/time_body_grid.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/shared/widgets/app_tab_bar.dart';
import 'package:calendar_tracker/shared/widgets/goal_dropdown.dart';
import 'package:calendar_tracker/shared/widgets/inline_form_error.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/log_entry_providers.dart';

import '../support/firestore_test_fixtures.dart';
import '../support/repository_doubles.dart';

/// Two halves of the same bug, one file.
///
/// "I added an activity and it never appeared" had two causes working
/// together: the document the app wrote no longer matched what
/// `firestore.rules` validated (so production rejected every write), and
/// every save path fired its write without awaiting it (so the rejection
/// was invisible — the sheet closed exactly as it does on success). The
/// suite missed both, because it asserts against `FakeFirebaseFirestore`,
/// which accepts any document and never fails a write.
///
/// So the first group drives each real save flow and then checks the *raw
/// document it wrote* against the deployed rules, and the second makes
/// each save flow fail and checks the user is actually told.
void main() {
  group('a save flow writes documents the deployed rules would accept', () {
    testWidgets('Day view: an actual activity added by tapping an empty slot', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: account.overrides,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();
      expect(find.text('New actual activity'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Deep work');
      await _pickGoal(tester, ancestor: find.byType(BottomSheet));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final written = await account.docsIn('trackedBlocks');
      expect(written, hasLength(1));
      expect(written.values.single['title'], 'Deep work');
      expect(written.values.single['goalId'], 'goal-1');
      account.expectWritesWouldBeAccepted();

      // The other half of "it didn't appear": accepted by the rules, and
      // actually drawn on the day it was added to.
      expect(
        find.byWidgetPredicate(
          (w) => w is ActualBlockWidget && w.block.title == 'Deep work',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Day view: a planned activity added on a future date', (
      WidgetTester tester,
    ) async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...account.overrides,
            selectedDateProvider.overrideWith((ref) => futureDate),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();
      expect(find.text('New planned activity'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Review');
      await _pickGoal(tester, ancestor: find.byType(BottomSheet));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final written = await account.docsIn('plannedBlocks');
      expect(written, hasLength(1));
      expect(written.values.single['title'], 'Review');
      account.expectWritesWouldBeAccepted();
      expect(
        find.byWidgetPredicate(
          (w) => w is PlanBlockWidget && w.block.title == 'Review',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Log activity: an entry saved from the sheet', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      final container = ProviderContainer(overrides: account.overrides);
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
        ..setGoal('goal-1');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save entry'));
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final written = await account.docsIn('trackedBlocks');
      expect(written, hasLength(1));
      expect(written.values.single['sourceId'], 'manual');
      account.expectWritesWouldBeAccepted();
      expect(find.text('30m · Evening walk'), findsOneWidget);
    });

    testWidgets('Goals: a goal created in the new-goal wizard', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: account.overrides,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // Step 1: category, one already picked.
      await tester.enterText(
        find.descendant(
          of: find.byType(GoalEditSheet),
          matching: find.byType(TextField),
        ),
        'Reading',
      );
      await tester.pumpAndSettle();
      await _goalSheetNext(tester); // Step 2: name & dates.
      await tester.ensureVisible(find.text('Next'));
      await _goalSheetNext(tester); // Step 3: schedule, defaults are fine.
      await tester.ensureVisible(find.text('Create goal'));
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final written = await account.docsIn('goals');
      expect(written, hasLength(2)); // The fixture's goal, plus this one.
      account.expectWritesWouldBeAccepted();
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('Categories: a category renamed on the categories screen', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: account.overrides,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Deep work');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final written = await account.docsIn('categories');
      expect(written['cat-1']!['name'], 'Deep work');
      account.expectWritesWouldBeAccepted();
    });

    testWidgets(
      'Live activity: the running-state doc, and the block Stop registers',
      (WidgetTester tester) async {
        final account = await seededAccount();
        await tester.pumpWidget(
          ProviderScope(
            overrides: account.overrides,
            child: const CalendarTrackerApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('▶ Start'));
        await tester.pumpAndSettle();
        await _pickGoal(
          tester,
          ancestor: find.byType(StartActivitySheet),
          goalName: 'Walking',
        );
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();

        // `state/runningActivity` is the collection whose rule was missing
        // entirely once, which read as "Start does nothing".
        final running = await account.docsIn('state');
        expect(running.keys, contains('runningActivity'));
        account.expectWritesWouldBeAccepted();

        final trackedBefore = (await account.docsIn('trackedBlocks')).length;
        await tester.tap(find.textContaining('Stop'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(await account.docsIn('state'), isEmpty);
        expect((await account.docsIn('trackedBlocks')).length, trackedBefore + 1);
        account.expectWritesWouldBeAccepted();
      },
    );

    testWidgets('Account: the tracking window', (WidgetTester tester) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: account.overrides,
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
      expect(await account.docsIn('settings'), isNotEmpty);
      account.expectWritesWouldBeAccepted();
    });
  });

  testWidgets(
    'Day view: a pasted over-length title is cut to what the rules accept, '
    'not sent as a write that can only be rejected',
    (WidgetTester tester) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: account.overrides,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'x' * (kMaxFieldLength + 200),
      );
      await _pickGoal(tester, ancestor: find.byType(BottomSheet));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final written = await account.docsIn('trackedBlocks');
      expect((written.values.single['title'] as String).length,
          kMaxFieldLength);
      account.expectWritesWouldBeAccepted();
    },
  );

  group('a delete that fails is never silent', () {
    // Same hole the saves had: unawaited (or uncaught), so the sheet
    // closed, the thing was still there, and nothing said why — which
    // reads as the delete not having registered at all.
    testWidgets('Day view: the edit-plan sheet keeps the plan and says so', (
      WidgetTester tester,
    ) async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final account = await onboardedEmptyAccount();
      await account.firestore
          .collection('users')
          .doc(account.uid)
          .collection('plannedBlocks')
          .doc('plan-future')
          .set({
            'start': DateTime(
              futureDate.year,
              futureDate.month,
              futureDate.day,
              12,
            ).toIso8601String(),
            'end': DateTime(
              futureDate.year,
              futureDate.month,
              futureDate.day,
              13,
            ).toIso8601String(),
            'title': 'Future sync',
            'goalId': 'goal-1',
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...account.overrides,
            selectedDateProvider.overrideWith((ref) => futureDate),
            rejectingPlannedBlocks,
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final planBlock = find.byWidgetPredicate(
        (w) => w is PlanBlockWidget && w.block.id == 'plan-future',
      );
      await tester.ensureVisible(planBlock);
      await tester.tap(planBlock);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete planned activity'));
      await tester.tap(find.text('Delete planned activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit planned activity'), findsOneWidget);
      expect(find.text(kDeleteFailedMessage), findsOneWidget);
      expect((await account.docsIn('plannedBlocks')).keys, ['plan-future']);
    });

    testWidgets('Categories: the category sheet keeps it and says so', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, rejectingCategories],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(kDeleteFailedMessage), findsOneWidget);
      expect((await account.docsIn('categories')).keys, ['cat-1']);
    });

    testWidgets('Goals: the edit sheet keeps the goal and says so', (
      WidgetTester tester,
    ) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, rejectingGoals],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete goal'));
      await tester.tap(find.text('Delete goal'));
      await tester.pumpAndSettle();
      // Walking has linked activity in this fixture, so it deactivates
      // rather than hard-deletes — the write that fails here is the
      // status upsert, not a remove.
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit goal'), findsOneWidget);
      expect(find.text(kDeleteFailedMessage), findsOneWidget);
    });

    testWidgets('Log activity: the edit sheet keeps the entry and says so', (
      WidgetTester tester,
    ) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, rejectingTrackedBlocks],
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
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Delete activity'), findsOneWidget); // Still open.
      expect(find.text(kDeleteFailedMessage), findsOneWidget);
    });

    testWidgets(
      "Day view: the block's own detail dialog closes, then says why the "
      'block is still there',
      (WidgetTester tester) async {
        final account = await seededAccount();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [...account.overrides, rejectingTrackedBlocks],
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
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The dialog is its own route, so a SnackBar underneath it would
        // be invisible — it closes first, then explains.
        expect(find.text('Thu, 20 Aug 2026'), findsNothing);
        expect(find.text(kDeleteFailedMessage), findsOneWidget);
        expect(actual, findsOneWidget);
      },
    );

    testWidgets('Activities: the list says so rather than leaving the row', (
      WidgetTester tester,
    ) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, rejectingTrackedBlocks],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Account');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('actual-walk'));
      await tester.ensureVisible(row);
      await tester.tap(find.descendant(of: row, matching: find.text('delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // A tab screen, not a sheet, so this one can use a SnackBar.
      expect(find.text(kDeleteFailedMessage), findsOneWidget);
      // And the row it couldn't delete is still there, rather than
      // disappearing optimistically.
      expect(find.text('Walk 48 m'), findsOneWidget);
    });
  });

  group('a write that fails is never silent', () {
    testWidgets('Day view: the add-block sheet stays open and says so', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...account.overrides,
            rejectingTrackedBlocks,
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(TimeBodyGrid)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Deep work');
      await _pickGoal(tester, ancestor: find.byType(BottomSheet));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Still open, still holding the entry — a closed sheet with nothing
      // written is exactly what the shipped bug looked like.
      expect(find.text('New actual activity'), findsOneWidget);
      expect(find.text(kSaveFailedMessage), findsOneWidget);
      expect(await account.docsIn('trackedBlocks'), isEmpty);
    });

    testWidgets('Log activity: the sheet stays open and says so', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      final container = ProviderContainer(
        overrides: [...account.overrides, rejectingTrackedBlocks],
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
        ..setGoal('goal-1');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save entry'));
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save entry'), findsOneWidget);
      expect(find.text(kSaveFailedMessage), findsOneWidget);
      expect(await account.docsIn('trackedBlocks'), isEmpty);
      // The draft survives, so a retry doesn't start from a blank form.
      expect(find.text('Evening walk'), findsWidgets);
    });

    testWidgets('Goals: the new-goal wizard stays open and says so', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, rejectingGoals],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('+ New goal'));
      await tester.pumpAndSettle();
      await _goalSheetNext(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(GoalEditSheet),
          matching: find.byType(TextField),
        ),
        'Reading',
      );
      await tester.pumpAndSettle();
      await _goalSheetNext(tester);
      await tester.ensureVisible(find.text('Next'));
      await _goalSheetNext(tester);
      await tester.ensureVisible(find.text('Create goal'));
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Create goal'), findsOneWidget);
      expect(find.text(kSaveFailedMessage), findsOneWidget);
      expect(await account.docsIn('goals'), hasLength(1)); // Only the fixture.
    });

    testWidgets('Categories: the category sheet stays open and says so', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, rejectingCategories],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Goals');
      await tester.tap(find.text('categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Errands');
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(kSaveFailedMessage), findsOneWidget);
      expect((await account.docsIn('categories')).keys, ['cat-1']);
    });
  });
}

/// Picks a goal from the [GoalDropdown] inside [ancestor] — the dropdown's
/// menu opens in its own overlay route, so the row to tap is not a
/// descendant of the sheet the dropdown itself sits in. Scoping matters
/// either way: a goal's name also renders behind the sheet, in the drift
/// footer's own per-goal rows.
Future<void> _pickGoal(
  WidgetTester tester, {
  required Finder ancestor,
  String goalName = 'Test goal',
}) async {
  await tester.tap(
    find.descendant(of: ancestor, matching: find.byType(GoalDropdown)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(goalName).last);
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppTabBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> _goalSheetNext(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}
