import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/features/home/home_page.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('home displays a bottle and starts and stops a timer', (
    tester,
  ) async {
    final bottle = await repository.createBottle(name: '专注', color: 0xFFE8C98D);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repository, enableTicker: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('专注'), findsOneWidget);
    final startKey = ValueKey('start-' + bottle.id.toString());
    expect(find.byKey(startKey), findsOneWidget);

    await tester.tap(find.byKey(startKey));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('stop-timer-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stop-timer-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('没有正在进行的计时'), findsOneWidget);
  });

  testWidgets('history page opens from the home page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repository, enableTicker: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('history-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('历史记录'), findsOneWidget);
    expect(find.text('还没有历史投入记录。'), findsOneWidget);
  });
}
