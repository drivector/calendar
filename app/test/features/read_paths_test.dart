import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/features/day_view/widgets/plan_block_widget.dart';
import 'package:calendar_tracker/shared/widgets/inline_form_error.dart';
import 'package:calendar_tracker/state/categories_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/shell/root_shell.dart';
import 'package:calendar_tracker/state/goals_providers.dart';

import '../support/firestore_test_fixtures.dart';
import '../support/repository_doubles.dart';

/// The read half of "my activities didn't appear".
///
/// Every list provider in this app turns a failed read into an empty list
/// (`valueOrNull ?? []`), so the two failures below both used to render as
/// a perfectly calm, completely empty account:
///
///  * one document `fromMap` can't parse — a block written before the
///    goal-ownership refactor, say — errored the *whole* stream, taking
///    every readable document with it;
///  * a genuine permission-denied on a collection looked exactly like
///    having nothing in it yet.
///
/// Nothing in the suite covered either, because `FakeFirebaseFirestore`
/// only ever hands back documents the tests themselves wrote.
void main() {
  /// A planned block as it was written before every activity became
  /// goal-owned: a `categoryId`, and no `goalId` for [PlannedBlock.fromMap]
  /// to cast.
  Map<String, dynamic> preRefactorBlock() => {
    'start': DateTime(2026, 8, 20, 11).toIso8601String(),
    'end': DateTime(2026, 8, 20, 12).toIso8601String(),
    'title': 'Written before the refactor',
    'categoryId': 'cat-1',
  };

  group('one unreadable document', () {
    testWidgets(
      "doesn't take the rest of its collection with it, on screen or in "
      'the providers',
      (WidgetTester tester) async {
        final account = await onboardedEmptyAccount();
        final blocks = account.firestore
            .collection('users')
            .doc(account.uid)
            .collection('plannedBlocks');
        await blocks.doc('readable').set({
          'start': DateTime(2026, 8, 20, 9).toIso8601String(),
          'end': DateTime(2026, 8, 20, 10).toIso8601String(),
          'title': 'Readable',
          'goalId': 'goal-1',
        });
        await blocks.doc('legacy').set(preRefactorBlock());

        final container = ProviderContainer(overrides: account.overrides);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const CalendarTrackerApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final planned = container.read(allPlannedBlocksProvider);
        expect(planned, hasLength(1));
        expect(planned.single.id, 'readable');
        expect(
          find.byWidgetPredicate(
            (w) => w is PlanBlockWidget && w.block.title == 'Readable',
          ),
          findsOneWidget,
        );
        // Skipping one row is not the same as the read having failed —
        // the banner is for a collection that genuinely can't be read.
        expect(find.text(kLoadFailedMessage), findsNothing);
      },
    );

    testWidgets('in the goals collection leaves the other goals usable', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await account.firestore
          .collection('users')
          .doc(account.uid)
          .collection('goals')
          .doc('goal-broken')
          .set({'name': 'Half a goal'}); // No categoryId, dates or schedule.

      final container = ProviderContainer(overrides: account.overrides);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // A goals list wiped out by one bad row would also take onboarding
      // with it — AuthGate shows onboarding for an account with no goals,
      // so this is the difference between using the app and being sent
      // back to set it up again.
      final goals = container.read(goalsProvider);
      expect(goals, hasLength(1));
      expect(goals.single.id, 'goal-1');
      expect(find.text('Welcome to Track My Day'), findsNothing);
    });

    testWidgets('in the categories collection leaves the others readable', (
      WidgetTester tester,
    ) async {
      final account = await onboardedEmptyAccount();
      await account.firestore
          .collection('users')
          .doc(account.uid)
          .collection('categories')
          .doc('cat-broken')
          .set({'name': 'No colour'}); // color is a required int.

      final container = ProviderContainer(overrides: account.overrides);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final categories = container.read(categoriesProvider);
      expect(categories, hasLength(1));
      expect(categories.single.id, 'cat-1');
    });
  });

  group('a read that fails', () {
    testWidgets('says so instead of showing an empty account', (
      WidgetTester tester,
    ) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, unreadableTrackedBlocks],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(kLoadFailedMessage), findsOneWidget);
    });

    testWidgets('is called out on every tab, not just the one that reads it', (
      WidgetTester tester,
    ) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...account.overrides, unreadableGoals],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kLoadFailedMessage), findsOneWidget);
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(kLoadFailedMessage), findsOneWidget);
    });

    testWidgets(
      "doesn't strand the app on 'loading', or send a full account back "
      'to onboarding',
      (WidgetTester tester) async {
        final account = await seededAccount();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [...account.overrides, unreadableGoals],
            child: const CalendarTrackerApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // An errored stream never produces a value, so the gate's
        // "still loading" check used to hold here forever; and every
        // provider reading `valueOrNull ?? []` made a full account look
        // like one with no goals, which is the onboarding screen.
        expect(find.text('loading'), findsNothing);
        expect(find.text('Welcome to Track My Day'), findsNothing);
        expect(find.byType(RootShell), findsOneWidget);
      },
    );

    testWidgets('is not claimed when every read is fine', (
      WidgetTester tester,
    ) async {
      final account = await seededAccount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: account.overrides,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kLoadFailedMessage), findsNothing);
    });
  });
}
