import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/core/records/time_statistics.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/features/history/history_page.dart';
import 'package:timesand/features/statistics/statistics_page.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;
  late Bottle bottle;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
    bottle = await repository.createBottle(name: '阅读', color: 0xFFAA99DD);
  });
  tearDown(() => database.close());

  Future<TimeEntry> record(DateTime start, DateTime end) {
    return repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: start,
      endedAt: end,
    );
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(380, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  String textAt(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets(
    'date picker changes the visible day and clips midnight records',
    (tester) async {
      await record(DateTime(2020, 1, 1, 9), DateTime(2020, 1, 1, 10));
      await record(DateTime(2020, 1, 1, 23, 30), DateTime(2020, 1, 2, 0, 30));
      await open(
        tester,
        HistoryPage(repository: repository, initialDate: DateTime(2020, 1, 2)),
      );
      expect(find.textContaining('1 条记录'), findsOneWidget);
      expect(find.text('30分 00秒'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('history-date-filter')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('1').last);
      final dialogContext = tester.element(find.byType(DatePickerDialog));
      await tester.tap(
        find.text(MaterialLocalizations.of(dialogContext).okButtonLabel),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2 条记录'), findsOneWidget);
      expect(find.text('1小时 30分'), findsOneWidget);
      expect(find.text('2020-01-01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing a record cannot overlap another interval', (
    tester,
  ) async {
    final first = await record(
      DateTime(2020, 1, 1, 9),
      DateTime(2020, 1, 1, 10),
    );
    await record(DateTime(2020, 1, 1, 11), DateTime(2020, 1, 1, 12));
    await open(tester, HistoryPage(repository: repository));
    final edit = find.byKey(ValueKey('edit-entry-${first.id}'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-end-input')),
      '2020-01-01T11:30:00',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('重叠'), findsOneWidget);
    expect(find.text('编辑时间记录'), findsOneWidget);
    expect(
      (await repository.fetchEntries()).first.endedAt,
      DateTime(2020, 1, 1, 10),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete confirmation preserves cancellation and updates totals', (
    tester,
  ) async {
    final first = await record(
      DateTime(2020, 1, 1, 9),
      DateTime(2020, 1, 1, 10),
    );
    await record(DateTime(2020, 1, 1, 11), DateTime(2020, 1, 1, 12));
    await open(tester, HistoryPage(repository: repository));
    final delete = find.byKey(ValueKey('delete-entry-${first.id}'));
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await repository.fetchEntries(), hasLength(2));
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    final entries = await repository.fetchEntries();
    expect(entries, hasLength(1));
    expect(find.textContaining('1 条记录'), findsOneWidget);
    final stats = TimeStatistics.forDate(
      date: DateTime(2020, 1, 1),
      now: DateTime(2020, 1, 1, 12),
      entries: entries,
    );
    expect(stats.recorded, const Duration(hours: 1));
    expect(stats.unallocated, const Duration(hours: 11));
    expect(
      TimeStatistics.lifetime(
        bottleId: bottle.id!,
        now: DateTime(2020, 1, 1, 12),
        entries: entries,
      ).total,
      const Duration(hours: 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'revision reloads externally stopped timer without clearing date',
    (tester) async {
      final active = await repository.startTimer(
        bottleId: bottle.id!,
        startedAt: DateTime(2020, 1, 1, 9),
      );
      final revision = ValueNotifier(0);
      addTearDown(revision.dispose);
      await open(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (_, value, _) => HistoryPage(
            repository: repository,
            initialDate: DateTime(2020, 1, 1),
            revision: value,
          ),
        ),
      );
      final edit = find.byKey(ValueKey('edit-entry-${active.id}'));
      expect(tester.widget<TextButton>(edit).onPressed, isNull);
      await repository.stopTimer(endedAt: DateTime(2020, 1, 1, 9, 30));
      revision.value++;
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(edit).onPressed, isNotNull);
      expect(find.text('2020-01-01'), findsOneWidget);
      expect(find.textContaining('1 条记录'), findsOneWidget);
      expect(find.text('30分 00秒'), findsWidgets);
      expect(find.text('正在投入'), findsNothing);
    },
  );

  testWidgets('statistics shows database totals and updates on revision', (
    tester,
  ) async {
    final entry = await record(
      DateTime(2020, 1, 1, 9),
      DateTime(2020, 1, 1, 10),
    );
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    await open(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: revision,
        builder: (_, value, _) =>
            StatisticsPage(repository: repository, revision: value),
      ),
    );
    expect(textAt(tester, 'statistics-daily-recorded'), '0秒');
    expect(textAt(tester, 'statistics-lifetime'), '1小时 00分');
    expect(find.byKey(const ValueKey('statistics-ocean')), findsOneWidget);
    await repository.updateEntry(
      id: entry.id!,
      startedAt: entry.startedAt,
      endedAt: DateTime(2020, 1, 1, 11),
    );
    revision.value++;
    await tester.pumpAndSettle();
    expect(textAt(tester, 'statistics-lifetime'), '2小时 00分');
    expect(textAt(tester, 'statistics-daily-recorded'), '0秒');
    expect(tester.takeException(), isNull);
  });
}
