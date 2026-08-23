import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles ported from the handoff's type hierarchy. The wireframe's
/// literal 9px/10px sizes are wireframe-only (see the handoff README) — real
/// UI type uses an 11px minimum for labels, per that same section.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _archivo({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    Color color = AppColors.text,
  }) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _mono({
    required double fontSize,
    Color color = AppColors.text,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'SF Mono', 'Courier'],
      fontSize: fontSize,
      color: color,
    );
  }

  /// Uppercase section/field caption, e.g. "THURSDAY", "PLAN", "ACTUAL".
  static TextStyle kicker({Color? color}) => _archivo(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1, // ~.1em at 11px
        color: color ?? AppColors.ink(0.5),
      );

  /// Screen/day title, e.g. "20 Aug".
  static TextStyle title({Color? color}) => _archivo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.text,
      );

  /// Block / row label, e.g. "Walk 45 m".
  static TextStyle label({Color? color}) => _archivo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.text,
      );

  /// Segmented-control / tag text.
  static TextStyle small({Color? color}) => _archivo(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.text,
      );

  /// Monospace annotation — hour gutter, source line, drift figures.
  static TextStyle mono({Color? color}) =>
      _mono(fontSize: 11, color: color ?? AppColors.ink(0.5));

  /// Larger monospace, e.g. computed duration in the log form.
  static TextStyle monoLarge({Color? color}) =>
      _mono(fontSize: 16, color: color ?? AppColors.text);

  /// Bottom tab bar label.
  static TextStyle tabLabel({Color? color}) => _archivo(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.66, // ~.06em at 11px
        color: color ?? AppColors.ink(0.4),
      );
}
