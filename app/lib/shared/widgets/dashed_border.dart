import 'package:flutter/widgets.dart';

/// Wraps [child] in a dashed rectangle outline — used for plan blocks, the
/// legend's "planned" swatch, and the untracked-gap inner box.
class DashedRectBorder extends StatelessWidget {
  const DashedRectBorder({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 3,
    this.dashGap = 2,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashGap: dashGap,
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
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

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
    final path = Path()..addRect(rect);

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
      dashGap != oldDelegate.dashGap;
}
