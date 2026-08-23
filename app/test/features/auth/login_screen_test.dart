import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import 'package:calendar_tracker/app.dart';
import 'package:calendar_tracker/shell/root_shell.dart';
import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';

void main() {
  testWidgets('AuthGate shows the login screen when signed out',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
        ],
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.byType(RootShell), findsNothing);
  });

  testWidgets('AuthGate shows the app when signed in',
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

    expect(find.byType(RootShell), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
  });

  testWidgets('Login: submitting with empty fields shows a validation error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
        ],
        child: const CalendarTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an email and password.'), findsOneWidget);
  });

  testWidgets('Login: toggling to create account swaps the button label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
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

  testWidgets('Login: a wrong-password error shows a friendly message',
      (WidgetTester tester) async {
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

  testWidgets('Login: a successful sign-in reaches the app',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
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

    expect(find.byType(RootShell), findsOneWidget);
  });
}
