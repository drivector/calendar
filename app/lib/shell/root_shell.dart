import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/day_view/day_view_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/log_activity/activities_screen.dart';
import '../features/week_view/week_view_screen.dart';
import '../shared/widgets/app_tab_bar.dart';
import '../state/root_shell_providers.dart';

const _tabs = [
  AppTabBarItem('Day'),
  AppTabBarItem('Week'),
  AppTabBarItem('Goals'),
  AppTabBarItem('Activities'),
];

const _screens = [
  DayViewScreen(),
  WeekViewScreen(),
  GoalsScreen(),
  ActivitiesScreen(),
];

/// Hosts the 4 tabs behind an [IndexedStack] (not route push) so each
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
