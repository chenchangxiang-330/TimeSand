import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared bottle geometry in a 98 by 140 design coordinate system.
///
/// Consumers scale these paths with [designSize]. The sand surface is resolved
/// against the same clipped interior used by the bottle painter, so an incoming
/// stream can stop at the real surface rather than an estimated fill height.
/// Treat the returned paths as read-only.
class GlassBottleGeometry {
  GlassBottleGeometry(double fill)
    : fraction = fill.isFinite ? fill.clamp(0.0, 1.0).toDouble() : 0.0;

  static const Size designSize = Size(98, 140);
  static const Offset mouth = Offset(49, 15);

  final double fraction;

  late final Path exterior = _vessel(0);
  late final Path interior = _vessel(2.5);
  late final Path wall = Path.combine(
    PathOperation.difference,
    exterior,
    interior,
  );
  late final _BottleSand _sand = _createSandShape();

  Path get sandFill => _sand.fill;
  Path get sandSurface => _sand.surface;
  Path get sandCap => _sand.cap;
  double get surfaceY => _sand.centerY;

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
    final curvature = 6.0 * math.sin(math.pi * fraction);
    // Sample the real clipped interior, including its shoulder and rounded foot.
    // This work runs once per geometry instance, not on animation frames.
    final widths = List<double>.generate(slices, (i) {
      final y = top + (i + 0.5) * step;
      var low = 0.0;
      var high = 40.0;
      for (var j = 0; j < 15; j++) {
        final x = (low + high) / 2;
        if (interior.contains(Offset(49 + x, y))) {
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
      if (areaBelow(middle) > total * fraction) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final centerY = fraction >= 1 ? top : (low + high) / 2;
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
