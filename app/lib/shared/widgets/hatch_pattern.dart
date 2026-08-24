import 'package:flutter/widgets.dart';

/// The 45° diagonal-stripe fill used for "untracked" in aggregate views
/// (week/month), per the design tokens:
/// `repeating-linear-gradient(45deg, rgba(0,0,0,.14) 0 3px, transparent 3px 6px)`.
class HatchPatternBox extends StatelessWidget {
  const HatchPatternBox({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HatchPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _HatchPainter extends CustomPainter {
  static const _stripeWidth = 3.0;
  static const _period = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.14)
      ..strokeWidth = _stripeWidth
      ..style = PaintingStyle.stroke;

    final diagonal = size.width + size.height;
    for (var offset = -diagonal; offset < diagonal; offset += _period) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}
