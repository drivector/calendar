import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Fluent 2 / Outlook type ramp, rendered in the **platform system font**
/// (SF Pro on iOS/macOS) — Segoe UI isn't available off Windows and isn't
/// on Google Fonts, and the system face is what Outlook itself renders
/// much of its iOS UI in.
///
/// Every method name here predates the Outlook restyle and is kept
/// deliberately, including [mono]/[monoLarge] — those no longer use a
/// monospace face (Outlook has none), but they still mean "secondary
/// annotation text", so the ~100 call sites didn't need touching.
class AppTextStyles {
  AppTextStyles._();

  /// No `fontFamily` — Flutter falls through to the platform default.
  static TextStyle _system({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    Color color = AppColors.text,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Section/field caption, e.g. "THURSDAY", "EMAIL". Call sites still
  /// uppercase these themselves; the wide tracking the flat system used is
  /// gone, since Outlook doesn't letterspace.
  static TextStyle kicker({Color? color}) => _system(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.textSecondary,
  );

  /// Fluent `subtitle2` — screen/day titles, e.g. "20 Aug".
  static TextStyle title({Color? color}) => _system(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.text,
  );

  /// Fluent `body1` — block/row labels, e.g. an event subject.
  static TextStyle label({Color? color}) => _system(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.text,
  );

  /// Fluent `caption1 strong` — segmented controls, tags, small buttons.
  static TextStyle small({Color? color}) => _system(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.text,
  );

  /// Secondary annotation — hour gutter, an event's source line, drift
  /// figures. Formerly monospace; now just quieter body text.
  static TextStyle mono({Color? color}) => _system(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.textSecondary,
  );

  /// Larger secondary figure, e.g. the computed duration in the log form.
  static TextStyle monoLarge({Color? color}) => _system(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.text,
  );

  /// Bottom tab bar label.
  static TextStyle tabLabel({Color? color}) => _system(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.textSecondary,
  );
}
