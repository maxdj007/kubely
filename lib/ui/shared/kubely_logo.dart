import 'package:flutter/material.dart';
import '../../core/theme/kubely_colors.dart';

class KubelyLogo extends StatelessWidget {
  const KubelyLogo({
    super.key,
    this.size = 48,
    this.showHex = false,
    this.color = KubelyColors.accent,
  });

  final double size;
  final bool showHex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KubelyLogoPainter(
          color: color,
          showHex: showHex,
        ),
      ),
    );
  }
}

class _KubelyLogoPainter extends CustomPainter {
  _KubelyLogoPainter({required this.color, required this.showHex});

  final Color color;
  final bool showHex;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48; // scale factor from 48x48 viewBox
    final cx = 24 * s;
    final cy = 24 * s;

    // Hex outline (K8s hexagon)
    if (showHex) {
      final hexPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..strokeJoin = StrokeJoin.round;

      final hexPath = Path();
      final hexPoints = <Offset>[
        Offset(24 * s, 4 * s),
        Offset(40.5 * s, 13.5 * s),
        Offset(40.5 * s, 32.5 * s),
        Offset(24 * s, 44 * s),
        Offset(7.5 * s, 32.5 * s),
        Offset(7.5 * s, 13.5 * s),
      ];
      hexPath.moveTo(hexPoints[0].dx, hexPoints[0].dy);
      for (var i = 1; i < hexPoints.length; i++) {
        hexPath.lineTo(hexPoints[i].dx, hexPoints[i].dy);
      }
      hexPath.close();
      canvas.drawPath(hexPath, hexPaint);
    }

    // Outer rim
    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s;
    canvas.drawCircle(Offset(cx, cy), 11.5 * s, rimPaint);

    // Spokes (6 spokes at 60° intervals = 3 diameters)
    final spokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round;

    // Vertical spoke
    canvas.drawLine(
        Offset(cx, 12.5 * s), Offset(cx, 35.5 * s), spokePaint);
    // 60° spoke (top-left to bottom-right)
    canvas.drawLine(
        Offset(14 * s, 18.2 * s), Offset(34 * s, 29.8 * s), spokePaint);
    // 120° spoke (bottom-left to top-right)
    canvas.drawLine(
        Offset(14 * s, 29.8 * s), Offset(34 * s, 18.2 * s), spokePaint);

    // Hub circle (filled with ink so spokes don't cross)
    final hubFill = Paint()
      ..color = KubelyColors.ink
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 4.4 * s, hubFill);

    final hubStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s;
    canvas.drawCircle(Offset(cx, cy), 4.4 * s, hubStroke);
  }

  @override
  bool shouldRepaint(covariant _KubelyLogoPainter oldDelegate) =>
      color != oldDelegate.color || showHex != oldDelegate.showHex;
}
