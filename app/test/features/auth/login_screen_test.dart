import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/features/onboarding/onboarding_screen.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/shell/root_shell.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';

void main() {
  testWidgets('AuthGate shows the login screen when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(signedIn: false),
          ),
        ],
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.byType(RootShell), findsNothing);
  });

  testWidgets(
    'AuthGate shows onboarding, not the app, for a brand-new account with no goals yet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(RootShell), findsNothing);
      expect(find.text('SIGN IN'), findsNothing);
    },
  );

  testWidgets(
    'AuthGate goes straight to the app, skipping onboarding, once the account has a goal',
    (WidgetTester tester) async {
      const uid = 'u2';
      final firestore = FakeFirebaseFirestore();
      final userDoc = firestore.collection('users').doc(uid);
      const category = Category(
        id: 'cat-1',
        name: 'Work',
        color: Color(0xFF0278E7),
      );
      final goal = Goal(
        id: 'goal-1',
        name: 'Deep work',
        categoryId: category.id,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2099, 12, 31),
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
        },
      );
      await userDoc
          .collection('categories')
          .doc(category.id)
          .set(category.toMap());
      await userDoc.collection('goals').doc(goal.id).set(goal.toMap());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
            ),
            firestoreProvider.overrideWithValue(firestore),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RootShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets('Login: submitting with empty fields shows a validation error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(signedIn: false),
          ),
        ],
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an email and password.'), findsOneWidget);
  });

  testWidgets('Login: toggling to create account swaps the button label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(signedIn: false),
          ),
        ],
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("don't have an account? create one"));
    await tester.pumpAndSettle();

    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('already have an account? sign in'), findsOneWidget);
  });

  testWidgets('Login: a wrong-password error shows a friendly message', (
    WidgetTester tester,
  ) async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(mockAuth)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'me@example.com');
    await tester.enterText(find.byType(TextField).last, 'wrongpassword');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets(
    'Login: a successful sign-in for a brand-new account reaches onboarding',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(signedIn: false),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'me@example.com');
      await tester.enterText(find.byType(TextField).last, 'correcthorse');
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      // A first sign-in has no goals yet, so it lands on onboarding, not
      // straight into the app — same as the very first login after sign-up.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(RootShell), findsNothing);
    },
  );
}
