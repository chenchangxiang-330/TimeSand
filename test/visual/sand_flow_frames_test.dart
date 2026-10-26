import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/features/home/home_page.dart';
import 'package:timesand/features/hourglass/sand_flow.dart';

// These frames are actual production widgets driven by UI taps and an in-memory
// database. Only sample records, the clock and screenshot fonts are test fixtures.
final _enabled = Platform.environment['RUN_UI_SCREENSHOTS'] == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_enabled) {
    setUpAll(() async {
      sqfliteFfiInit();
      await _loadScreenshotFonts();
    });
  }

  for (final viewport in <String, Size>{
    'phone': const Size(390, 844),
    'desktop': const Size(1440, 960),
  }.entries) {
    testWidgets('captures continuous sand flow on ' + viewport.key, (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.value;
      await tester.binding.setSurfaceSize(viewport.value);
      addTearDown(() async {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        await tester.binding.setSurfaceSize(null);
      });

      final database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final repository = TimeRecordsRepository(database);
      var now = DateTime(2026, 10, 27, 15, 20);
      final learningId = await _seedData(repository, now);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: HomePage(
              repository: repository,
              clock: () => now,
              enableTicker: true,
              enableFlowAnimation: true,
            ),
          ),
        ),
      );
      await _until(
        tester,
        () => find.byKey(ValueKey('start-$learningId')).evaluate().isNotEmpty,
      );
      Object? imageError;
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/scenes/coastal-sunrise.jpg'),
          tester.element(find.byType(HomePage)),
          onError: (error, stackTrace) => imageError = error,
        ),
      );
      expect(imageError, isNull, reason: 'Capture must use the real scene.');
      await tester.pump();
      await tester.pump();
      expect(await repository.fetchActiveEntry(), isNull);
      expect(_flow(tester).debugParticleCount, 0);
      await _saveFrame(
        tester,
        boundaryKey,
        viewport.value,
        'sand-flow-' + viewport.key + '-00-idle',
      );

      // Start 学习 through its real button; do not seed an active timer.
      final start = find.byKey(ValueKey('start-$learningId'));
      expect(start.hitTestable(), findsOneWidget);
      await tester.tap(start);
      await _until(tester, () => _flow(tester).debugIsEmitting);
      expect((await repository.fetchActiveEntry())!.bottleId, learningId);
      expect(_flow(tester).debugTargetBottleId, learningId);
      final initialEmissions = _flow(tester).debugEmissionCount;

      final samples = [
        (advance: 600, name: '01-running-0600ms'),
        (advance: 600, name: '02-running-1200ms'),
        (advance: 800, name: '03-running-2000ms'),
      ];
      var elapsedMilliseconds = 0;
      final runningBytes = <List<int>>[];
      for (final sample in samples) {
        elapsedMilliseconds += sample.advance;
        now = DateTime(
          2026,
          10,
          27,
          15,
          20,
        ).add(Duration(milliseconds: elapsedMilliseconds));
        await _frames(tester, Duration(milliseconds: sample.advance));
        expect(_flow(tester).debugParticleCount, greaterThan(0));
        expect(_flow(tester).debugIsEmitting, isTrue);
        expect(_flow(tester).debugTargetBottleId, learningId);
        expect(tester.takeException(), isNull);
        runningBytes.add(
          await _saveFrame(
            tester,
            boundaryKey,
            viewport.value,
            'sand-flow-' + viewport.key + '-' + sample.name,
          ),
        );
      }
      expect(_flow(tester).debugEmissionCount, greaterThan(initialEmissions));
      // A repeated static overlay cannot satisfy the sequential frame evidence.
      expect(runningBytes[0], isNot(orderedEquals(runningBytes[1])));
      expect(runningBytes[1], isNot(orderedEquals(runningBytes[2])));

      await tester.tap(find.byKey(const ValueKey('stop-timer-button')));
      await _until(
        tester,
        () =>
            tester
                .widget<SandFlowSurface>(find.byType(SandFlowSurface))
                .activeBottleId ==
            null,
      );
      expect(await repository.fetchActiveEntry(), isNull);
      expect(_flow(tester).debugIsEmitting, isFalse);
      expect(_flow(tester).debugParticleCount, greaterThan(0));
      final stoppedEmissions = _flow(tester).debugEmissionCount;
      await _frames(tester, const Duration(milliseconds: 250));
      await _saveFrame(
        tester,
        boundaryKey,
        viewport.value,
        'sand-flow-' + viewport.key + '-04-draining-0250ms',
      );
      await _frames(tester, const Duration(milliseconds: 1750));
      expect(_flow(tester).debugParticleCount, 0);
      expect(_flow(tester).debugEmissionCount, stoppedEmissions);
      expect(_flow(tester).debugMotionRunning, isFalse);
      await _saveFrame(
        tester,
        boundaryKey,
        viewport.value,
        'sand-flow-' + viewport.key + '-05-stopped-2000ms',
      );
      final entries = await repository.fetchEntries();
      expect(entries, hasLength(5));
      expect(entries.where((entry) => entry.isActive), isEmpty);
      expect(entries.last.bottleId, learningId);
      expect(entries.last.durationSeconds, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, skip: !_enabled);
  }
}

