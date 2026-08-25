import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shapes.dart';
import 'app_text_styles.dart';

/// Minimal [ThemeData] so Material widgets used later (e.g. a [TextField] in
/// the Log screen) inherit sane defaults. Day-view widgets reference
/// [AppColors]/[AppSpacing]/[AppShapes]/[AppTextStyles] directly rather than
/// through a [ThemeExtension] — there's no dark mode or multi-brand
/// requirement yet.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.bg,
    ),
    // No `fontFamily`/`textTheme` override — Flutter's default resolves to
    // the platform system font (SF Pro on iOS/macOS), which is what
    // AppTextStyles builds on too. See its own doc comment for why Segoe UI
    // isn't used here.
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
      contentTextStyle: AppTextStyles.label(color: AppColors.surface),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.small),
    ),
  );
}
