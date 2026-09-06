// Deliberately-failing tests, one per known defect found in the
// 2026-09-07 data-model audit (see HANDOFF.md). Each asserts the
// behaviour the app *should* have; each currently fails, and the failure
// message names the bug. They are red on purpose — delete or invert the
// assertion only when the underlying defect is actually fixed.
//
// "An overnight block is counted twice in multi-day totals" (the first
// defect from that audit) has since been fixed and moved to
// test/state/derived_providers_test.dart as a regular passing assertion.
// "The Capacity page loses the far side of an overnight block" (the
// second) has likewise been fixed and moved to
// test/state/week_view_providers_test.dart.
//
// Two items from that audit are deliberately absent, because neither is
// expressible as a behavioural assertion:
//
//   * `Goal.weeklyTargetHours` is misnamed (it returns the whole-span
//     total for a byDate goal, not a weekly figure). Its *behaviour* is
//     correct and already covered; only the name is wrong, and a test
//     cannot fail on a name.
//   * `AppTextStyles.mono()` no longer means monospace, only "secondary
//     annotation text". Same category — the rendering is intended, the
//     name is the debt.
//
// A test asserting either would have to assert current, correct
// behaviour, which would pass and prove nothing.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_block.dart';
import 'package:calendar_tracker/shared/widgets/quick_log_check_button.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';

import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';

import 'support/firestore_test_fixtures.dart';
import 'support/repository_doubles.dart';

Goal _goal() => Goal(
  id: 'goal-1',
  name: 'Test goal',
  categoryId: 'cat-1',
  startDate: DateTime(2020, 1, 1),
  endDate: DateTime(2099, 12, 31),
  scheduleByWeekday: {
    for (var weekday = 1; weekday <= 7; weekday++)
      weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
  },
);

void main() {
  group('DEFECT: a rejected write closes the UI as if it had worked', () {
    testWidgets(
      "the unscheduled dialog's quick-log checkmark reports a failed write",
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            ...await _onboardedNoActivityOverrides(),
            rejectingTrackedBlocks,
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

        await tester.tap(find.text('30m unscheduled ›'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(QuickLogCheckButton),
          ),
        );
        await tester.pumpAndSettle();

        // unscheduled_dialog.dart:140 fires logUnscheduledGoalTime without
        // awaiting or catching, then pops — so the write is rejected, the
        // dialog closes exactly as on success, and nothing is written.
        expect(
          container.read(allTrackedBlocksProvider),
          isEmpty,
          reason: 'precondition: the rejected write really did not land',
        );
        expect(
          find.textContaining("Couldn't save", findRichText: true),
          findsOneWidget,
          reason:
              'A rejected quick-log is silent — the dialog closes and the '
              'totals are unchanged, indistinguishable from success.',
        );
      },
    );

    testWidgets("the goal list's complete button reports a failed write", (
      WidgetTester tester,
    ) async {
      // A plan that has already fully happened, in the week the goal list
      // is showing — otherwise there is nothing to "complete" and the
      // test would fail on its own setup rather than on the defect.
      final container = ProviderContainer(
        overrides: [
          ...await _onboardedNoActivityOverrides(
            selectedDate: DateTime(2026, 9, 2),
            pastPlan: PlannedBlock(
              id: 'plan-past',
              start: DateTime(2026, 9, 1, 9, 0),
              end: DateTime(2026, 9, 1, 10, 0),
              title: 'Already happened',
              goalId: 'goal-1',
            ),
          ),
          rejectingTrackedBlocks,
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
      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();

      final complete = find.byType(CompleteGoalButton);
      expect(
        complete,
        findsWidgets,
        reason: 'precondition: a pending plan to complete',
      );
      await tester.tap(complete.first);
      await tester.pumpAndSettle();

      // goals_screen.dart:168 loops upsert() over several blocks awaiting
      // none of them, so a partial or total failure is invisible.
      expect(
        find.textContaining("Couldn't save", findRichText: true),
        findsOneWidget,
        reason:
            'Completing a goal against a rejecting repository reports '
            'nothing — the button simply appears to do nothing.',
      );
    });

    testWidgets(
      "the Capacity day preview's quick-log checkmark reports a failed write",
      (WidgetTester tester) async {
        const uid = 'defects-seeded-uid';
        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: uid, email: 'defects@example.com'),
              ),
            ),
            firestoreProvider.overrideWithValue(await seededFirestore(uid)),
            selectedDateProvider.overrideWith((ref) => mockDay),
            rejectingTrackedBlocks,
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

        await tester.tap(find.text('Planning'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MON 17'));
        await tester.pumpAndSettle();

        final checkButton = find
            .descendant(
              of: find
                  .ancestor(
                    of: find.descendant(
                      of: find.byType(Dialog),
                      matching: find.text('walking'),
                    ),
                    matching: find.byType(Row),
                  )
                  .first,
              matching: find.byType(QuickLogCheckButton),
            );
        expect(
          checkButton,
          findsOneWidget,
          reason: 'precondition: an unscheduled row to quick-log',
        );

        final before = container
            .read(allTrackedBlocksProvider)
            .where((b) => b.goalId == 'goal-walking')
            .length;

        await tester.ensureVisible(checkButton);
        await tester.pumpAndSettle();
        await tester.tap(checkButton);
        await tester.pumpAndSettle();

        // day_preview_sheet.dart:229 has the same unawaited, uncaught
        // shape as the Day view's own dialog.
        expect(
          container
              .read(allTrackedBlocksProvider)
              .where((b) => b.goalId == 'goal-walking')
              .length,
          before,
          reason: 'precondition: the rejected write really did not land',
        );
        expect(
          find.textContaining("Couldn't save", findRichText: true),
          findsOneWidget,
          reason:
              'A rejected quick-log from the Capacity day preview is '
              'silent — the sheet closes exactly as on success.',
        );
      },
    );
  });
}

/// [pastPlan] seeds a planned block that has already fully happened, in
/// the same week as [selectedDate] — the precondition
/// [pendingPlannedBlocksForGoal] needs before the goal list will render a
/// [CompleteGoalButton] at all.
Future<List<Override>> _onboardedNoActivityOverrides({
  DateTime? selectedDate,
  PlannedBlock? pastPlan,
}) async {
  const uid = 'known-defects-uid';
  final firestore = FakeFirebaseFirestore();
  final userDoc = firestore.collection('users').doc(uid);
  const category = Category(
    id: 'cat-1',
    name: 'Work',
    color: Color(0xFF0278E7),
  );
  final goal = _goal();
  await userDoc.collection('categories').doc(category.id).set(category.toMap());
  await userDoc.collection('goals').doc(goal.id).set(goal.toMap());
  if (pastPlan != null) {
    await userDoc
        .collection('plannedBlocks')
        .doc(pastPlan.id)
        .set(pastPlan.toMap());
  }

  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'defects@example.com'),
      ),
    ),
    firestoreProvider.overrideWithValue(firestore),
    selectedDateProvider.overrideWith(
      (ref) => selectedDate ?? DateTime(2026, 8, 20),
    ),
  ];
}
