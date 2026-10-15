import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/features/history/history_page.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repo;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repo = TimeRecordsRepository(database);
    final bottle = await repo.createBottle(name: '阅读', color: 1);
    await repo.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime.utc(2020, 1, 1, 9, 0, 15),
      endedAt: DateTime.utc(2020, 1, 1, 10, 0, 15),
    );
  });
  tearDown(() => database.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(380, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: HistoryPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('manual input rejects normalized nonexistent dates', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('manual-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('manual-start-input')), '2020-02-30 09:00');
    await tester.enterText(find.byKey(const ValueKey('manual-end-input')), '2020-03-01 10:00');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效日期和时间。'), findsOneWidget);
    expect(await repo.fetchEntries(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing preserves seconds and refreshes totals', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('edit-entry-1')));
    await tester.tap(find.byKey(const ValueKey('edit-entry-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-end-input')),
      '2020-01-01T11:00:15.000Z',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();
    expect((await repo.fetchEntries()).single.durationSeconds, 7200);
    expect((await repo.fetchEntries()).single.startedAt.second, 15);
    expect(find.text('历史记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid edit stays open with visible error', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('edit-entry-1')));
    await tester.tap(find.byKey(const ValueKey('edit-entry-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-end-input')),
      'bad',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('请保留日期'), findsOneWidget);
    expect((await repo.fetchEntries()).single.durationSeconds, 3600);
  });

  testWidgets(
    'delete cancellation preserves records and confirmation removes them',
    (tester) async {
      await open(tester);
      final button = find.byKey(const ValueKey('delete-entry-1'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await repo.fetchEntries(), hasLength(1));
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(await repo.fetchEntries(), isEmpty);
      expect(find.text('还没有历史投入记录。'), findsOneWidget);
    },
  );

  testWidgets('month and bottle controls filter and show lifetime totals', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('history-bottle-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('该瓶永久累计'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-month-filter')));
    await tester.pumpAndSettle();
    expect(find.text('选择月份'), findsOneWidget);
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    expect(find.text('还没有历史投入记录。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
