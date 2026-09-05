import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';

/// A thin proportional bar: a solid [filled] run, an optional [hatched]
/// run after it, and whatever's left of [total] as bare track.
///
/// Shared by the calendar's two summary strips, which mean different
/// things by it — the header draws logged time (solid) and planned-ahead
/// time (hatched) against one day's tracking window, the drift footer
/// draws one goal's logged time against that goal's own plan — hence the
/// deliberately neutral parameter names.
///
/// The runs are laid out by integer flex over [kFlexResolution] rather
/// than fractional widths, so they stay exact at any track width.
/// Together they're clamped to the whole track: a day (or goal) already
/// past [total] renders as full, not as an overflow.
class CapacityTrack extends StatelessWidget {
  const CapacityTrack({
    super.key,
    required this.filled,
    required this.total,
    this.hatched = Duration.zero,
    this.fillColor = AppColors.accent,
  });

  static const double height = 6;

  /// Flex units one full track is divided into. 1000 puts the rounding
  /// error below a tenth of a percent — invisible at this height.
  static const int kFlexResolution = 1000;

  final Duration filled;
  final Duration hatched;
  final Duration total;
  final Color fillColor;

  int _flex(Duration part) {
    if (total <= Duration.zero) return 0;
    return (part.inSeconds * kFlexResolution / total.inSeconds)
        .round()
        .clamp(0, kFlexResolution);
  }

  @override
  Widget build(BuildContext context) {
    final filledFlex = _flex(filled);
    // Whatever's left after the solid run — something already over its
    // total has no room left to draw the hatched run in.
    final hatchedFlex = _flex(hatched).clamp(0, kFlexResolution - filledFlex);
    final remainder = kFlexResolution - filledFlex - hatchedFlex;

    return ClipRRect(
      borderRadius: AppShapes.small,
      child: SizedBox(
        height: height,
        // stretch, not the default centre: a childless ColoredBox given
        // loose vertical constraints sizes itself to zero height, so the
        // fills paint nothing at all. Only caught by looking at the real
        // app — a widget test asserting fill *widths* passes either way.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (filledFlex > 0)
              Expanded(flex: filledFlex, child: ColoredBox(color: fillColor)),
            if (hatchedFlex > 0)
              Expanded(flex: hatchedFlex, child: const _HatchFill()),
            if (remainder > 0)
              Expanded(
                flex: remainder,
                child: const ColoredBox(color: AppColors.neutral300),
              ),
          ],
        ),
      ),
    );
  }
}

/// The hatched run's fill: accent diagonal stripes on white, the
/// flat-colour cousin of the dashed outline a planned block gets on the
/// timeline. A dashed *outline* would collapse to mush inside a 6px-tall
/// run, so the texture goes inside instead.
class _HatchFill extends StatelessWidget {
  const _HatchFill();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _HatchPainter());
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  static const double _spacing = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);
    final paint = Paint()
      ..color = AppColors.accent300
      ..strokeWidth = 2;
    // 45° stripes: walk x from -height so the first stripe's bottom-left
    // corner still crosses the run rather than starting mid-way in.
    for (var x = -size.height; x < size.width; x += _spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}
