import 'package:flutter/material.dart';

import 'shell/root_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class CalendarTrackerApp extends StatelessWidget {
  const CalendarTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Material(
        color: AppColors.bg,
        child: SafeArea(child: RootShell()),
      ),
    );
  }
}
