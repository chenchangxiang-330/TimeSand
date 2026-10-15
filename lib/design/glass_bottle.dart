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
  static const _warm = Color(0xFFFFF0D7);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 98, size.height / 140);
    final glass = Path()
      ..moveTo(34, 15)
      ..lineTo(64, 15)
      ..lineTo(64, 32)
      ..cubicTo(64, 40, 83, 41, 85, 58)
      ..cubicTo(87, 73, 86, 99, 84, 117)
      ..cubicTo(83, 128, 76, 132, 66, 132)
      ..lineTo(32, 132)
      ..cubicTo(22, 132, 15, 128, 14, 117)
      ..cubicTo(12, 99, 11, 73, 13, 58)
      ..cubicTo(15, 41, 34, 40, 34, 32)
      ..close();
    const bounds = Rect.fromLTWH(11, 15, 76, 117);
    final tint = Color.lerp(color, _white, 0.42)!;
    final edge = Color.lerp(color, const Color(0xFF5C86A3), 0.5)!;
    _glow(
      canvas,
      const Rect.fromLTWH(11, 130, 76, 8),
      edge.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [
            tint.withValues(alpha: 0.32),
            _white.withValues(alpha: 0.22),
            _white.withValues(alpha: 0.035),
            color.withValues(alpha: 0.05),
            tint.withValues(alpha: 0.26),
          ],
          stops: const [0, 0.15, 0.43, 0.72, 1],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(glass);
    if (fill > 0) {
      final surface = 129 - 81 * fill;
      final sandBounds = Rect.fromLTRB(11, surface, 87, 133);
      canvas.drawRect(
        sandBounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, _white, 0.60)!,
              Color.lerp(color, _white, 0.12)!,
              Color.lerp(color, const Color(0xFF334E68), 0.22)!,
              Color.lerp(color, _white, 0.24)!,
            ],
            stops: const [0, 0.3, 0.76, 1],
          ).createShader(sandBounds),
      );
      final glow = Rect.fromCenter(
        center: Offset(37, surface + 6),
        width: 65,
        height: 28,
      );
      _glow(canvas, glow, _white.withValues(alpha: 0.35));
      for (var i = 0; i < 65; i++) {
        canvas.drawCircle(
          Offset(
            14 + ((i * 47 + 13) % 101) / 101 * 70,
            surface + ((i * 71 + 31) % 103) / 103 * (132 - surface),
          ),
          i.isEven ? 0.42 : 0.27,
          Paint()
            ..color = i.isEven
                ? _white.withValues(alpha: 0.5)
                : edge.withValues(alpha: 0.25),
        );
      }
      final surfaceBounds = Rect.fromCenter(
        center: Offset(49, surface),
        width: 72,
        height: 8,
      );
      canvas.drawOval(
        surfaceBounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, _warm, 0.72)!,
              Color.lerp(color, _white, 0.5)!,
              color,
            ],
          ).createShader(surfaceBounds),
      );
    }
    canvas.restore();

    canvas.drawPath(
      glass,
      Paint()
        ..color = edge.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _white.withValues(alpha: 0.9),
            tint.withValues(alpha: 0.86),
            _white.withValues(alpha: 0.88),
            edge.withValues(alpha: 0.65),
          ],
          stops: const [0, 0.3, 0.7, 1],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    final highlight = Path()
      ..moveTo(38, 24)
      ..lineTo(38, 33)
      ..cubicTo(36, 44, 20, 46, 19, 61)
      ..cubicTo(18, 75, 18, 96, 20, 110);
    canvas.drawPath(
      highlight,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _white.withValues(alpha: 0.12),
            _white.withValues(alpha: 0.9),
            _warm.withValues(alpha: 0.7),
            _white.withValues(alpha: 0.1),
          ],
          stops: const [0, 0.22, 0.53, 1],
        ).createShader(highlight.getBounds())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(79, 62)
        ..cubicTo(81, 83, 80, 104, 78, 116)
        ..quadraticBezierTo(76, 125, 64, 127),
      Paint()
        ..color = _white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );

    const mouth = Rect.fromLTWH(29, 9, 40, 12);
    canvas.drawOval(
      mouth.translate(0, 2.5),
      Paint()
        ..color = edge.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final rim = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(mouth)
      ..addOval(const Rect.fromLTWH(34, 12, 30, 5));
    canvas.drawPath(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_white, _warm.withValues(alpha: 0.78), tint],
          stops: const [0, 0.45, 1],
        ).createShader(mouth),
    );
    canvas.drawOval(
      mouth,
      Paint()
        ..color = _white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawArc(
      const Rect.fromLTWH(17, 122, 64, 8),
      0,
      3.141592653589793,
      false,
      Paint()
        ..color = _white.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  // Scale a circular shader with its canvas so wide reflections remain
  // elliptical instead of collapsing to a dot on the shortest dimension.
  void _glow(Canvas canvas, Rect bounds, Color color) {
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.scale(bounds.width / 2, bounds.height / 2);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(const Rect.fromLTWH(-1, -1, 2, 2)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassBottlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