SandFlowSurfaceState _flow(WidgetTester tester) =>
    tester.state<SandFlowSurfaceState>(find.byType(SandFlowSurface));

Future<int> _seedData(TimeRecordsRepository repository, DateTime now) async {
  const names = ['学习', '专注工作', '运动健康', '灵感创作'];
  const colors = [0xFF8EBCA8, 0xFF8FA6D7, 0xFFE9B782, 0xFFC6A1D1];
  const minutes = [70, 105, 40, 50];
  var learningId = 0;
  for (var index = 0; index < names.length; index++) {
    final bottle = await repository.createBottle(
      name: names[index],
      color: colors[index],
      now: DateTime(2026, 10, 1).add(Duration(seconds: index)),
    );
    if (index == 0) learningId = bottle.id!;
    final start = DateTime(now.year, now.month, now.day, 6 + index * 2);
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes[index])),
    );
  }
  return learningId;
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

Future<List<int>> _saveFrame(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Size size,
  String name,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  List<int>? pixels;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(image.width, size.width.toInt());
      expect(image.height, size.height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final png = bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      pixels = List<int>.of(png);
      final directory = Directory('build/ui-screenshots');
      await directory.create(recursive: true);
      await File(directory.path + '/$name.png').writeAsBytes(png, flush: true);
    } finally {
      image.dispose();
    }
  });
  return pixels!;
}

Future<void> _loadScreenshotFonts() async {
  final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
  expect(icons.lengthInBytes, greaterThan(10000));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(icons));
  await materialIcons.load();
  await _loadFont(
    'Roboto',
    environmentKey: 'ROBOTO_FONT',
    candidates: const [
      '/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Regular.ttf',
      '/usr/share/fonts/truetype/roboto/unhinted/Roboto-Regular.ttf',
      '/usr/share/fonts/truetype/roboto/Roboto-Regular.ttf',
    ],
  );
  await _loadFont(
    'NotoSansSC',
    environmentKey: 'NOTO_SANS_CJK_FONT',
    candidates: const [
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
    ],
  );
}

Future<void> _loadFont(
  String family, {
  required String environmentKey,
  required List<String> candidates,
}) async {
  final configured = Platform.environment[environmentKey];
  final paths = [
    if (configured != null && configured.isNotEmpty) configured,
    ...candidates,
  ];
  for (final path in paths) {
    final file = File(path);
    if (!await file.exists()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    return;
  }
  throw StateError(
    'Missing $family screenshot font. Install fonts-roboto and fonts-noto-cjk '
    'on the cloud runner, or configure $environmentKey.',
  );
}
