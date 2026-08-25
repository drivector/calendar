import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/account_screen.dart';
import '../features/day_view/day_view_screen.dart';
import '../features/goals/goals_screen.dart';
import '../shared/widgets/app_tab_bar.dart';
import '../state/root_shell_providers.dart';

const _tabs = [
  AppTabBarItem('Calendar'),
  AppTabBarItem('Goals'),
  AppTabBarItem('Account'),
];

const _screens = [DayViewScreen(), GoalsScreen(), AccountScreen()];

/// Hosts the 3 tabs behind an [IndexedStack] (not route push) so each
/// screen's scroll position and form state survive tab switches.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);

    return Column(
      children: [
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
