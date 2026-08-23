import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_providers.dart';
import '../../theme/app_colors.dart';
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
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
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
      setState(() => _error = 'Enter an email and password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = ref.read(firebaseAuthProvider);
    try {
      if (_isSignUp) {
        await auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e.code));
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
          Text('Calendar Tracker', style: AppTextStyles.title()),
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
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(_error!, style: AppTextStyles.mono(color: AppColors.accent)),
          ],
          const SizedBox(height: AppSpacing.s6),
          GestureDetector(
            onTap: _submitting ? null : _submit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              color: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              child: Text(
                _submitting
                    ? 'PLEASE WAIT'
                    : (_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN'),
                style: AppTextStyles.small(color: AppColors.bg),
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
