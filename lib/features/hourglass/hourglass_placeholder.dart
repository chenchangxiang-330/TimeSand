import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A glass vessel whose sand volume follows the supplied day progress.
/// The repeating animation is decorative and never measures elapsed time.
class HourglassPlaceholder extends StatefulWidget {
  const HourglassPlaceholder({
    required this.progress,
    this.height = 320,
    this.animate = true,
    super.key,
  }) : assert(height > 0);

  final double progress;
  final double height;
  final bool animate;

  @override
  State<HourglassPlaceholder> createState() => _HourglassPlaceholderState();
}

class _HourglassPlaceholderState extends State<HourglassPlaceholder>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _motionAllowed = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        TickerMode.valuesOf(context).enabled;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant HourglassPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final progress = widget.progress;
    final shouldAnimate =
        widget.animate &&
        _motionAllowed &&
        _foreground &&
        progress.isFinite &&
        progress > 0 &&
        progress < 1;
    if (shouldAnimate && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!shouldAnimate && _motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.isFinite
        ? widget.progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final height = widget.height.isFinite ? widget.height : 320.0;
    return Semantics(
      label: '时间沙漏',
      value: '今天已流逝 ${(progress * 100).round()}%',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: height * 0.6875,
            height: height,
            child: CustomPaint(
              painter: _GlassHourglassPainter(
                progress: progress,
                motion: _motion,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassHourglassPainter extends CustomPainter {
  _GlassHourglassPainter({required this.progress, required this.motion})
    : super(repaint: motion);

  final double progress;
  final Animation<double> motion;

  static const _white = Color(0xFFFFFFFF);
  static const _edge = Color(0xFF90B8CF);
  static const _warm = Color(0xFFFFF0CD);
  static const _shadow = Color(0xFF456E87);
  static const _center = 110.0;
  static const _top = 31.0;
  static const _neck = 158.0;
  static const _bottom = 285.0;
  static const _radius = 73.0;
  static const _neckRadius = 5.0;
  static const _bulge = 32.0;

  double _radiusAt(double t) =>
      _neckRadius +
      (_radius - _neckRadius) * (3 * t * t - 2 * t * t * t) +
      _bulge * math.sin(math.pi * t) * math.sin(math.pi * t);

  double _radiusSlope(double t) =>
      (_radius - _neckRadius) * (6 * t - 6 * t * t) +
      _bulge * math.pi * math.sin(2 * math.pi * t);

  Path _vessel({double inset = 0}) {
    final path = Path()
      ..moveTo(_center - _radius + inset, _top)
      ..lineTo(_center + _radius - inset, _top);
    // Hermite segments preserve the smooth rounded bulb, including its shoulder.
    void chamber(double side, bool upper, double from, double to) {
      const height = _neck - _top;
      final direction = upper ? -1.0 : 1.0;
      for (var i = 0; i < 12; i++) {
        final a = from + (to - from) * i / 12;
        final b = from + (to - from) * (i + 1) / 12;
        final delta = (b - a) / 3;
        final ax = _center + side * (_radiusAt(a) - inset);
        final ay = _neck + direction * height * a;
        final bx = _center + side * (_radiusAt(b) - inset);
        final by = _neck + direction * height * b;
        path.cubicTo(
          ax + side * _radiusSlope(a) * delta,
          ay + direction * height * delta,
          bx - side * _radiusSlope(b) * delta,
          by - direction * height * delta,
          bx,
          by,
        );
      }
    }

    chamber(1, true, 1, 0);
    chamber(1, false, 0, 1);
    path.lineTo(_center - _radius + inset, _bottom);
    chamber(-1, false, 1, 0);
    chamber(-1, true, 0, 1);
    return path..close();
  }

  // Resolve the curved sand surface against the actual interior cross-section.
  // This is cached per progress value; animation frames only move light grains.
  late final Path _outerGlass = _vessel();
  late final Path _innerGlass = _vessel(inset: 3);
  late final Path _glassWall = Path.combine(
    PathOperation.difference,
    _outerGlass,
    _innerGlass,
  );
  late final _SandShape _upperSand = _sandShape(true, 1 - progress);
  late final _SandShape _lowerSand = _sandShape(false, progress);

  _SandShape _sandShape(bool upper, double fraction) {
    final top = upper ? _top : _neck;
    final bottom = upper ? _neck : _bottom;
    final curvature = (upper ? -7.0 : 15.0) * math.sin(math.pi * fraction);
    const slices = 192;
    final step = (bottom - top) / slices;
    final widths = List<double>.generate(slices, (i) {
      final y = top + (i + 0.5) * step;
      final level = upper
          ? (_neck - y) / (_neck - _top)
          : (y - _neck) / (_bottom - _neck);
      return _radiusAt(level) - 3;
    });
    final total = widths.fold<double>(0, (sum, radius) => sum + radius * 2);
    double areaBelow(double centerY) {
      var area = 0.0;
      for (var i = 0; i < slices; i++) {
        final y = top + (i + 0.5) * step;
        final radius = widths[i];
        if (curvature.abs() < 0.0001) {
          if (y >= centerY) area += radius * 2;
        } else if (curvature > 0) {
          if (y >= centerY) {
            final reach = 80 * math.sqrt((y - centerY) / curvature);
            area += math.min(radius, reach) * 2;
          }
        } else if (y >= centerY) {
          area += radius * 2;
        } else {
          final hollow = 80 * math.sqrt((centerY - y) / -curvature);
          area += math.max(0.0, radius - hollow) * 2;
        }
      }
      return area;
    }

    var low = top - curvature.abs();
    var high = bottom + curvature.abs();
    for (var i = 0; i < 24; i++) {
      final midpoint = (low + high) / 2;
      if (areaBelow(midpoint) > total * fraction) {
        low = midpoint;
      } else {
        high = midpoint;
      }
    }
    final centerY = fraction >= 1
        ? top
        : fraction <= 0
        ? bottom
        : (low + high) / 2;
    final surface = Path();
    final fill = Path();
    final cap = Path();
    for (var i = 0; i <= 60; i++) {
      final x = 20 + i * 3.0;
      final u = (x - _center) / 80;
      final y = centerY + curvature * u * u;
      if (i == 0) {
        surface.moveTo(x, y);
        fill.moveTo(x, y);
        cap.moveTo(x, y);
      } else {
        surface.lineTo(x, y);
        fill.lineTo(x, y);
        cap.lineTo(x, y);
      }
    }
    fill
      ..lineTo(200, bottom + 1)
      ..lineTo(20, bottom + 1)
      ..close();
    for (var i = 60; i >= 0; i--) {
      final x = 20 + i * 3.0;
      final u = (x - _center) / 80;
      cap.lineTo(x, centerY + curvature * u * u + 5);
    }
    cap.close();
    return _SandShape(
      fill: fill,
      surface: surface,
      cap: cap,
      bounds: Rect.fromLTRB(20, top, 200, bottom),
      centerY: centerY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 320);
    final glass = _outerGlass;
    const bodyBounds = Rect.fromLTWH(21, 29, 178, 258);
    const contact = Rect.fromLTWH(27, 296, 166, 12);
    _glow(canvas, contact, _shadow.withValues(alpha: 0.16));
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _edge.withValues(alpha: 0.25),
            _white.withValues(alpha: 0.14),
            _white.withValues(alpha: 0.02),
            _warm.withValues(alpha: 0.1),
            _edge.withValues(alpha: 0.23),
          ],
          stops: const [0, 0.13, 0.43, 0.76, 1],
        ).createShader(bodyBounds),
    );

    canvas.save();
    canvas.clipPath(_innerGlass);
    if (progress < 1) {
      _sand(canvas, _upperSand, 17);
    }
    if (progress > 0) {
      _sand(canvas, _lowerSand, 71);
    }
    if (progress > 0 && progress < 1) {
      final stream = Rect.fromLTRB(108.6, _neck, 111.4, _lowerSand.centerY);
      canvas.drawRect(
        stream,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _white.withValues(alpha: 0.88),
              _warm.withValues(alpha: 0.2),
            ],
          ).createShader(stream),
      );
      for (var i = 0; i < 9; i++) {
        final travel = (motion.value + i / 9) % 1;
        canvas.drawCircle(
          Offset(
            _center + math.sin(i * 2.4) * 1.5,
            _neck + (_lowerSand.centerY - _neck) * travel,
          ),
          i.isEven ? 0.85 : 0.5,
          Paint()..color = _white.withValues(alpha: 0.9),
        );
      }
    }
    canvas.restore();

    // The wall is a filled thickness band, with a cool outer reflection and
    // a warm inner reflection; the center remains transparent to the scene.
    canvas.drawPath(
      _glassWall,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _edge.withValues(alpha: 0.78),
            _white.withValues(alpha: 0.92),
            _warm.withValues(alpha: 0.50),
            _shadow.withValues(alpha: 0.48),
          ],
          stops: const [0, 0.21, 0.68, 1],
        ).createShader(bodyBounds),
    );
    canvas.save();
    canvas.clipPath(_innerGlass);
    for (final upper in [true, false]) {
      _curvedReflection(canvas, upper, -1);
      _curvedReflection(canvas, upper, 1);
    }
    canvas.restore();
    // Two distinct rims of the glass wall remain readable on a bright sky.
    canvas.drawPath(
      glass,
      Paint()
        ..color = _shadow.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _white.withValues(alpha: 0.95),
            _edge.withValues(alpha: 0.7),
            _white.withValues(alpha: 0.92),
            _edge.withValues(alpha: 0.62),
          ],
          stops: const [0, 0.31, 0.75, 1],
        ).createShader(bodyBounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawPath(
      _vessel(inset: 3),
      Paint()
        ..color = _white.withValues(alpha: 0.57)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _reflection(canvas, true);
    _reflection(canvas, false);
    _rim(canvas, _top);
    _rim(canvas, _bottom);
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

  void _sand(Canvas canvas, _SandShape shape, int seed) {
    canvas.save();
    canvas.clipRect(shape.bounds);
    canvas.clipPath(shape.fill);
    canvas.drawRect(
      shape.bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFEF7),
            Color(0xFFFFFFFF),
            Color(0xFFCADBE6),
            Color(0xFFF5F5E9),
          ],
          stops: [0, 0.24, 0.76, 1],
        ).createShader(shape.bounds),
    );
    _glow(
      canvas,
      Rect.fromCenter(
        center: Offset(96, shape.centerY + 12),
        width: 150,
        height: 68,
      ),
      _white.withValues(alpha: 0.92),
    );
    for (var i = 0; i < 165; i++) {
      final x = 20 + ((i * 73 + seed * 19) % 211) / 211 * 180;
      final y =
          shape.bounds.top +
          ((i * 97 + seed * 23) % 223) / 223 * shape.bounds.height;
      canvas.drawCircle(
        Offset(x, y),
        i % 5 == 0 ? 0.72 : 0.37,
        Paint()
          ..color = i.isEven
              ? _white.withValues(alpha: 0.88)
              : _shadow.withValues(alpha: 0.22),
      );
      if (i % 23 == 0) {
        canvas.drawLine(
          Offset(x - 1.5, y),
          Offset(x + 1.5, y),
          Paint()
            ..color = _white.withValues(alpha: 0.65)
            ..strokeWidth = 0.45,
        );
      }
    }
    canvas.drawPath(
      shape.cap,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _warm.withValues(alpha: 0.9),
            _white.withValues(alpha: 0.95),
            _edge.withValues(alpha: 0.35),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(shape.bounds),
    );
    canvas.drawPath(
      shape.surface,
      Paint()
        ..color = _white.withValues(alpha: 0.94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.restore();
  }

  void _curvedReflection(Canvas canvas, bool upper, double side) {
    const height = _neck - _top;
    final direction = upper ? -1.0 : 1.0;
    final ribbon = Path();
    for (var edge = 0; edge < 2; edge++) {
      for (var i = 0; i <= 24; i++) {
        final t = edge == 0 ? 0.3 + i / 24 * 0.65 : 0.95 - i / 24 * 0.65;
        final offset = edge == 0 ? 5.0 : 16.0;
        final x = _center + side * (_radiusAt(t) - offset);
        final y = _neck + direction * height * t;
        if (edge == 0 && i == 0) {
          ribbon.moveTo(x, y);
        } else {
          ribbon.lineTo(x, y);
        }
      }
    }
    ribbon.close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = LinearGradient(
          begin: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
          end: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            (side < 0 ? _white : _edge).withValues(alpha: 0.48),
            _warm.withValues(alpha: 0.16),
            _white.withValues(alpha: 0),
          ],
          stops: const [0, 0.25, 1],
        ).createShader(ribbon.getBounds()),
    );
  }

  void _reflection(Canvas canvas, bool upper) {
    const height = _neck - _top;
    final sign = upper ? -1.0 : 1.0;
    final path = Path();
    for (var i = 0; i <= 30; i++) {
      final t = 0.38 + i / 30 * 0.54;
      final point = Offset(
        _center - _radiusAt(t) + 7,
        _neck + sign * height * t,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _white.withValues(alpha: 0),
            _white.withValues(alpha: 0.88),
            _warm.withValues(alpha: 0.65),
            _white.withValues(alpha: 0),
          ],
          stops: const [0, 0.24, 0.7, 1],
        ).createShader(path.getBounds())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _rim(Canvas canvas, double y) {
    final bounds = Rect.fromCenter(
      center: Offset(_center, y),
      width: (_radius + 5) * 2,
      height: 19,
    );
    canvas.drawOval(
      bounds.translate(0, 4),
      Paint()
        ..color = _edge.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(bounds)
      ..addOval(
        Rect.fromCenter(
          center: Offset(_center, y - 0.5),
          width: bounds.width - 9,
          height: 8,
        ),
      );
    canvas.drawPath(
      ring,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_white, _warm.withValues(alpha: 0.7), _edge],
          stops: const [0, 0.42, 1],
        ).createShader(bounds),
    );
    canvas.drawOval(
      bounds,
      Paint()
        ..color = _white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(_GlassHourglassPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.motion != motion;
}

class _SandShape {
  const _SandShape({
    required this.fill,
    required this.surface,
    required this.cap,
    required this.bounds,
    required this.centerY,
  });

  final Path fill;
  final Path surface;
  final Path cap;
  final Rect bounds;
  final double centerY;
}
