import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/account_screen.dart';
import '../features/account/capacity_screen.dart';
import '../features/day_view/day_view_screen.dart';
import '../features/goals/goals_screen.dart';
import '../shared/widgets/app_tab_bar.dart';
import '../shared/widgets/inline_form_error.dart';
import '../state/derived_providers.dart';
import '../state/root_shell_providers.dart';
import '../theme/app_spacing.dart';

const _tabs = [
  AppTabBarItem('Calendar'),
  AppTabBarItem('Goals'),
  AppTabBarItem('Planning'),
  AppTabBarItem('Account'),
];

const _screens = [
  DayViewScreen(),
  GoalsScreen(),
  CapacityScreen(),
  AccountScreen(),
];

/// Hosts the 3 tabs behind an [IndexedStack] (not route push) so each
/// screen's scroll position and form state survive tab switches.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);

    return Column(
      children: [
        // Above every tab, not inside one: a failed read affects whatever
        // the user happens to be looking at, and the Calendar tab showing
        // nothing is exactly as misleading as the Goals tab showing
        // nothing.
        if (ref.watch(firestoreReadFailedProvider))
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s3,
              AppSpacing.s3,
              AppSpacing.s3,
              0,
            ),
            child: InlineFormError(kLoadFailedMessage),
          ),
        Expanded(
          child: IndexedStack(index: currentIndex, children: _screens),
        ),
        AppTabBar(
          items: _tabs,
          currentIndex: currentIndex,
          onChanged: (index) =>
              ref.read(currentTabIndexProvider.notifier).state = index,
        ),
      ],
    );
  }
}
