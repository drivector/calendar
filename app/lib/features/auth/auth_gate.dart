import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/goal.dart';
import '../../shell/root_shell.dart';
import '../../state/auth_providers.dart';
import '../../state/categories_providers.dart';
import '../../state/goal_reminder_providers.dart';
import '../../state/goals_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

/// Root of the app's body — [RootShell] once a user is signed in *and*
/// email-verified (or [OnboardingScreen] first, if they have no goals yet
/// — see [_SignedInGate]; or [_UnverifiedEmailGate] first, if they haven't
/// verified yet), [LoginScreen] otherwise, switching live as
/// [authStateChangesProvider] changes (sign-in, sign-up, and sign-out all
/// land here with no separate navigation step).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        if (!user.emailVerified) return _UnverifiedEmailGate(user: user);
        return const _SignedInGate();
      },
      loading: () =>
          Center(child: Text('loading', style: AppTextStyles.mono())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}

/// Blocks a signed-in-but-unverified account from reaching the app —
/// shown right after sign-up (which sends the verification email but
/// can't wait for the user to actually click it), and for any
/// already-existing account created before this gate existed. Firebase's
/// own [authStateChangesProvider] stream never re-emits just because
/// `emailVerified` flips server-side — the only way to notice a
/// just-clicked verification link is to explicitly reload the user and
/// recheck, which is what "I've verified — continue" does. Holds that
/// result in local state (seeded from [user]'s snapshot at the time this
/// widget was built) rather than trying to force the stream to re-emit.
class _UnverifiedEmailGate extends ConsumerStatefulWidget {
  const _UnverifiedEmailGate({required this.user});

  final User user;

  @override
  ConsumerState<_UnverifiedEmailGate> createState() =>
      _UnverifiedEmailGateState();
}

class _UnverifiedEmailGateState extends ConsumerState<_UnverifiedEmailGate> {
  late bool _verified = widget.user.emailVerified;
  bool _busy = false;
  String? _message;

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.user.sendEmailVerification();
      if (mounted) setState(() => _message = 'Verification email sent.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = "Couldn't send the email. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.user.reload();
      final refreshed = ref.read(firebaseAuthProvider).currentUser;
      // reload() updates the local User's profile fields (emailVerified
      // included) but NOT the cached ID token's claims — Firestore's
      // security rules check the token's own `email_verified` claim, not
      // this profile flag. Without forcing a fresh token here, a user who
      // just verified would pass this local check and reach RootShell,
      // then immediately hit permission-denied on its first Firestore read
      // until the SDK happened to refresh the token on its own.
      await refreshed?.getIdToken(true);
      if (mounted) {
        setState(() {
          _verified = refreshed?.emailVerified ?? false;
          if (!_verified) _message = 'Still not verified — check your email.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signOut() => ref.read(firebaseAuthProvider).signOut();

  @override
  Widget build(BuildContext context) {
    if (_verified) return const _SignedInGate();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify your email', style: AppTextStyles.title()),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'We sent a link to ${widget.user.email}. Open it, then come '
            'back here.',
            style: AppTextStyles.mono(),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(_message!, style: AppTextStyles.mono(color: AppColors.text)),
          ],
          const SizedBox(height: AppSpacing.s6),
          GestureDetector(
            onTap: _busy ? null : _checkVerified,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: AppShapes.small,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              child: Text(
                _busy ? 'Please wait' : "I've verified — continue",
                style: AppTextStyles.small(color: AppColors.surface),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          GestureDetector(
            onTap: _busy ? null : _resend,
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              child: Text(
                'resend verification email',
                style: AppTextStyles.mono(),
              ),
            ),
          ),
          GestureDetector(
            onTap: _busy ? null : _signOut,
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              child: Text('sign out', style: AppTextStyles.mono()),
            ),
          ),
        ],
      ),
    );
  }
}

/// [OnboardingScreen] while a signed-in account still has zero goals,
/// [RootShell] otherwise — a brand-new account (first login after sign-up)
/// starts with no goals, same signal the rest of the app already uses for
/// "this is a fresh account." Waits for both streams' first snapshot
/// before deciding, so a *returning* user with real goals never flashes
/// onboarding while Firestore is still loading.
///
/// Also owns keeping goal reminders in sync with the live goals list: inits
/// the notification plugin once and resyncs scheduled reminders on every
/// goals change. Failures here (no platform channel — e.g. in widget
/// tests — or the user declining permission) are swallowed: reminders are
/// a nice-to-have layered on top of the app, never worth crashing over.
class _SignedInGate extends ConsumerStatefulWidget {
  const _SignedInGate();

  @override
  ConsumerState<_SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends ConsumerState<_SignedInGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final service = ref.read(goalReminderServiceProvider);
        await service.init();
        await service.requestPermissions();
      } catch (_) {
        // No-op — see class doc.
      }
    });
    // listenManual (not listen-in-build) so this registers exactly once for
    // the widget's whole lifetime, with fireImmediately picking up whatever
    // goals are already loaded rather than waiting for the next change.
    ref.listenManual<AsyncValue<List<Goal>>>(goalsStreamProvider, (
      previous,
      next,
    ) {
      final goals = next.valueOrNull;
      if (goals == null) return;
      unawaited(
        ref.read(goalReminderServiceProvider).resync(goals).catchError((_) {}),
      );
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    if (!goalsAsync.hasValue || !categoriesAsync.hasValue) {
      return Center(child: Text('loading', style: AppTextStyles.mono()));
    }

    return goalsAsync.value!.isEmpty
        ? const OnboardingScreen()
        : const RootShell();
  }
}
