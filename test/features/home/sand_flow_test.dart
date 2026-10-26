import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/design/bottle_geometry.dart';
import 'package:timesand/design/glass_bottle.dart';
import 'package:timesand/features/bottles/bottle_detail_page.dart';
import 'package:timesand/features/home/home_page.dart';
import 'package:timesand/features/hourglass/hourglass_placeholder.dart';
import 'package:timesand/features/hourglass/sand_flow.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;
  late _Clock clock;
  late List<Bottle> bottles;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
    clock = _Clock();
    bottles = [
      await repository.createBottle(
        name: '学习',
        color: 0xFF8EBCA8,
        now: clock.now,
      ),
      await repository.createBottle(
        name: '创作',
        color: 0xFFC6A1D1,
        now: clock.now.add(const Duration(seconds: 1)),
      ),
    ];
  });
  tearDown(() => database.close());

  testWidgets('flow follows persisted active ID, never the selected bottle', (
    tester,
  ) async {
    await _pumpHome(tester, repository, clock);
    expect(_flow(tester).debugIsEmitting, isFalse);
    expect(_flow(tester).debugParticleCount, 0);

    await _tap(tester, _idKey('start-', bottles.first.id!));
    await _until(tester, () => _flow(tester).debugIsEmitting);
    await _frames(tester, const Duration(milliseconds: 1200));
    final active = (await repository.fetchActiveEntry())!;
    final flow = _flow(tester);
    expect(active.bottleId, bottles.first.id);
    expect(flow.debugTargetBottleId, active.bottleId);
    expect(flow.debugParticleCount, greaterThan(0));
    final emissions = flow.debugEmissionCount;

    await _tap(tester, _idKey('select-bottle-', bottles.last.id!));
    await _frames(tester, const Duration(milliseconds: 100));
    expect((await repository.fetchActiveEntry())!.id, active.id);
    expect(flow.debugTargetBottleId, bottles.first.id);
    expect(flow.debugEmissionCount, greaterThan(emissions));
    expect(find.byType(SandFlowSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a rejected start never emits sand or invents an active entry', (
    tester,
  ) async {
    final failing = _RejectedStartRepository(database);
    await _pumpHome(tester, failing, clock);
    await _tap(tester, _idKey('start-', bottles.first.id!));
    await _until(tester, () => find.text('测试启动失败').evaluate().isNotEmpty);
    await _frames(tester, const Duration(seconds: 1));

    expect(await repository.fetchActiveEntry(), isNull);
    expect(await repository.fetchEntries(), isEmpty);
    expect(_flow(tester).debugTargetBottleId, isNull);
    expect(_flow(tester).debugIsEmitting, isFalse);
    expect(_flow(tester).debugParticleCount, 0);
    expect(_flow(tester).debugEmissionCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'stop disables emission immediately and lets existing sand drain',
    (tester) async {
      await _pumpHome(tester, repository, clock);
      await _tap(tester, _idKey('start-', bottles.first.id!));
      await _until(tester, () => _flow(tester).debugIsEmitting);
      await _frames(tester, const Duration(milliseconds: 1200));
      expect(_flow(tester).debugParticleCount, greaterThan(0));

      clock.advance(const Duration(seconds: 2));
      await _tap(tester, find.byKey(const ValueKey('stop-timer-button')));
      await _until(
        tester,
        () =>
            tester
                .widget<SandFlowSurface>(find.byType(SandFlowSurface))
                .activeBottleId ==
            null,
      );
      final flow = _flow(tester);
      expect(await repository.fetchActiveEntry(), isNull);
      expect(flow.debugIsEmitting, isFalse);
      expect(flow.debugParticleCount, greaterThan(0));
      final emissions = flow.debugEmissionCount;
      await _frames(tester, const Duration(seconds: 2));

      expect(flow.debugParticleCount, 0);
      expect(flow.debugEmissionCount, emissions);
      expect(flow.debugMotionRunning, isFalse);
      final entry = (await repository.fetchEntries()).single;
      expect(entry.durationSeconds, 2);
      expect(entry.bottleId, bottles.first.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cancel switch preserves flow; confirmed switch is nonoverlapping',
    (tester) async {
      await _pumpHome(tester, repository, clock);
      await _tap(tester, _idKey('start-', bottles.first.id!));
      await _until(tester, () => _flow(tester).debugIsEmitting);
      await _frames(tester, const Duration(milliseconds: 600));
      final first = (await repository.fetchActiveEntry())!;

      await _tap(tester, _idKey('start-', bottles.last.id!));
      await _until(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
      );
      expect((await repository.fetchActiveEntry())!.id, first.id);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, '取消'),
        ),
      );
      await _frames(tester, const Duration(milliseconds: 300));
      expect((await repository.fetchActiveEntry())!.id, first.id);
      expect(_flow(tester).debugTargetBottleId, bottles.first.id);

      clock.advance(const Duration(seconds: 2));
      await _tap(tester, _idKey('start-', bottles.last.id!));
      await _until(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-switch-timer')));
      await _until(
        tester,
        () => _flow(tester).debugTargetBottleId == bottles.last.id,
      );
      await _frames(tester, const Duration(milliseconds: 600));

      final entries = await repository.fetchEntries();
      final active = (await repository.fetchActiveEntry())!;
      expect(entries, hasLength(2));
      expect(entries.where((entry) => entry.isActive), hasLength(1));
      expect(entries.first.id, first.id);
      expect(entries.first.endedAt, active.startedAt);
      expect(entries.first.durationSeconds, 2);
      expect(active.bottleId, bottles.last.id);
      expect(find.byType(SandFlowSurface), findsOneWidget);
      expect(_flow(tester).debugTargetBottleId, active.bottleId);
      expect(_flow(tester).debugParticleCount, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rapid repeated start keeps one database entry and one flow', (
    tester,
  ) async {
    await _pumpHome(tester, repository, clock);
    final start = _idKey('start-', bottles.first.id!);
    if (start.hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(start);
      await tester.pump();
    }
    await tester.tap(start);
    await tester.tap(start);
    await _until(tester, () => _flow(tester).debugIsEmitting);
    await _frames(tester, const Duration(milliseconds: 600));

    expect(await repository.fetchEntries(), hasLength(1));
    expect(find.byType(SandFlowSurface), findsOneWidget);
    expect(_flow(tester).debugTargetBottleId, bottles.first.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'restored persisted timer resumes flow toward its actual bottle',
    (tester) async {
      final restored = await repository.startTimer(
        bottleId: bottles.last.id!,
        startedAt: clock.now.subtract(const Duration(minutes: 20)),
      );
      await _pumpHome(tester, TimeRecordsRepository(database), clock);
      await _until(tester, () => _flow(tester).debugIsEmitting);
      await _frames(tester, const Duration(milliseconds: 600));

      expect((await repository.fetchActiveEntry())!.id, restored.id);
      expect(_flow(tester).debugTargetBottleId, bottles.last.id);
      expect(_flow(tester).debugParticleCount, greaterThan(0));
      expect(find.byKey(const ValueKey('stop-timer-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [const Size(390, 844), const Size(1440, 960)]) {
    testWidgets('anchors match actual widgets at $size and after resizing', (
      tester,
    ) async {
      await repository.startTimer(
        bottleId: bottles.first.id!,
        startedAt: clock.now.subtract(const Duration(minutes: 1)),
      );
      await _pumpHome(tester, repository, clock, size: size);
      await _until(tester, () => _flow(tester).debugGeometry != null);
      _expectAnchors(tester, bottles.first.id!);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      final resized = size.width < 1000
          ? const Size(1440, 960)
          : const Size(390, 844);
      tester.view.physicalSize = resized;
      await tester.binding.setSurfaceSize(resized);
      await _frames(tester, const Duration(milliseconds: 100));
      await _until(tester, () => _flow(tester).debugGeometry != null);
      _expectAnchors(tester, bottles.first.id!);
      expect(_flow(tester).debugTargetBottleId, bottles.first.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('flow overlay does not intercept taps on the bottle body', (
    tester,
  ) async {
    await repository.startTimer(
      bottleId: bottles.first.id!,
      startedAt: clock.now.subtract(const Duration(minutes: 1)),
    );
    await _pumpHome(tester, repository, clock);
    await _until(tester, () => _flow(tester).debugIsEmitting);
    final bottle = _bottle(tester, bottles.first.id!);
    await tester.tapAt(tester.getCenter(bottle));
    await _until(
      tester,
      () => find.byType(BottleDetailPage).evaluate().isNotEmpty,
    );
    await _frames(tester, const Duration(milliseconds: 350));

    expect(find.byType(BottleDetailPage), findsOneWidget);
    expect((await repository.fetchActiveEntry())!.bottleId, bottles.first.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('scrolling source offscreen pauses decorative work and resumes', (
    tester,
  ) async {
    await repository.startTimer(
      bottleId: bottles.first.id!,
      startedAt: clock.now.subtract(const Duration(minutes: 1)),
    );
    await _pumpHome(tester, repository, clock);
    await _until(tester, () => _flow(tester).debugIsEmitting);
    await _frames(tester, const Duration(milliseconds: 600));
    final flow = _flow(tester);
    tester.view.physicalSize = const Size(390, 420);
    await tester.binding.setSurfaceSize(const Size(390, 420));
    await tester.pump();
    final scroll = tester
        .widget<SingleChildScrollView>(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is SingleChildScrollView &&
                    widget.controller != null,
              )
              .first,
        )
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await _frames(tester, const Duration(milliseconds: 100));
    expect(flow.debugMotionRunning, isFalse);
    final emissions = flow.debugEmissionCount;
    final particles = flow.debugParticleCount;
    await _frames(tester, const Duration(seconds: 2));
    expect(flow.debugEmissionCount, emissions);
    expect(flow.debugParticleCount, lessThanOrEqualTo(particles));
    expect(await repository.fetchActiveEntry(), isNotNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();
    scroll.jumpTo(0);
    await _until(tester, () => flow.debugIsEmitting);
    await _frames(tester, const Duration(milliseconds: 100));
    expect(flow.debugEmissionCount, greaterThan(emissions));
    _expectAnchors(tester, bottles.first.id!);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reduced motion preserves the timer without scheduling flow frames',
    (tester) async {
      final active = await repository.startTimer(
        bottleId: bottles.first.id!,
        startedAt: clock.now.subtract(const Duration(minutes: 1)),
      );
      await _pumpHome(tester, repository, clock, disableAnimations: true);
      await _frames(tester, const Duration(milliseconds: 600));
      final flow = _flow(tester);
      expect(flow.debugReducedMotion, isTrue);
      expect(flow.debugMotionRunning, isFalse);
      expect(flow.debugParticleCount, 0);
      expect(flow.debugEmissionCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect((await repository.fetchActiveEntry())!.id, active.id);
      expect(find.byKey(const ValueKey('stop-timer-button')), findsOneWidget);
      await _frames(tester, const Duration(seconds: 2));
      expect(flow.debugEmissionCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'leaving home and backgrounding keep timer data but stop flow work',
    (tester) async {
      final active = await repository.startTimer(
        bottleId: bottles.first.id!,
        startedAt: clock.now.subtract(const Duration(minutes: 1)),
      );
      await _pumpHome(tester, repository, clock);
      await _until(tester, () => _flow(tester).debugIsEmitting);
      await tester.tap(find.byKey(const ValueKey('nav-history')));
      await _frames(tester, const Duration(milliseconds: 600));
      if (find.byType(SandFlowSurface).evaluate().isNotEmpty) {
        expect(_flow(tester).debugMotionRunning, isFalse);
      }
      expect((await repository.fetchActiveEntry())!.id, active.id);

      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await _until(tester, () => _flow(tester).debugIsEmitting);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _frames(tester, const Duration(milliseconds: 100));
      expect(_flow(tester).debugMotionRunning, isFalse);
      final emissions = _flow(tester).debugEmissionCount;
      await _frames(tester, const Duration(seconds: 2));
      expect(_flow(tester).debugEmissionCount, emissions);
      expect((await repository.fetchActiveEntry())!.id, active.id);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _until(tester, () => _flow(tester).debugIsEmitting);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Clock {
  DateTime now = DateTime(2026, 10, 27, 15, 20);
  void advance(Duration delta) => now = now.add(delta);
}

class _RejectedStartRepository extends TimeRecordsRepository {
  _RejectedStartRepository(super.database);

  @override
  Future<TimeEntry> startTimer({
    required int bottleId,
    DateTime? startedAt,
  }) async {
    throw const _StartFailure();
  }
}

class _StartFailure implements Exception {
  const _StartFailure();
  @override
  String toString() => '测试启动失败';
}

Finder _idKey(String prefix, int id) => find.byKey(ValueKey('$prefix$id'));

SandFlowSurfaceState _flow(WidgetTester tester) =>
    tester.state<SandFlowSurfaceState>(find.byType(SandFlowSurface));

Finder _bottle(WidgetTester tester, int id) => find.descendant(
  of: _idKey('bottle-detail-', id),
  matching: find.byType(GlassBottle),
);

Future<void> _pumpHome(
  WidgetTester tester,
  TimeRecordsRepository repository,
  _Clock clock, {
  Size size = const Size(390, 844),
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: HomePage(
        repository: repository,
        enableTicker: false,
        enableFlowAnimation: true,
        clock: () => clock.now,
      ),
    ),
  );
  await _until(
    tester,
    () =>
        find
            .byKey(const ValueKey('primary-timer-button'))
            .evaluate()
            .isNotEmpty &&
        find.byType(SandFlowSurface).evaluate().isNotEmpty,
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
    await tester.pump();
  }
  await tester.tap(target);
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: 'The bounded UI transition must finish.');
}

Future<void> _frames(WidgetTester tester, Duration duration) async {
  var remaining = duration.inMicroseconds;
  while (remaining > 0) {
    final micros = remaining < 16000 ? remaining : 16000;
    await tester.pump(Duration(microseconds: micros));
    remaining -= micros;
  }
}

void _expectAnchors(WidgetTester tester, int bottleId) {
  final flow = _flow(tester);
  final geometry = flow.debugGeometry;
  expect(geometry, isNotNull);
  final origin = tester.getTopLeft(find.byType(SandFlowSurface));
  final hourglass = find.byType(HourglassPlaceholder);
  final expectedSource =
      tester.getTopLeft(hourglass) +
      HourglassPlaceholder.outletFor(tester.getSize(hourglass));
  final bottle = _bottle(tester, bottleId);
  final bottleRect = tester.getRect(bottle);
  final expectedMouth =
      bottleRect.topLeft +
      Offset(
        GlassBottleGeometry.mouth.dx *
            bottleRect.width /
            GlassBottleGeometry.designSize.width,
        GlassBottleGeometry.mouth.dy *
            bottleRect.height /
            GlassBottleGeometry.designSize.height,
      );
  expect((origin + geometry!.source - expectedSource).distance, lessThan(.5));
  expect((origin + geometry.mouth - expectedMouth).distance, lessThan(.5));
  expect(
    (geometry.bottleRect.topLeft + origin - bottleRect.topLeft).distance,
    lessThan(.5),
  );
  expect(geometry.bottleRect.size, bottleRect.size);
  for (var sample = 0; sample <= 180; sample++) {
    final point = geometry.position(sample / 180);
    expect(
      geometry.obstacles.any((rect) => rect.contains(point)),
      isFalse,
      reason: 'The continuous stream must route outside text, not be clipped by it.',
    );
  }
}
