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

  // Invert the bulb cross-section integral: decorative animation never changes
  // these upper/lower sand volumes or the supplied real time progress.
  double _levelForVolume(double fraction) {
    if (fraction <= 0) return 0;
    if (fraction >= 1) return 1;
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 24; i++) {
      final t = (low + high) / 2;
      final area =
          (_neckRadius - 2) * t +
          (_radius - _neckRadius) * (t * t * t - 0.5 * t * t * t * t) +
          _bulge * (t / 2 - math.sin(2 * math.pi * t) / (4 * math.pi));
      final total = (_radius + _neckRadius + _bulge - 4) / 2;
      if (area / total < fraction) {
        low = t;
      } else {
        high = t;
      }
    }
    return (low + high) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 320);
    final glass = _vessel();
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

    final level = _levelForVolume(1 - progress);
    final upperSurface = _neck - (_neck - _top) * level;
    final lowerSurface = _neck + (_bottom - _neck) * level;
    final surfaceRadius = _radiusAt(level);
    canvas.save();
    canvas.clipPath(_vessel(inset: 2));
    if (progress < 1) {
      _sand(
        canvas,
        Rect.fromLTRB(20, upperSurface, 200, _neck),
        surfaceRadius,
        17,
      );
    }
    if (progress > 0) {
      _sand(
        canvas,
        Rect.fromLTRB(20, lowerSurface, 200, _bottom + 1),
        surfaceRadius,
        71,
      );
    }
    if (progress > 0 && progress < 1) {
      final stream = Rect.fromLTRB(108.6, _neck, 111.4, lowerSurface);
      canvas.drawRect(
        stream,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_white.withValues(alpha: 0.88), _warm.withValues(alpha: 0.2)],
          ).createShader(stream),
      );
      for (var i = 0; i < 9; i++) {
        final travel = (motion.value + i / 9) % 1;
        canvas.drawCircle(
          Offset(
            _center + math.sin(i * 2.4) * 1.5,
            _neck + (lowerSurface - _neck) * travel,
          ),
          i.isEven ? 0.85 : 0.5,
          Paint()..color = _white.withValues(alpha: 0.9),
        );
      }
    }
    canvas.restore();

    // Two distinct rims of the glass wall remain readable on a bright sky.
    canvas.drawPath(
      glass,
      Paint()
        ..color = _shadow.withValues(alpha: 0.23)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4,
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

  void _sand(Canvas canvas, Rect bounds, double surfaceRadius, int seed) {
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF8F5EC),
            Color(0xFFD3E0E8),
            Color(0xFFF7FBFC),
          ],
          stops: [0, 0.27, 0.73, 1],
        ).createShader(bounds),
    );
    final glow = Rect.fromCenter(
      center: Offset(96, bounds.top + 5),
      width: 148,
      height: 54,
    );
    _glow(canvas, glow, _white.withValues(alpha: 0.8));
    // Static seeded micro-grains keep screenshots and reduced-motion views
    // textured. They are decorative; no grain contributes to time accounting.
    for (var i = 0; i < 145; i++) {
      final x = 20 + ((i * 73 + seed * 19) % 211) / 211 * 180;
      final y = bounds.top + ((i * 97 + seed * 23) % 223) / 223 * bounds.height;
      canvas.drawCircle(
        Offset(x, y),
        i % 4 == 0 ? 0.65 : 0.38,
        Paint()
          ..color = i.isEven
              ? _white.withValues(alpha: 0.68)
              : _shadow.withValues(alpha: 0.19),
      );
    }
    canvas.restore();
    final surface = Rect.fromCenter(
      center: Offset(_center, bounds.top),
      width: math.max(0.0, surfaceRadius * 2 - 5),
      height: 7,
    );
    canvas.drawOval(
      surface,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _warm.withValues(alpha: 0.95),
            _white,
            const Color(0xFFDCE6E9),
          ],
        ).createShader(surface),
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
      height: 16,
    );
    canvas.drawOval(
      bounds.translate(0, 3),
      Paint()
        ..color = _edge.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(bounds)
      ..addOval(Rect.fromCenter(
        center: Offset(_center, y - 0.5),
        width: bounds.width - 9,
        height: 8,
      ));
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
