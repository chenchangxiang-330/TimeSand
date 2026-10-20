import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/design/glass_bottle.dart';
import 'package:timesand/features/bottles/bottle_detail_page.dart';
import 'package:timesand/features/history/history_page.dart';
import 'package:timesand/features/home/home_page.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;
  late Bottle bottle;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
    bottle = await repository.createBottle(name: '阅读', color: 0xFFAA99DD);
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime(2020, 1, 1, 14),
      endedAt: DateTime(2020, 1, 1, 15),
    );
  });
  tearDown(() => database.close());

  Future<void> open(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'idle bottle detail resets today at midnight and preserves history',
    (tester) async {
      var now = DateTime(2020, 1, 1, 23, 59, 58);
      await open(
        tester,
        BottleDetailPage(
          repository: repository,
          bottle: bottle,
          clock: () => now,
        ),
        const Size(420, 1000),
      );
      expect(await repository.fetchActiveEntry(), isNull);
      expect(find.text('今天 1小时 00分'), findsOneWidget);
      expect(
        tester.widget<GlassBottle>(find.byType(GlassBottle)).fill,
        greaterThan(0),
      );

      now = DateTime(2020, 1, 2, 0, 0, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('今天 0秒'), findsOneWidget);
      expect(find.text('今天 1小时 00分'), findsNothing);
      expect(tester.widget<GlassBottle>(find.byType(GlassBottle)).fill, 0);
      expect(find.text('永久累计 · 1 条记录'), findsOneWidget);
      expect(find.text('1小时 00分'), findsWidgets);
      expect((await repository.fetchEntries()).single.durationSeconds, 3600);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar navigation samples current clock after an idle tab crosses midnight',
    (tester) async {
      await repository.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2020, 1, 2),
        endedAt: DateTime(2020, 1, 2, 0, 1),
      );
      var now = DateTime(2020, 1, 1, 23, 59, 58);
      await open(
        tester,
        HomePage(repository: repository, enableTicker: false, clock: () => now),
        const Size(1280, 1000),
      );
      await tester.tap(find.byKey(const ValueKey('dock-statistics')));
      await tester.pumpAndSettle();
      expect(find.text('时间统计'), findsOneWidget);

      now = DateTime(2020, 1, 2, 0, 2);
      await tester.tap(find.byKey(const ValueKey('dock-history')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<HistoryPage>(find.byType(HistoryPage)).initialDate,
        now,
      );
      expect(find.text('2020-01-02'), findsOneWidget);
      expect(find.textContaining('1 条记录'), findsOneWidget);
      expect(find.text('1分 00秒'), findsWidgets);
      expect(await repository.fetchEntries(), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
