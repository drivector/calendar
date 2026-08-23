import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Minimal [ThemeData] so Material widgets used later (e.g. a [TextField] in
/// the Log screen) inherit sane defaults. Day-view widgets reference
/// [AppColors]/[AppSpacing]/[AppTextStyles] directly rather than through a
/// [ThemeExtension] — there's no dark mode or multi-brand requirement yet.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.bg,
    ),
    textTheme: GoogleFonts.archivoTextTheme().apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.3),
      selectionHandleColor: AppColors.accent,
    ),
    dividerColor: AppColors.divider,
    splashFactory: NoSplash.splashFactory,
    highlightColor: AppColors.accent.withValues(alpha: 0.08),
    // `behavior: floating` is required, not just stylistic — this app has
    // no `Scaffold` anywhere (by design, per the Modernist system), and
    // `SnackBarBehavior.fixed` throws without one ("no descendant
    // Scaffolds to present to"). Floating renders via the ScaffoldMessenger
    // overlay directly.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: AppTextStyles.label(color: AppColors.bg),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
  );
}
