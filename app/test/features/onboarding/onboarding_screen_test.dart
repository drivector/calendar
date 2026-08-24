import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/data/onboarding_categories.dart';
import 'package:calendar_tracker/features/goals/widgets/goal_edit_sheet.dart';
import 'package:calendar_tracker/features/onboarding/onboarding_screen.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/shared/widgets/category_chip.dart';
import 'package:calendar_tracker/shell/root_shell.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/categories_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';

Future<List<Override>> _signedInEmptyOverrides(String uid) async {
  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: '$uid@example.com'),
      ),
    ),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
  ];
}

void main() {
  testWidgets(
    'OnboardingScreen: seeds every predefined category and shows each with its description',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInEmptyOverrides('onboard-seed'),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      for (final category in onboardingCategories) {
        expect(find.text(category.name), findsOneWidget);
        final description = onboardingCategoryDescriptions[category.id];
        expect(description, isNotNull);
        expect(find.text(description!), findsOneWidget);
      }

      final categories = container.read(categoriesProvider);
      expect(categories, hasLength(onboardingCategories.length));
      expect(
        categories.map((c) => c.name),
        containsAll(onboardingCategories.map((c) => c.name)),
      );
    },
  );

  testWidgets(
    'OnboardingScreen: tapping a category opens a goal sheet pre-scoped to it',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _signedInEmptyOverrides('onboard-precat'),
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();

      expect(find.byType(GoalEditSheet), findsOneWidget);
      final exerciseChip = tester.widget<CategoryChip>(
        find.descendant(
          of: find.byType(GoalEditSheet),
          matching: find.widgetWithText(CategoryChip, 'exercise'),
        ),
      );
      expect(exerciseChip.selected, isTrue);
    },
  );

  testWidgets(
    'OnboardingScreen: creating a goal switches straight into the app',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: await _signedInEmptyOverrides('onboard-create'),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();

      final nameField = find.descendant(
        of: find.byType(GoalEditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Running');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('CREATE GOAL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREATE GOAL'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RootShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      final goals = container.read(goalsProvider);
      expect(goals, hasLength(1));
      expect(goals.single.name, 'Running');
      expect(goals.single.categoryId, 'onboarding-exercise');
    },
  );

  testWidgets(
    "OnboardingScreen: doesn't resurrect a category the user already removed",
    (WidgetTester tester) async {
      const uid = 'onboard-existing-cat';
      final firestore = FakeFirebaseFirestore();
      const customCategory = Category(
        id: 'custom-1',
        name: 'Custom',
        color: Color(0xFF000000),
      );
      await firestore
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(customCategory.id)
          .set(customCategory.toMap());

      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: uid, email: '$uid@example.com'),
            ),
          ),
          firestoreProvider.overrideWithValue(firestore),
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

      // Still onboarding (no goals yet) — but seeding was skipped since a
      // category already existed, so only the pre-existing one is there.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      final categories = container.read(categoriesProvider);
      expect(categories, hasLength(1));
      expect(categories.single.id, 'custom-1');
    },
  );
}
