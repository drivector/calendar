import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

String _messageFor(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address looks wrong.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email or password is incorrect.';
    case 'email-already-in-use':
      // Reachable via an ordinary duplicate sign-up, but *also* after a
      // sign-up that errored **after** Firebase had already created the
      // account server-side (see `keychain-error` below) — so point at
      // the recovery path instead of just stating the fact.
      return 'An account already exists for that email — sign in instead.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'keychain-error':
      // Firebase creates the account server-side *before* persisting the
      // session, so this error does NOT mean sign-up didn't happen —
      // saying otherwise sends people into a retry loop that then fails
      // with 'email-already-in-use'.
      return "Your account may have been created, but the session couldn't "
          "be saved to the keychain — try signing in. (macOS only: this "
          "build isn't code-signed with a development team; see "
          'HANDOFF.md.)';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/// Deliberately has no `user-not-found` case: Firebase's email enumeration
/// protection (on by default) makes `sendPasswordResetEmail` *succeed* for
/// an unregistered address rather than reveal that it isn't registered —
/// verified live against this project. A malformed address still errors,
/// so `invalid-email` is real and stays.
String _resetMessageFor(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address looks wrong.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/// Email/password sign-in and sign-up, in one screen with a toggle between
/// the two modes — shown by [AuthGate] whenever there's no signed-in user.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _submitting = false;
  String? _error;
  // Neutral confirmation text (e.g. "reset email sent") — kept separate
  // from _error so the two never fight over the same styling/meaning.
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Enter an email and password.';
        _message = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });

    final auth = ref.read(firebaseAuthProvider);
    try {
      if (_isSignUp) {
        // No sendEmailVerification() call here — AuthGate's own
        // _UnverifiedEmailGate sends it once, the moment it first mounts,
        // covering both this path and an existing unverified account
        // simply signing back in (which never used to send anything at
        // all — a real bug: signing in reached a gate claiming "we sent a
        // link" when nothing had been sent).
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e.code));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Enter your email first.';
        _message = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });

    final auth = ref.read(firebaseAuthProvider);
    try {
      await auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        // Phrased conditionally on purpose. Firebase succeeds here even for
        // an unregistered address (enumeration protection), so a flat
        // "email sent" would be a lie in that case — and spelling out
        // which it was would defeat the protection.
        setState(
          () => _message =
              'If an account exists for that email, a reset link is on '
              'its way.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _resetMessageFor(e.code));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track My Day', style: AppTextStyles.title()),
          const SizedBox(height: AppSpacing.s1),
          Text(
            _isSignUp ? 'create an account' : 'sign in to continue',
            style: AppTextStyles.mono(),
          ),
          const SizedBox(height: AppSpacing.s6),
          _FieldLabel('Email'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: AppTextStyles.label(),
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: AppSpacing.s4),
          _FieldLabel('Password'),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: AppTextStyles.label(),
            decoration: const InputDecoration(isDense: true),
            onSubmitted: (_) => _submit(),
          ),
          if (!_isSignUp)
            GestureDetector(
              onTap: _submitting ? null : _sendPasswordReset,
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: Text('forgot password?', style: AppTextStyles.mono()),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(_error!, style: AppTextStyles.mono(color: AppColors.accent)),
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(_message!, style: AppTextStyles.mono(color: AppColors.text)),
          ],
          const SizedBox(height: AppSpacing.s6),
          GestureDetector(
            onTap: _submitting ? null : _submit,
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
                _submitting
                    ? 'Please wait'
                    : (_isSignUp ? 'Create account' : 'Sign in'),
                style: AppTextStyles.small(color: AppColors.surface),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          GestureDetector(
            onTap: _submitting
                ? null
                : () => setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                    _message = null;
                  }),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              child: Text(
                _isSignUp
                    ? 'already have an account? sign in'
                    : "don't have an account? create one",
                style: AppTextStyles.mono(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text.toUpperCase(), style: AppTextStyles.kicker()),
    );
  }
}
