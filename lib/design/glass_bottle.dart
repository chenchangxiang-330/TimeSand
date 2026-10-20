import 'dart:math' as math;

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
                      const Color(0xFF193A58),
                      0.45,
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
  _GlassBottlePainter({required this.color, required this.fill});

  final Color color;
  final double fill;

  static const _white = Color(0xFFFFFFFF);
  static const _warm = Color(0xFFFFF0D7);

  late final Path _outerGlass = _vessel(0);
  late final Path _innerGlass = _vessel(2.5);
  late final Path _glassWall = Path.combine(
    PathOperation.difference,
    _outerGlass,
    _innerGlass,
  );
  late final _BottleSand _sandShape = _createSandShape();

  Path _vessel(double inset) => Path()
    ..moveTo(34 + inset, 15)
    ..lineTo(64 - inset, 15)
    ..lineTo(64 - inset, 32)
    ..cubicTo(64 - inset, 40, 83 - inset, 41, 85 - inset, 58)
    ..cubicTo(87 - inset, 73, 86 - inset, 99, 84 - inset, 117)
    ..cubicTo(83 - inset, 128 - inset, 76, 132 - inset, 66, 132 - inset)
    ..lineTo(32, 132 - inset)
    ..cubicTo(22, 132 - inset, 15 + inset, 128 - inset, 14 + inset, 117)
    ..cubicTo(12 + inset, 99, 11 + inset, 73, 13 + inset, 58)
    ..cubicTo(15 + inset, 41, 34 + inset, 40, 34 + inset, 32)
    ..close();

  _BottleSand _createSandShape() {
    const top = 48.0;
    const bottom = 129.5;
    const slices = 128;
    const step = (bottom - top) / slices;
    final curvature = 6.0 * math.sin(math.pi * fill);
    // Sample the real clipped interior, including its shoulder and rounded foot.
    // This work runs once per painter, not on animation frames.
    final widths = List<double>.generate(slices, (i) {
      final y = top + (i + 0.5) * step;
      var low = 0.0;
      var high = 40.0;
      for (var j = 0; j < 15; j++) {
        final x = (low + high) / 2;
        if (_innerGlass.contains(Offset(49 + x, y))) {
          low = x;
        } else {
          high = x;
        }
      }
      return (low + high) / 2;
    });
    final total = widths.fold<double>(0, (sum, radius) => sum + radius * 2);
    double areaBelow(double centerY) {
      var area = 0.0;
      for (var i = 0; i < slices; i++) {
        final y = top + (i + 0.5) * step;
        if (y < centerY) continue;
        final radius = curvature < 0.0001
            ? widths[i]
            : math.min(widths[i], 36 * math.sqrt((y - centerY) / curvature));
        area += radius * 2;
      }
      return area;
    }

    var low = top - curvature;
    var high = bottom;
    for (var i = 0; i < 24; i++) {
      final middle = (low + high) / 2;
      if (areaBelow(middle) > total * fill) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final centerY = fill >= 1 ? top : (low + high) / 2;
    final body = Path();
    final surface = Path();
    final cap = Path();
    for (var i = 0; i <= 39; i++) {
      final x = 10 + i * 2.0;
      final u = (x - 49) / 36;
      final y = centerY + curvature * u * u;
      if (i == 0) {
        body.moveTo(x, y);
        surface.moveTo(x, y);
        cap.moveTo(x, y);
      } else {
        body.lineTo(x, y);
        surface.lineTo(x, y);
        cap.lineTo(x, y);
      }
    }
    body
      ..lineTo(88, bottom)
      ..lineTo(10, bottom)
      ..close();
    for (var i = 39; i >= 0; i--) {
      final x = 10 + i * 2.0;
      final u = (x - 49) / 36;
      cap.lineTo(x, centerY + curvature * u * u + 3.5);
    }
    return _BottleSand(
      fill: body,
      surface: surface,
      cap: cap..close(),
      centerY: centerY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 98, size.height / 140);
    final glass = _outerGlass;
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
    canvas.clipPath(_innerGlass);
    if (fill > 0) _paintSand(canvas, edge);
    _faceReflection(canvas);
    canvas.restore();

    canvas.drawPath(
      _glassWall,
      Paint()
        ..shader = LinearGradient(
          colors: [
            edge.withValues(alpha: 0.72),
            _white.withValues(alpha: 0.92),
            _warm.withValues(alpha: 0.65),
            edge.withValues(alpha: 0.58),
          ],
          stops: const [0, 0.18, 0.65, 1],
        ).createShader(bounds),
    );

    canvas.drawPath(
      glass,
      Paint()
        ..color = edge.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
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
      mouth.translate(0, 3.5),
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

  void _paintSand(Canvas canvas, Color edge) {
    final shape = _sandShape;
    const bounds = Rect.fromLTRB(10, 48, 88, 129.5);
    canvas.save();
    canvas.clipRect(bounds);
    canvas.clipPath(shape.fill);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, _white, 0.70)!,
            Color.lerp(color, _white, 0.13)!,
            Color.lerp(color, const Color(0xFF334E68), 0.3)!,
            Color.lerp(color, _warm, 0.3)!,
          ],
          stops: const [0, 0.28, 0.78, 1],
        ).createShader(bounds),
    );
    _glow(
      canvas,
      Rect.fromCenter(
        center: Offset(39, shape.centerY + 5),
        width: 64,
        height: 32,
      ),
      _white.withValues(alpha: 0.52),
    );
    for (var i = 0; i < 90; i++) {
      canvas.drawCircle(
        Offset(
          14 + ((i * 47 + 13) % 101) / 101 * 70,
          48 + ((i * 71 + 31) % 103) / 103 * 81.5,
        ),
        i.isEven ? 0.46 : 0.28,
        Paint()
          ..color = i.isEven
              ? _white.withValues(alpha: 0.7)
              : edge.withValues(alpha: 0.26),
      );
    }
    canvas.drawPath(
      shape.cap,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, _warm, 0.77)!,
            Color.lerp(color, _white, 0.72)!,
            Color.lerp(color, _white, 0.15)!,
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      shape.surface,
      Paint()
        ..color = _white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65,
    );
    canvas.restore();
  }

  void _faceReflection(Canvas canvas) {
    final reflection = Path()
      ..moveTo(38, 22)
      ..lineTo(38, 33)
      ..cubicTo(36, 44, 21, 44, 20, 60)
      ..cubicTo(18, 79, 20, 105, 23, 118)
      ..quadraticBezierTo(26, 122, 30, 116)
      ..cubicTo(26, 96, 26, 76, 28, 61)
      ..cubicTo(29, 48, 44, 43, 43, 33)
      ..lineTo(43, 22)
      ..close();
    canvas.drawPath(
      reflection,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _white.withValues(alpha: 0.6),
            _warm.withValues(alpha: 0.24),
            _white.withValues(alpha: 0),
          ],
          stops: const [0, 0.38, 1],
        ).createShader(reflection.getBounds()),
    );
    final rearReflection = Path()
      ..moveTo(75, 56)
      ..cubicTo(80, 75, 79, 103, 75, 120)
      ..lineTo(70, 121)
      ..cubicTo(73, 102, 75, 75, 70, 58)
      ..close();
    canvas.drawPath(
      rearReflection,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            _white.withValues(alpha: 0.32),
            color.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.65, 1],
        ).createShader(rearReflection.getBounds()),
    );
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

class _BottleSand {
  const _BottleSand({
    required this.fill,
    required this.surface,
    required this.cap,
    required this.centerY,
  });

  final Path fill;
  final Path surface;
  final Path cap;
  final double centerY;
}
