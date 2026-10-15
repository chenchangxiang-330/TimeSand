import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/features/bottles/bottle_detail_page.dart';
import 'package:timesand/features/history/history_page.dart';
import 'package:timesand/features/home/home_page.dart';

final _sampleNow = DateTime(2026, 10, 15, 15, 20);

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
  });
  tearDown(() => database.close());

  const scenarios = [
    (
      name: 'narrow phone with empty data',
      size: Size(320, 740),
      scale: 1.0,
      count: 0,
      longNames: false,
    ),
    (
      name: 'narrow phone with long bottle names',
      size: Size(320, 740),
      scale: 1.0,
      count: 3,
      longNames: true,
    ),
    (
      name: 'Android landscape',
      size: Size(844, 390),
      scale: 1.0,
      count: 4,
      longNames: false,
    ),
    (
      name: 'desktop with twenty bottles',
      size: Size(1440, 960),
      scale: 1.0,
      count: 20,
      longNames: false,
    ),
    (
      name: 'narrow macOS window',
      size: Size(600, 500),
      scale: 1.0,
      count: 8,
      longNames: true,
    ),
    (
      name: 'phone with large accessible text',
      size: Size(390, 844),
      scale: 1.7,
      count: 4,
      longNames: true,
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets('glass homepage fits ${scenario.name}', (tester) async {
      final ids = await _seedBottles(
        repository,
        count: scenario.count,
        longNames: scenario.longNames,
      );
      await _pumpHome(
        tester,
        repository,
        size: scenario.size,
        textScale: scenario.scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(HomePage), findsOneWidget);
      for (final key in [
        'nav-home',
        'nav-history',
        'nav-statistics',
        'nav-settings',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('primary-timer-button')),
        findsOneWidget,
      );

      // Scroll to the actual final item, forcing layout of lazy children.
      // This catches overflows that would otherwise hide below the viewport.
      final target = ids.isEmpty
          ? find.byKey(const ValueKey('create-bottle-button'))
          : find.byKey(ValueKey('bottle-detail-${ids.last}'));
      await _reveal(tester, target);
      expect(tester.takeException(), isNull);
      expect(target.hitTestable(), findsOneWidget);
      if (ids.isNotEmpty) {
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(BottleDetailPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('glass navigation opens the existing history page', (
    tester,
  ) async {
    await _seedBottles(repository, count: 2);
    await _pumpHome(tester, repository, size: const Size(390, 844));
    final history = find.byKey(const ValueKey('nav-history'));
    await _reveal(tester, history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restored timer exposes a usable stop control', (tester) async {
    final ids = await _seedBottles(repository, count: 2);
    await repository.startTimer(
      bottleId: ids.first,
      startedAt: _sampleNow.subtract(const Duration(minutes: 20)),
    );
    await _pumpHome(
      tester,
      repository,
      size: const Size(320, 740),
      textScale: 1.7,
    );
    final stop = find.byKey(const ValueKey('stop-timer-button'));
    await _reveal(tester, stop);
    expect(stop.hitTestable(), findsOneWidget);
    expect(await repository.fetchActiveEntry(), isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  TimeRecordsRepository repository, {
  required Size size,
  double textScale = 1,
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
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: HomePage(
        repository: repository,
        enableTicker: false,
        clock: () => _sampleNow,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<int>> _seedBottles(
  TimeRecordsRepository repository, {
  required int count,
  bool longNames = false,
}) async {
  final ids = <int>[];
  const colors = [0xFF8FA6D7, 0xFF8EBCA8, 0xFFE9B782, 0xFFC6A1D1];
  for (var i = 0; i < count; i++) {
    final bottle = await repository.createBottle(
      name: longNames
          ? '${i + 1} 阅读学习与长期成长的时间之瓶 Reading and deliberate practice'
          : '测试时间之瓶 ${i + 1}',
      color: colors[i % colors.length],
      now: DateTime(2026, 10, 1),
    );
    ids.add(bottle.id!);
    final start = DateTime(2026, 10, 15, 6).add(Duration(minutes: i * 20));
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 10)),
    );
  }
  return ids;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    );
    expect(scrollable, findsWidgets);
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: scrollable.first,
      maxScrolls: 80,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
}
