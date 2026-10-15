import 'package:flutter/material.dart';

/// A decorative glass bottle. A zero fill intentionally leaves the bottle empty.
class GlassBottle extends StatelessWidget {
  const GlassBottle({
    required this.color,
    this.fill = 0,
    this.height = 120,
    this.icon = Icons.auto_stories_outlined,
    super.key,
  }) : assert(height > 0);

  final Color color;
  final double fill;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final safeFill = fill.isFinite ? fill.clamp(0.0, 1.0).toDouble() : 0.0;
    final safeHeight = height.isFinite ? height : 120.0;
    final visibleColor = color.withValues(alpha: 1);
    return Semantics(
      label: '时间之瓶',
      value: '已装入 ${(safeFill * 100).round()}%',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: safeHeight * 0.7,
            height: safeHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GlassBottlePainter(
                      color: visibleColor,
                      fill: safeFill,
                    ),
                  ),
                ),
                Positioned(
                  top: safeHeight * 0.5,
                  child: Icon(
                    icon,
                    size: safeHeight * 0.19,
                    color: Color.lerp(
                      visibleColor,
                      const Color(0xFFECF8FF),
                      0.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBottlePainter extends CustomPainter {
  const _GlassBottlePainter({required this.color, required this.fill});

  final Color color;
  final double fill;

  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 98, size.height / 140);
    final glass = Path()
      ..moveTo(34, 15)
      ..lineTo(64, 15)
      ..lineTo(64, 32)
      ..cubicTo(64, 38, 82, 41, 84, 56)
      ..lineTo(84, 117)
      ..cubicTo(84, 128, 76, 132, 67, 132)
      ..lineTo(31, 132)
      ..cubicTo(22, 132, 14, 128, 14, 117)
      ..lineTo(14, 56)
      ..cubicTo(16, 41, 34, 38, 34, 32)
      ..close();
    const bounds = Rect.fromLTWH(14, 15, 70, 117);
    final tint = Color.lerp(color, _white, 0.45)!;
    canvas.drawOval(
      const Rect.fromLTWH(11, 130, 76, 8),
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
        ).createShader(const Rect.fromLTWH(11, 130, 76, 8)),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [
            tint.withValues(alpha: 0.24),
            _white.withValues(alpha: 0.025),
            color.withValues(alpha: 0.07),
            tint.withValues(alpha: 0.2),
          ],
          stops: const [0, 0.26, 0.7, 1],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(glass);
    if (fill > 0) {
      final surface = 129 - 81 * fill;
      final sandBounds = Rect.fromLTRB(14, surface, 84, 133);
      canvas.drawRect(
        sandBounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, _white, 0.45)!,
              color,
              Color.lerp(color, const Color(0xFF243647), 0.2)!,
            ],
            stops: const [0, 0.48, 1],
          ).createShader(sandBounds),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(49, surface), width: 70, height: 8),
        Paint()..color = Color.lerp(color, _white, 0.58)!,
      );
      canvas.drawLine(
        Offset(23, surface + 2),
        Offset(68, surface + 2),
        Paint()
          ..color = _white.withValues(alpha: 0.35)
          ..strokeWidth = 0.7,
      );
    }
    canvas.restore();

    canvas.drawPath(
      glass,
      Paint()
        ..color = tint.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawPath(
      Path()
        ..moveTo(37, 23)
        ..lineTo(37, 32)
        ..cubicTo(37, 42, 20, 45, 20, 59)
        ..lineTo(20, 111),
      Paint()
        ..color = _white.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(78, 60)
        ..lineTo(78, 111)
        ..quadraticBezierTo(78, 124, 67, 126),
      Paint()
        ..color = _white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    const mouth = Rect.fromLTWH(30, 10, 38, 11);
    canvas.drawOval(
      mouth,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _white.withValues(alpha: 0.58),
            tint.withValues(alpha: 0.16),
            _white.withValues(alpha: 0.35),
          ],
        ).createShader(mouth),
    );
    canvas.drawOval(
      mouth,
      Paint()
        ..color = tint.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawOval(
      const Rect.fromLTWH(35, 12, 28, 6),
      Paint()
        ..color = color.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassBottlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
