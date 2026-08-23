import 'package:flutter/widgets.dart';

/// Modernist design system tokens, ported from
/// `design_handoff_time_tracking_calendar/_ds/modernist-.../styles.css`.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF3F2F2);
  static const surface = Color(0xFFEAE9E9);
  static const text = Color(0xFF201E1D);
  static const accent = Color(0xFFEC3013);

  static const accent100 = Color(0xFFFFF2EF);
  static const accent200 = Color(0xFFFFE0D9);
  static const accent300 = Color(0xFFFFC4B8);
  static const accent400 = Color(0xFFFF9783);
  static const accent500 = Color(0xFFFF563C);
  static const accent600 = Color(0xFFDD2B0F);
  static const accent700 = Color(0xFFAE1800);
  static const accent800 = Color(0xFF7C1405);
  static const accent900 = Color(0xFF4D170E);

  static const neutral100 = Color(0xFFF8F4F4);
  static const neutral200 = Color(0xFFEAE7E7);
  static const neutral300 = Color(0xFFD7D3D3);
  static const neutral400 = Color(0xFFBAB6B6);
  static const neutral500 = Color(0xFF9B9797);
  static const neutral600 = Color(0xFF7D7979);
  static const neutral700 = Color(0xFF605D5D);
  static const neutral800 = Color(0xFF444141);
  static const neutral900 = Color(0xFF2D2B2B);

  /// CSS: `color-mix(in srgb, #201e1d 40%, transparent)`.
  static Color get divider => text.withValues(alpha: 0.4);

  static Color ink(double opacity) => text.withValues(alpha: opacity);
}
