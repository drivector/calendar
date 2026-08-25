import 'package:flutter/widgets.dart';

/// Outlook / Fluent 2 design tokens. Token *names* are unchanged from the
/// previous flat "Modernist" system so every call site kept working through
/// the restyle — only what they resolve to changed.
class AppColors {
  AppColors._();

  /// Fluent `neutralBackground3` — the canvas the white surfaces sit on.
  static const bg = Color(0xFFFAF9F8);

  /// Fluent `neutralBackground1` — cards, sheets, bars. Outlook layers
  /// white surfaces on the slightly grey canvas rather than tinting them.
  static const surface = Color(0xFFFFFFFF);

  /// Fluent `neutralForeground1`.
  static const text = Color(0xFF242424);

  /// Fluent `neutralForeground2` — annotations, captions, inactive labels.
  /// Everything that used to lean on a monospace face for "secondary" now
  /// leans on this instead.
  static const textSecondary = Color(0xFF616161);

  /// Fluent `brandForeground1` — Outlook's blue.
  static const accent = Color(0xFF0F6CBD);

  /// Brand ramp around [accent], used for tints/fills and pressed states.
  static const accent100 = Color(0xFFEFF6FC);
  static const accent200 = Color(0xFFCFE4FA);
  static const accent300 = Color(0xFFB4D6FA);
  static const accent400 = Color(0xFF77B7F0);
  static const accent500 = Color(0xFF2886DE);
  static const accent600 = Color(0xFF0F6CBD);
  static const accent700 = Color(0xFF115EA3);
  static const accent800 = Color(0xFF0F548C);
  static const accent900 = Color(0xFF0C3B5E);

  /// Fluent's neutral ramp.
  static const neutral100 = Color(0xFFFAF9F8);
  static const neutral200 = Color(0xFFF5F5F5);
  static const neutral300 = Color(0xFFEDEBE9);
  static const neutral400 = Color(0xFFE0E0E0);
  static const neutral500 = Color(0xFFD1D1D1);
  static const neutral600 = Color(0xFFADADAD);
  static const neutral700 = Color(0xFF757575);
  static const neutral800 = Color(0xFF616161);
  static const neutral900 = Color(0xFF424242);

  /// Fluent `neutralStroke2` — a hairline, not the heavy 40%-ink rule the
  /// flat system used. Anything that needs a *visible* separator at a
  /// glance should use a 1px border in this plus elevation, the way
  /// Outlook separates surfaces.
  static const divider = Color(0xFFE0E0E0);

  /// A one-off ink opacity — still handy for hover/selected row tints.
  static Color ink(double opacity) => text.withValues(alpha: opacity);
}
