import 'package:flutter/widgets.dart';

/// Outlook's own calendar-category palette, replacing the OKLCH-derived
/// hues the flat system used.
///
/// Note [meetings] is a real colour of its own now. It used to be pinned to
/// `AppColors.accent`, which stopped working the moment the accent became
/// Outlook blue — it would have collided with [deepWork].
class AppCategoryColors {
  AppCategoryColors._();

  /// Outlook green.
  static const walking = Color(0xFF107C10);

  /// Outlook blue.
  static const deepWork = Color(0xFF0078D4);

  /// Outlook red.
  static const meetings = Color(0xFFD13438);

  /// Outlook purple.
  static const admin = Color(0xFF5C2E91);

  /// Outlook teal.
  static const screenTime = Color(0xFF008272);

  /// The pale fill behind an event chip — Outlook tints the category colour
  /// toward white rather than using it at full strength, so the subject
  /// text stays readable on top.
  static Color blockFill(Color category) =>
      Color.lerp(const Color(0xFFFFFFFF), category, 0.15)!;

  /// A planned block's own light fill — true alpha, not a lerp toward
  /// white like [blockFill], so it reads as translucent (the grid lines
  /// underneath still show through) rather than just a paler solid.
  static Color planFill(Color category) => category.withValues(alpha: 0.3);
}
