import 'dart:math' as math;
import 'dart:ui' show ClipOp, PathMetric;

import 'package:flutter/material.dart';

import '../../design/bottle_geometry.dart';
import 'hourglass_placeholder.dart';

/// Geometry is measured after layout in the viewport's coordinate system.
/// It is cached between layout, scroll, and statistics updates.
class SandFlowGeometry {
  SandFlowGeometry({
    required this.source,
    required this.mouth,
    required this.bottleRect,
    required this.viewport,
    required this.bottleClip,
    required this.bottle,
    required this.obstacles,
  }) {
    final left = obstacles.fold<double>(
      math.min(source.dx, mouth.dx),
      (value, rect) => math.min(value, rect.left),
    );
    final lane = (left - 10).clamp(7.0, viewport.width - 7).toDouble();
    // Travel through the content gutter, outside captions and shelf headings.
    // The final control point shares the mouth's x, making entry vertical.
    final headingBottom = obstacles
        .where((rect) => rect.top > source.dy && rect.bottom < mouth.dy)
        .fold<double>(
          source.dy + 8,
          (bottom, rect) => math.max(bottom, rect.bottom + 4),
        );
    final approachY = math.min(
      mouth.dy - 4,
      math.max(mouth.dy - 16, headingBottom),
    );
    path = Path()
      ..moveTo(source.dx, source.dy)
      ..cubicTo(source.dx, source.dy + 4, lane, source.dy, lane, source.dy + 8)
      ..lineTo(lane, approachY)
      ..cubicTo(lane, approachY + 6, mouth.dx, approachY, mouth.dx, mouth.dy);
    metric = path.computeMetrics().first;
  }

  final Offset source;
  final Offset mouth;
  final Rect bottleRect;
  final Rect viewport;
  final Rect bottleClip;
  final GlassBottleGeometry bottle;
  final List<Rect> obstacles;
  late final Path path;
  late final PathMetric metric;

  Offset position(double fraction) => metric
      .getTangentForOffset(metric.length * fraction.clamp(0, 1))!
      .position;
}

/// Decorative flow follows persisted activeBottleId. It never writes records
/// or accumulates elapsed business time.
class SandFlowSurface extends StatefulWidget {
  const SandFlowSurface({
    required this.child,
    required this.activeBottleId,
    required this.sourceKey,
    required this.bottleKeys,
    required this.viewportKey,
    required this.obstacleKeys,
    required this.colors,
    required this.fills,
    this.enabled = true,
    this.visible = true,
    super.key,
  });

  final Widget child;
  final int? activeBottleId;
  final GlobalKey sourceKey;
  final Map<int, GlobalKey> bottleKeys;
  final GlobalKey viewportKey;
  final List<GlobalKey> obstacleKeys;
  final Map<int, Color> colors;
  final Map<int, double> fills;
  final bool enabled;
  final bool visible;

  @override
  State<SandFlowSurface> createState() => SandFlowSurfaceState();
}

