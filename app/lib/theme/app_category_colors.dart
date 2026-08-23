import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Category hues, per the handoff: `oklch(0.58 0.19 <hue>)`, converted once
/// to sRGB hex (Dart has no native OKLCH). Meetings is pinned to the theme
/// accent rather than deriving its own hue.
class AppCategoryColors {
  AppCategoryColors._();

  /// oklch(0.58 0.19 145)
  static const walking = Color(0xFF009520);

  /// oklch(0.58 0.19 255)
  static const deepWork = Color(0xFF0278E7);

  /// Pinned to the theme accent, per the design spec.
  static const meetings = AppColors.accent;

  /// oklch(0.58 0.19 300)
  static const admin = Color(0xFF8E57D8);

  /// A 5th hue at the same lightness/chroma, per the handoff's rule for any
  /// new category. oklch(0.58 0.19 200)
  static const screenTime = Color(0xFF0097A6);

  /// `color-mix(in oklch, <category> 15%, #fff)`, approximated in sRGB —
  /// visually indistinguishable from the OKLCH mix at this ratio.
  static Color blockFill(Color category) =>
      Color.lerp(const Color(0xFFFFFFFF), category, 0.15)!;
}
