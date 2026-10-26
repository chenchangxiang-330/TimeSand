import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timesand/design/bottle_geometry.dart';
import 'package:timesand/features/hourglass/sand_flow.dart';

void main() {
  test('unequal route lengths cannot cut through headings during switches', () {
    final previous = _geometry(104);
    final destination = _geometry(260);
    const elapsed = .23;
    const transition = elapsed / .45;
    const particleProgress = (.39 + elapsed / 1.55) / .74;
    final heading = destination.obstacles.last;

    // This fixture reproduces the old shortcut through the shelf heading:
    // one path turns toward the bottle while the other remains vertical.
    final shortcut = Offset.lerp(
      previous.position(particleProgress),
      destination.position(particleProgress),
      Curves.easeInOut.transform(transition),
    )!;
    expect(heading.contains(shortcut), isTrue);

    final route = destination.retargetFrom(previous, transition);
    expect(
      heading.contains(route.position(particleProgress)),
      isFalse,
      reason: 'A surviving grain must follow the gutter during retargeting.',
    );
    _expectClearRoute(route);
  });

  for (final wide in [false, true]) {
    for (final reverse in [false, true]) {
      test('retarget avoids captions: wide=$wide reverse=$reverse', () {
        final left = wide ? 300.0 : 104.0;
        final right = wide ? 850.0 : 260.0;
        final previous = _geometry(reverse ? right : left, wide: wide);
        final destination = _geometry(reverse ? left : right, wide: wide);

        for (var frame = 0; frame <= 30; frame++) {
          final route = destination.retargetFrom(previous, frame / 30);
          _expectClearRoute(route);
          expect(
            (route.position(0) - destination.source).distance,
            lessThan(.05),
          );
          expect((route.position(1) - route.mouth).distance, lessThan(.05));
          final endDirection =
              route.metric.getTangentForOffset(route.metric.length)!.vector;
          expect(endDirection.dx.abs(), lessThan(.001));
          expect(endDirection.dy, greaterThan(0));
          // Only the flight route moves; landing and fill remain tied to the
          // actual destination bottle throughout the transition.
          expect(route.bottleRect, destination.bottleRect);
          expect(route.bottle, same(destination.bottle));
        }
      });
    }
  }

  test('resizing during retarget uses the current source and shelf height', () {
    final previous = _geometry(104);
    final destination = _geometry(260, verticalOffset: 40);
    final route = destination.retargetFrom(previous, .5);

    expect(route.source, destination.source);
    expect(route.mouth, Offset(182, destination.mouth.dy));
    _expectClearRoute(route);
  });

  test('completed retarget reuses the exact destination geometry', () {
    final previous = _geometry(104);
    final destination = _geometry(260);
    expect(destination.retargetFrom(previous, 1), same(destination));
    expect(destination.retargetFrom(previous, 2), same(destination));
  });
}

SandFlowGeometry _geometry(
  double mouthX, {
  bool wide = false,
  double verticalOffset = 0,
}) {
  final mouthY = 500.0 + verticalOffset;
  const scale = 116 / 140;
  final bottleRect = Rect.fromLTWH(
    mouthX - GlassBottleGeometry.mouth.dx * scale,
    mouthY - GlassBottleGeometry.mouth.dy * scale,
    GlassBottleGeometry.designSize.width * scale,
    GlassBottleGeometry.designSize.height * scale,
  );
  return SandFlowGeometry(
    source: Offset(wide ? 650.0 : 195.0, 280.0 + verticalOffset),
    mouth: Offset(mouthX, mouthY),
    bottleRect: bottleRect,
    viewport: Rect.fromLTWH(0, 0, wide ? 1200.0 : 390.0, 740),
    bottleClip: bottleRect,
    bottle: GlassBottleGeometry(.4),
    obstacles: [
      if (!wide)
        Rect.fromLTRB(
          13,
          295.0 + verticalOffset,
          377,
          330.0 + verticalOffset,
        ),
      Rect.fromLTRB(
        27,
        420.0 + verticalOffset,
        wide ? 1173.0 : 363.0,
        484.6 + verticalOffset,
      ),
    ],
  );
}

void _expectClearRoute(SandFlowGeometry route) {
  for (var sample = 0; sample <= 180; sample++) {
    final point = route.position(sample / 180);
    expect(
      route.obstacles.any((rect) => rect.inflate(2.8).contains(point)),
      isFalse,
      reason: 'The route needs room for the grain body and its sideways sway.',
    );
    expect(route.viewport.contains(point), isTrue);
  }
}