class SandFlowSurfaceState extends State<SandFlowSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const maxParticles = 144;
  final _coordinateKey = GlobalKey();
  final _repaint = _FlowRepaint();
  final _particles = <_Grain>[];
  late final AnimationController _motion;
  SandFlowGeometry? _geometry;
  SandFlowGeometry? _previousGeometry;
  Color _color = Colors.white;
  Color _previousColor = Colors.white;
  int? _displayId;
  int _serial = 0;
  int _emissions = 0;
  double _spawnRemainder = 0;
  double _transition = 1;
  Duration? _lastTick;
  bool _measureQueued = false;
  bool _foreground = true;
  bool _reduceMotion = false;
  bool _tickerMode = true;

  int? get debugTargetBottleId => widget.activeBottleId;
  int get debugParticleCount => _particles.length;
  int get debugEmissionCount => _emissions;
  bool get debugIsEmitting => _canAnimate && widget.activeBottleId != null;
  bool get debugMotionRunning => _motion.isAnimating;
  bool get debugReducedMotion => _reduceMotion;
  SandFlowGeometry? get debugGeometry => _geometry;
  List<Offset> get debugParticlePositions => _geometry == null
      ? const []
      : _particles
            .where((grain) => grain.fraction < .74)
            .map((grain) {
              return _externalPosition(grain, _geometry!);
            })
            .toList(growable: false);

  bool get _canShow =>
      widget.visible && _foreground && _tickerMode && _geometry != null;
  bool get _canAnimate => _canShow && widget.enabled && !_reduceMotion;

  @override
  void initState() {
    super.initState();
    _displayId = widget.activeBottleId;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    WidgetsBinding.instance.addObserver(this);
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _tickerMode = TickerMode.valuesOf(context).enabled;
    _scheduleMeasure();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant SandFlowSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.activeBottleId;
    if (next != null && next != _displayId) {
      _previousGeometry = _geometry;
      _previousColor = _color;
      _transition = _geometry == null ? 1 : 0;
      // No old bottle continues receiving after a confirmed switch.
      _particles.removeWhere((grain) => grain.fraction >= .40);
      _displayId = next;
    }
    // When next is null keep the last target only until in-flight grains land.
    _scheduleMeasure();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _scheduleMeasure();
    _syncMotion();
  }

  void _scheduleMeasure() {
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (mounted) _measure();
    });
  }

  Rect? _bounds(GlobalKey? key, RenderBox root) {
    final render = key?.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize)
      return null;
    return Rect.fromPoints(
      root.globalToLocal(render.localToGlobal(Offset.zero)),
      root.globalToLocal(
        render.localToGlobal(render.size.bottomRight(Offset.zero)),
      ),
    );
  }

  void _measure() {
    final root = _coordinateKey.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize || !widget.visible) {
      _geometry = null;
      _syncMotion();
      _repaint.markChanged();
      return;
    }
    final viewport = Offset.zero & root.size;
    final source = _bounds(widget.sourceKey, root);
    final target = _bounds(widget.bottleKeys[_displayId], root);
    final shelf = _bounds(widget.viewportKey, root);
    if (source == null || target == null || shelf == null) {
      _geometry = null;
    } else {
      final outlet =
          source.topLeft + HourglassPlaceholder.outletFor(source.size);
      final mouth =
          target.topLeft +
          Offset(
            target.width *
                GlassBottleGeometry.mouth.dx /
                GlassBottleGeometry.designSize.width,
            target.height *
                GlassBottleGeometry.mouth.dy /
                GlassBottleGeometry.designSize.height,
          );
      final visibleShelf = viewport.intersect(shelf);
      if (!viewport.deflate(2).contains(outlet) ||
          !visibleShelf.deflate(2).contains(mouth)) {
        _geometry = null;
      } else {
        _geometry = SandFlowGeometry(
          source: outlet,
          mouth: mouth,
          bottleRect: target,
          viewport: viewport,
          bottleClip: visibleShelf.intersect(target),
          bottle: GlassBottleGeometry(widget.fills[_displayId] ?? 0),
          obstacles: [
            for (final key in widget.obstacleKeys)
              if (_bounds(key, root) case final Rect rect) rect.inflate(3),
          ],
        );
        _color = (widget.colors[_displayId] ?? Colors.white).withValues(
          alpha: 1,
        );
      }
    }
    _syncMotion();
    _repaint.markChanged();
  }

  void _syncMotion() {
    if (!_canAnimate) {
      _motion.stop();
      _lastTick = null;
      _particles.clear();
      _spawnRemainder = 0;
      _previousGeometry = null;
      _transition = 1;
      return;
    }
    if (widget.activeBottleId != null || _particles.isNotEmpty) {
      if (!_motion.isAnimating) {
        _lastTick = null;
        _motion.repeat();
      }
    } else {
      _motion.stop();
      _lastTick = null;
      _displayId = null;
    }
  }

  void _tick() {
    final elapsed = _motion.lastElapsedDuration;
    if (elapsed == null) return;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    if (dt <= 0) return;
    for (final grain in _particles) {
      grain.age += dt;
    }
    _particles.removeWhere((grain) => grain.fraction >= 1);
    _transition = math.min(1, _transition + dt / .45);
    if (_transition == 1) _previousGeometry = null;
    if (debugIsEmitting) {
      // Cap emission on slow frames; never replay a backlog after suspension.
      _spawnRemainder += math.min(dt, .05) * 76;
      while (_spawnRemainder >= 1 && _particles.length < maxParticles) {
        _particles.add(_Grain(_serial++));
        _emissions++;
        _spawnRemainder--;
      }
      if (_particles.length == maxParticles) _spawnRemainder = 0;
    } else {
      _spawnRemainder = 0;
    }
    if (widget.activeBottleId == null && _particles.isEmpty) _syncMotion();
    _repaint.markChanged();
  }

  Offset _externalPosition(_Grain grain, SandFlowGeometry geometry) {
    final progress = (grain.fraction / .74).clamp(0.0, 1.0);
    var point = geometry.position(progress);
    final old = _previousGeometry;
    if (old != null && _transition < 1) {
      point = Offset.lerp(
        old.position(progress),
        point,
        Curves.easeInOut.transform(_transition),
      )!;
    }
    final sway =
        math.sin(grain.age * 12 + grain.seed) *
        math.sin(math.pi * progress) *
        1.35;
    return point + Offset(sway, 0);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleMeasure();
        return false;
      },
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleMeasure();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: Stack(
            key: _coordinateKey,
            fit: StackFit.expand,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SandFlowPainter(this, _repaint),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _repaint.dispose();
    super.dispose();
  }
}

