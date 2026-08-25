import 'package:flutter/widgets.dart';

/// Wraps [child] in a dashed rounded-rectangle outline — used for plan
/// blocks, the legend's "planned" swatch, and the untracked-gap inner box.
///
/// [radius] defaults to the event-block radius so a dashed planned block
/// lines up with the solid actual block it sits behind; pass
/// `Radius.zero` for a square dashed outline.
class DashedRectBorder extends StatelessWidget {
  const DashedRectBorder({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 3,
    this.dashGap = 2,
    this.radius = const Radius.circular(4),
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final Radius radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashGap: dashGap,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final Radius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(strokeWidth / 2);
    // An RRect, not a Rect — `computeMetrics` below walks whatever path it
    // is given, so the rounded corners get dashed along their arc for free.
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashWidth != oldDelegate.dashWidth ||
      dashGap != oldDelegate.dashGap ||
      radius != oldDelegate.radius;
}
