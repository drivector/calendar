import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';
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
      // A bare Scaffold, not Material — no appBar/FAB/drawer chrome, but a
      // Scaffold is required for ScaffoldMessenger.showSnackBar to work
      // anywhere in the app (it asserts a descendant Scaffold exists,
      // regardless of SnackBarBehavior).
      home: const Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: AuthGate()),
      ),
    );
  }
}