class _Grain {
  _Grain(this.seed) : lifetime = 1.55 + (seed % 10) * .03;
  final int seed;
  final double lifetime;
  double age = 0;
  double get fraction => age / lifetime;
}

class _SandFlowPainter extends CustomPainter {
  _SandFlowPainter(this.state, Listenable repaint) : super(repaint: repaint);
  final SandFlowSurfaceState state;
  final _grainPaint = Paint();
  final _glowPaint = Paint();
  final _depthPaint = Paint()..color = const Color(0x25315D79);

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = state._geometry;
    if (geometry == null || !state._canShow) return;
    final active = state.widget.activeBottleId != null;
    if (!active && state._particles.isEmpty) return;
    final color = Color.lerp(
      state._previousColor,
      state._color,
      state._transition,
    )!;
    canvas.save();
    canvas.clipRect(geometry.viewport);
    // This layer spans cards but cannot draw over captions, buttons, or nav.
    for (final rect in geometry.obstacles) {
      canvas.clipRect(rect, clipOp: ClipOp.difference);
    }
    if (state._reduceMotion || !state.widget.enabled) {
      if (active) {
        for (var i = 0; i <= 22; i++) {
          final p = i / 22;
          _grainPaint.color = Color.lerp(
            Colors.white,
            color,
            math.max(0, (p - .65) / .35),
          )!.withValues(alpha: .8);
          canvas.drawCircle(geometry.position(p), 1.05, _grainPaint);
        }
        final end = geometry.mouth - const Offset(0, 6);
        _grainPaint
          ..color = color.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3;
        canvas.drawPath(
          Path()
            ..moveTo(end.dx - 3, end.dy - 3)
            ..lineTo(end.dx, end.dy)
            ..lineTo(end.dx + 3, end.dy - 3),
          _grainPaint,
        );
        _grainPaint.style = PaintingStyle.fill;
      }
    } else {
      for (final grain in state._particles) {
        if (grain.fraction >= .74) continue;
        final point = state._externalPosition(grain, geometry);
        final progress = grain.fraction / .74;
        final tint = Color.lerp(
          const Color(0xFFFFFCF1),
          color,
          ((progress - .65) / .35).clamp(0.0, 1.0),
        )!;
        final radius = .7 + (grain.seed % 5) * .17;
        _glowPaint.color = tint.withValues(alpha: .15);
        canvas.drawCircle(point, radius * 2.6, _glowPaint);
        canvas.drawCircle(
          point + const Offset(0, .35),
          radius * 1.55,
          _depthPaint,
        );
        _grainPaint.color = tint.withValues(alpha: .94);
        canvas.drawCircle(point, radius, _grainPaint);
      }
    }
    canvas.restore();

    // Interior particles are clipped by the exact same vessel geometry used by
    // the bottle painter. The sand surface remains the real statistics surface.
    canvas.save();
    canvas.clipRect(geometry.bottleClip);
    canvas.translate(geometry.bottleRect.left, geometry.bottleRect.top);
    canvas.scale(
      geometry.bottleRect.width / 98,
      geometry.bottleRect.height / 140,
    );
    canvas.clipPath(geometry.bottle.interior);
    for (final grain in state._particles) {
      final p = grain.fraction;
      if (p < .74) continue;
      double x;
      double y;
      double alpha;
      if (p < .92) {
        final fall = (p - .74) / .18;
        x =
            49 +
            math.sin(grain.seed * 2.1 + fall * 5) *
                .75 *
                math.sin(math.pi * fall);
        y = 15 + (geometry.bottle.surfaceY - 15) * fall;
        alpha = .9;
      } else {
        final landing = (p - .92) / .08;
        final direction = grain.seed.isEven ? 1 : -1;
        x = 49 + direction * landing * (3 + grain.seed % 5);
        y = geometry.bottle.surfaceY - math.sin(landing * math.pi) * 3;
        alpha = (1 - landing) * .8;
      }
      _grainPaint.color = Color.lerp(
        color,
        Colors.white,
        .7,
      )!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), .85 + grain.seed % 3 * .15, _grainPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SandFlowPainter oldDelegate) =>
      oldDelegate.state != state;
}

class _FlowRepaint extends ChangeNotifier {
  void markChanged() => notifyListeners();
}
