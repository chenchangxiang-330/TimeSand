import 'package:flutter/material.dart';

class HourglassPlaceholder extends StatelessWidget {
  const HourglassPlaceholder({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TimeSand hourglass placeholder',
      value: '${(progress * 100).round()} percent of the day elapsed',
      child: CustomPaint(
        painter: _HourglassPainter(progress: progress),
        child: const SizedBox(width: 190, height: 250),
      ),
    );
  }
}

class _HourglassPainter extends CustomPainter {
  const _HourglassPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    const top = 20.0;
    final bottom = size.height - 20.0;
    final neck = size.height / 2;
    final framePaint = Paint()
      ..color = const Color(0xFF29251F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final sandPaint = Paint()..color = const Color(0xFFE8C98D);

    final glass = Path()
      ..moveTo(center - 62, top)
      ..lineTo(center + 62, top)
      ..lineTo(center + 8, neck)
      ..lineTo(center + 62, bottom)
      ..lineTo(center - 62, bottom)
      ..lineTo(center - 8, neck)
      ..close();

    canvas.drawPath(glass, framePaint);
    canvas.drawLine(
      Offset(center - 70, top),
      Offset(center + 70, top),
      framePaint,
    );
    canvas.drawLine(
      Offset(center - 70, bottom),
      Offset(center + 70, bottom),
      framePaint,
    );

    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final lowerHeight = (bottom - neck - 10) * clamped;
    final lower = Path()
      ..moveTo(center - 8, neck + 3)
      ..lineTo(center + 8, neck + 3)
      ..lineTo(center + 48, bottom - 5)
      ..lineTo(center - 48, bottom - 5)
      ..close();
    canvas.drawPath(lower, sandPaint);

    if (lowerHeight > 0) {
      canvas.drawRect(
        Rect.fromLTWH(center - 2, bottom - 8 - lowerHeight, 4, lowerHeight),
        sandPaint,
      );
    }

    final upperHeight = (neck - top - 12) * (1 - clamped);
    if (upperHeight > 0) {
      canvas.drawRect(
        Rect.fromLTWH(center - 43, top + 7, 86, upperHeight),
        sandPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_HourglassPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
