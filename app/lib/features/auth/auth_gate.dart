import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/root_shell.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_text_styles.dart';
import 'login_screen.dart';

/// Root of the app's body — [RootShell] once a user is signed in,
/// [LoginScreen] otherwise, switching live as [authStateChangesProvider]
/// changes (sign-in, sign-up, and sign-out all land here with no separate
/// navigation step).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user == null ? const LoginScreen() : const RootShell(),
      loading: () => Center(child: Text('loading', style: AppTextStyles.mono())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
