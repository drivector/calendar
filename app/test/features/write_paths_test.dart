import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
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
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/shared/widgets/app_tab_bar.dart';
import 'package:calendar_tracker/shared/widgets/goal_dropdown.dart';
import 'package:calendar_tracker/shared/widgets/inline_form_error.dart';
import 'package:calendar_tracker/state/categories_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';
import 'package:calendar_tracker/state/log_entry_providers.dart';

import '../support/firestore_test_fixtures.dart';

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

  group('a write that fails is never silent', () {
    testWidgets('Day view: the add-block sheet stays open and says so', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...account.overrides,
            _rejectingTrackedBlocks,
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
        overrides: [...account.overrides, _rejectingTrackedBlocks],
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
          overrides: [...account.overrides, _rejectingGoals],
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
          overrides: [...account.overrides, _rejectingCategories],
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

/// A repository whose reads work normally but whose writes are rejected —
/// what a permission-denied from Firestore's rules looks like to the app.
/// `DocumentReference` is sealed in `cloud_firestore`, so a rejected write
/// can't be faked at the Firestore level; overriding the repository
/// provider is the seam this app already uses for the same purpose (see
/// `saveUserSettingsProvider`).
class _RejectingRepository<T> extends FirestoreListRepository<T> {
  _RejectingRepository({
    required super.firestore,
    required super.uid,
    required super.collectionName,
    required super.fromMap,
    required super.toMap,
    required super.idOf,
  });

  @override
  Future<void> upsert(T item) => Future.error(
    FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'The caller does not have permission.',
    ),
  );
}

final _rejectingTrackedBlocks = trackedBlocksRepositoryProvider.overrideWith(
  (ref) => _RejectingRepository<TrackedBlock>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'trackedBlocks',
    fromMap: TrackedBlock.fromMap,
    toMap: (block) => block.toMap(),
    idOf: (block) => block.id,
  ),
);

final _rejectingGoals = goalsRepositoryProvider.overrideWith(
  (ref) => _RejectingRepository<Goal>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'goals',
    fromMap: Goal.fromMap,
    toMap: (goal) => goal.toMap(),
    idOf: (goal) => goal.id,
  ),
);

final _rejectingCategories = categoriesRepositoryProvider.overrideWith(
  (ref) => _RejectingRepository<Category>(
    firestore: ref.watch(firestoreProvider),
    uid: ref.watch(currentUidProvider),
    collectionName: 'categories',
    fromMap: Category.fromMap,
    toMap: (category) => category.toMap(),
    idOf: (category) => category.id,
  ),
);

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
