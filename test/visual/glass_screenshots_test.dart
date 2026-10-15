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

// Screenshot fixtures are test-only sample data. They never touch the app's
// persistent database or substitute sample values in the production homepage.
final _sampleNow = DateTime(2026, 10, 15, 15, 20);
final _screenshotsEnabled =
    Platform.environment['RUN_UI_SCREENSHOTS'] == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (_screenshotsEnabled) {
    setUpAll(() async {
      sqfliteFfiInit();
      await _loadScreenshotFonts();
    });
  }

  for (final viewport in <String, Size>{
    'phone': const Size(390, 844),
    'desktop': const Size(1440, 960),
  }.entries) {
    testWidgets('renders actual glass homepage at ${viewport.key} size', (
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
      await _seedScreenshotData(repository);
      final boundaryKey = GlobalKey();

      await _pumpScreenshotHome(tester, repository, boundaryKey);
      expect(find.byKey(const ValueKey('stop-timer-button')), findsOneWidget);
      expect(await repository.fetchBottles(), hasLength(4));
      expect(await repository.fetchEntries(), hasLength(5));

      if (viewport.key == 'phone') {
        await _saveScreenshot(
          tester,
          boundaryKey,
          viewport.value,
          'phone-active',
        );
        await tester.ensureVisible(find.text('时间海洋'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _saveScreenshot(
          tester,
          boundaryKey,
          viewport.value,
          'phone-scroll',
        );
      }

      // End the sample timer through the real repository. Main captures show
      // the idle interface, while phone-active preserves the recording state.
      await repository.stopTimer(endedAt: _sampleNow);
      expect(await repository.fetchActiveEntry(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpScreenshotHome(tester, repository, boundaryKey);
      expect(find.byKey(const ValueKey('stop-timer-button')), findsNothing);
      expect(
        find.byKey(const ValueKey('primary-timer-button')),
        findsOneWidget,
      );
      await _saveScreenshot(tester, boundaryKey, viewport.value, viewport.key);
      if (viewport.key == 'phone') {
        await tester.ensureVisible(
          find.byKey(const ValueKey('primary-timer-button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _saveScreenshot(
          tester,
          boundaryKey,
          viewport.value,
          'phone-idle',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, skip: !_screenshotsEnabled);
  }
}

Future<void> _seedScreenshotData(TimeRecordsRepository repository) async {
  const names = ['专注工作', '阅读学习', '运动健康', '灵感创作'];
  const colors = [0xFF8FA6D7, 0xFF8EBCA8, 0xFFE9B782, 0xFFC6A1D1];
  const starts = [9, 11, 13, 14];
  const minutes = [105, 70, 40, 50];
  final bottleIds = <int>[];
  for (var i = 0; i < names.length; i++) {
    final bottle = await repository.createBottle(
      name: names[i],
      color: colors[i],
      now: DateTime(2026, 10, 1),
    );
    bottleIds.add(bottle.id!);
    final start = DateTime(2026, 10, 15, starts[i]);
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes[i])),
    );
  }
  await repository.startTimer(
    bottleId: bottleIds.first,
    startedAt: DateTime(2026, 10, 15, 15),
  );
}

Future<void> _loadScreenshotFonts() async {
  // flutter test does not register the icon family automatically. Load the
  // actual bundled font so screenshots contain icons rather than tofu boxes.
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

Future<void> _saveScreenshot(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Size size,
  String name,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(image.width, size.width.toInt());
      expect(image.height, size.height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final directory = Directory('build/ui-screenshots');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    } finally {
      image.dispose();
    }
  });
}

Future<void> _pumpScreenshotHome(
  WidgetTester tester,
  TimeRecordsRepository repository,
  GlobalKey boundaryKey,
) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomePage(
          repository: repository,
          enableTicker: false,
          clock: () => _sampleNow,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  Object? imageError;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/scenes/coastal-light.png'),
      tester.element(find.byType(HomePage)),
      onError: (error, stackTrace) => imageError = error,
    ),
  );
  expect(imageError, isNull, reason: 'The real scene asset must decode.');
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(HomePage), findsOneWidget);
}
