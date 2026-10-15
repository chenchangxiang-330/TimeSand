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
        TickerMode.of(context);
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
  static const _edge = Color(0xFFB7D5E3);
  static const _shadow = Color(0xFF163344);
  static const _center = 110.0;
  static const _top = 31.0;
  static const _neck = 158.0;
  static const _bottom = 285.0;
  static const _radius = 73.0;
  static const _neckRadius = 5.0;

  Path _vessel(double radius, double neckRadius) {
    const chamberHeight = _neck - _top;
    return Path()
      ..moveTo(_center - radius, _top)
      ..lineTo(_center + radius, _top)
      ..cubicTo(
        _center + radius,
        _top + chamberHeight / 3,
        _center + neckRadius,
        _neck - chamberHeight / 3,
        _center + neckRadius,
        _neck,
      )
      ..cubicTo(
        _center + neckRadius,
        _neck + chamberHeight / 3,
        _center + radius,
        _bottom - chamberHeight / 3,
        _center + radius,
        _bottom,
      )
      ..lineTo(_center - radius, _bottom)
      ..cubicTo(
        _center - radius,
        _bottom - chamberHeight / 3,
        _center - neckRadius,
        _neck + chamberHeight / 3,
        _center - neckRadius,
        _neck,
      )
      ..cubicTo(
        _center - neckRadius,
        _neck - chamberHeight / 3,
        _center - radius,
        _top + chamberHeight / 3,
        _center - radius,
        _top,
      )
      ..close();
  }

  // Invert the integrated cross-section of the cubic glass curve. This keeps
  // the combined upper/lower sand area constant as the real progress changes.
  double _levelForVolume(double fraction) {
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 24; i++) {
      final t = (low + high) / 2;
      final area =
          _neckRadius * t +
          (_radius - _neckRadius) * (t * t * t - 0.5 * t * t * t * t);
      final ratio = area / ((_radius + _neckRadius) / 2);
      if (ratio < fraction) {
        low = t;
      } else {
        high = t;
      }
    }
    return (low + high) / 2;
  }

  double _radiusAt(double level) =>
      _neckRadius +
      (_radius - _neckRadius) * (3 * level * level - 2 * level * level * level);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 320);
    final glass = _vessel(_radius, _neckRadius);
    const bodyBounds = Rect.fromLTWH(35, 29, 150, 258);

    // Soft contact shadow and a subtle halo are gradients, not blurred layers.
    canvas.drawOval(
      const Rect.fromLTWH(27, 294, 166, 17),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _shadow.withValues(alpha: 0.18),
            _shadow.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTWH(27, 294, 166, 17)),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _white.withValues(alpha: 0.16),
            _edge.withValues(alpha: 0.025),
            _white.withValues(alpha: 0.07),
            _edge.withValues(alpha: 0.19),
          ],
          stops: const [0, 0.28, 0.67, 1],
        ).createShader(bodyBounds),
    );

    final level = _levelForVolume(1 - progress);
    final upperSurface = _neck - (_neck - _top) * level;
    final lowerSurface = _neck + (_bottom - _neck) * level;
    final surfaceRadius = _radiusAt(level);

    canvas.save();
    canvas.clipPath(glass);
    final sandPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFCFFFF), Color(0xFFDCEAF2), Color(0xFFF8FCFF)],
        stops: [0, 0.55, 1],
      ).createShader(bodyBounds);
    if (progress < 1) {
      canvas.drawRect(Rect.fromLTRB(35, upperSurface, 185, _neck), sandPaint);
      _sandSurface(canvas, upperSurface, surfaceRadius);
    }
    if (progress > 0) {
      canvas.drawRect(
        Rect.fromLTRB(35, lowerSurface, 185, _bottom + 1),
        sandPaint,
      );
      _sandSurface(canvas, lowerSurface, surfaceRadius);
    }

    if (progress > 0 && progress < 1) {
      final stream = Rect.fromLTRB(108.5, _neck, 111.5, lowerSurface);
      canvas.drawRect(
        stream,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _white.withValues(alpha: 0.7),
              _white.withValues(alpha: 0.1),
            ],
          ).createShader(stream),
      );
      for (var i = 0; i < 7; i++) {
        final travel = (motion.value + i / 7) % 1;
        final y = _neck + (lowerSurface - _neck) * travel;
        final x = _center + math.sin(i * 2.4) * 1.8;
        canvas.drawCircle(
          Offset(x, y),
          i.isEven ? 0.8 : 0.55,
          Paint()..color = _white.withValues(alpha: 0.7),
        );
      }
    }
    canvas.restore();

    // Transmitted edge tint and narrow, curved highlights give the glass depth.
    canvas.drawPath(
      glass,
      Paint()
        ..color = _edge.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    final leftHighlight = Path()
      ..moveTo(43, 40)
      ..cubicTo(46, 90, 91, 116, 101, 145);
    final lowerHighlight = Path()
      ..moveTo(101, 173)
      ..cubicTo(92, 207, 48, 234, 43, 274);
    for (final path in [leftHighlight, lowerHighlight]) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _white.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(176, 45)
        ..cubicTo(168, 91, 133, 124, 120, 147),
      Paint()
        ..color = _white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    _rim(canvas, _top, _radius + 4);
    _rim(canvas, _bottom, _radius + 4);
    canvas.restore();
  }

  void _sandSurface(Canvas canvas, double y, double radius) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_center, y), width: radius * 2, height: 5),
      Paint()..color = _white.withValues(alpha: 0.83),
    );
  }

  void _rim(Canvas canvas, double y, double radius) {
    final bounds = Rect.fromCenter(
      center: Offset(_center, y),
      width: radius * 2,
      height: 14,
    );
    canvas.drawOval(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _white.withValues(alpha: 0.72),
            _edge.withValues(alpha: 0.13),
            _white.withValues(alpha: 0.44),
          ],
        ).createShader(bounds),
    );
    canvas.drawOval(
      bounds,
      Paint()
        ..color = _edge.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      bounds.deflate(2),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_GlassHourglassPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.motion != motion;
}
