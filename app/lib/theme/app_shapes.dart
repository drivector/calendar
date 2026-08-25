import 'package:flutter/widgets.dart';

/// Fluent 2 corner radii and elevation — the two things the previous flat
/// design system deliberately had none of, and the biggest single lever in
/// making this read as Outlook rather than a wireframe.
///
/// Radii are exposed as [BorderRadius] rather than raw doubles so call
/// sites read `borderRadius: AppShapes.small` and can't accidentally mix
/// a radius into a place expecting a size.
class AppShapes {
  AppShapes._();

  /// Buttons, inputs, chips, calendar event blocks.
  static const small = BorderRadius.all(Radius.circular(4));

  /// Cards, menus, popups, dialogs.
  static const medium = BorderRadius.all(Radius.circular(8));

  /// Large surfaces — the top corners of a modal bottom sheet.
  static const large = BorderRadius.all(Radius.circular(12));

  /// A bottom sheet only rounds where it meets the content behind it.
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(12));

  /// Fluent `shadow2` — resting cards and bars. Two layers: a soft
  /// directional drop plus a tight ambient ring, which is what stops a
  /// Fluent surface looking like a flat rectangle with a blur under it.
  static const shadow2 = [
    BoxShadow(
      color: Color(0x24000000), // rgba(0,0,0,.14)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(color: Color(0x1F000000), blurRadius: 2), // rgba(0,0,0,.12)
  ];

  /// Fluent `shadow8` — flyouts, menus, sheets: anything floating above
  /// the page rather than sitting on it.
  static const shadow8 = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x1F000000), blurRadius: 2),
  ];
}
