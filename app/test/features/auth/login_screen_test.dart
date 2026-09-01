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

    expect(find.text('Sign in'), findsOneWidget);
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
      expect(find.text('Sign in'), findsNothing);
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

    await tester.tap(find.text('Sign in'));
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

    expect(find.text('Create account'), findsOneWidget);
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
    await tester.tap(find.text('Sign in'));
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
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // A first sign-in has no goals yet, so it lands on onboarding, not
      // straight into the app — same as the very first login after sign-up.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(RootShell), findsNothing);
    },
  );

  testWidgets(
    "Login: \"forgot password?\" only shows in sign-in mode, not sign-up",
    (WidgetTester tester) async {
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

      expect(find.text('forgot password?'), findsOneWidget);

      await tester.tap(find.text("don't have an account? create one"));
      await tester.pumpAndSettle();

      expect(find.text('forgot password?'), findsNothing);
    },
  );

  testWidgets(
    'Login: tapping "forgot password?" with no email typed asks for one first',
    (WidgetTester tester) async {
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

      await tester.tap(find.text('forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email first.'), findsOneWidget);
    },
  );

  testWidgets(
    'Login: "forgot password?" with an email sends a reset email and confirms it',
    (WidgetTester tester) async {
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

      await tester.enterText(find.byType(TextField).first, 'me@example.com');
      await tester.tap(find.text('forgot password?'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If an account exists for that email, a reset link is on its way.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Login: "forgot password?" for an unregistered email gives the same '
    'neutral answer — Firebase enumeration protection means we never reveal '
    'whether the account exists',
    (WidgetTester tester) async {
      // Not a mocked throw: verified live against the real project that
      // sendPasswordResetEmail *succeeds* for an unregistered address, so
      // the success path is what an unknown email actually hits.
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

      await tester.enterText(
        find.byType(TextField).first,
        'nobody@example.com',
      );
      await tester.tap(find.text('forgot password?'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If an account exists for that email, a reset link is on its way.',
        ),
        findsOneWidget,
      );
      expect(find.text('No account found for that email.'), findsNothing);
    },
  );

  testWidgets(
    'Login: a malformed email on "forgot password?" still gets a real error',
    (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'not-an-email');
      await tester.tap(find.text('forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('That email address looks wrong.'), findsOneWidget);
    },
  );

  testWidgets(
    'Login: a sign-up that errors after the account was created points at '
    'signing in, not a retry loop',
    (WidgetTester tester) async {
      // The real scenario behind this: Firebase creates the account
      // server-side *before* persisting the session, so a post-creation
      // failure (e.g. keychain-error) leaves a real account behind. The
      // obvious retry then hits email-already-in-use — which must guide
      // the user to sign in rather than just restating the problem.
      final mockAuth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("don't have an account? create one"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'me@example.com');
      await tester.enterText(find.byType(TextField).last, 'correcthorse');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('An account already exists for that email — sign in instead.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Login: a keychain-error on sign-up says the account may exist, not that '
    'sign-up failed outright',
    (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'keychain-error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("don't have an account? create one"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'me@example.com');
      await tester.enterText(find.byType(TextField).last, 'correcthorse');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your account may have been created'),
        findsOneWidget,
      );
      expect(find.textContaining('try signing in'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthGate blocks an unverified account from reaching the app',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'u3', isEmailVerified: false),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(RootShell), findsNothing);
    },
  );

  testWidgets(
    'AuthGate: reaching the unverified gate sends a verification email on '
    "its own, without a manual resend — covers signing back in to an "
    'existing unverified account, not just a fresh sign-up',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'u3b', isEmailVerified: false),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // No tap on "resend" — this fires automatically the moment the gate
      // is reached, per _UnverifiedEmailGateState.initState().
      expect(find.text('Verification email sent.'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthGate: "resend verification email" on the unverified gate does not crash',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'u4', isEmailVerified: false),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('resend verification email'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Verification email sent.'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthGate: signing out from the unverified gate returns to the login screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'u5', isEmailVerified: false),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Verify your email'), findsNothing);
    },
  );

  testWidgets(
    'Login: signing up creates an unverified account and lands on the verify gate',
    (WidgetTester tester) async {
      // verifyEmailAutomatically: false matches real Firebase — a brand
      // new account starts unverified, not the mock's convenience default.
      final mockAuth = MockFirebaseAuth(
        signedIn: false,
        verifyEmailAutomatically: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockAuth),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("don't have an account? create one"));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'newbie@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'correcthorse');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(mockAuth.currentUser?.emailVerified, isFalse);
    },
  );

  testWidgets(
    'AuthGate: tapping continue while still genuinely unverified stays on the gate',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'u6', isEmailVerified: false),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("I've verified — continue"));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Still not verified — check your email.'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthGate: once actually verified, continue reaches the app',
    (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u7', isEmailVerified: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockAuth),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const CalendarTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);

      // MockUser.emailVerified is immutable and reload() is a no-op in
      // this mock, so this is how a test expresses "the account actually
      // got verified elsewhere" — swapping in a fresh, verified MockUser
      // for the same uid. This also directly exercises why the real
      // implementation re-reads `firebaseAuthProvider.currentUser` after
      // reload() rather than trusting the User instance it was built
      // with: that stale instance never changes, only the auth's own
      // currentUser does.
      mockAuth.mockUser = MockUser(uid: 'u7', isEmailVerified: true);

      await tester.tap(find.text("I've verified — continue"));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Verify your email'), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );
}
