import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/root_shell.dart';
import '../../state/auth_providers.dart';
import '../../state/categories_providers.dart';
import '../../state/goals_providers.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

/// Root of the app's body — [RootShell] once a user is signed in (or
/// [OnboardingScreen] first, if they have no goals yet — see
/// [_SignedInGate]), [LoginScreen] otherwise, switching live as
/// [authStateChangesProvider] changes (sign-in, sign-up, and sign-out all
/// land here with no separate navigation step).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) =>
          user == null ? const LoginScreen() : const _SignedInGate(),
      loading: () =>
          Center(child: Text('loading', style: AppTextStyles.mono())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}

/// [OnboardingScreen] while a signed-in account still has zero goals,
/// [RootShell] otherwise — a brand-new account (first login after sign-up)
/// starts with no goals, same signal the rest of the app already uses for
/// "this is a fresh account." Waits for both streams' first snapshot
/// before deciding, so a *returning* user with real goals never flashes
/// onboarding while Firestore is still loading.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
