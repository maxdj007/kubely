import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    this.width = 40,
    this.height = 16,
    this.lineColor = const Color(0xFF2EE6C5),
    this.lineWidth = 1.4,
  });

  final List<double> data;
  final double width;
  final double height;
  final Color lineColor;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          lineColor: lineColor,
          lineWidth: lineWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.lineWidth,
  });

  final List<double> data;
  final Color lineColor;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final step = size.width / (data.length - 1);
    final padding = 2.0;
    final drawHeight = size.height - padding * 2;

    for (var i = 0; i < data.length; i++) {
      final x = i * step;
      final normalized = (data[i] - minVal) / effectiveRange;
      final y = padding + drawHeight * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      data != oldDelegate.data || lineColor != oldDelegate.lineColor;
}
