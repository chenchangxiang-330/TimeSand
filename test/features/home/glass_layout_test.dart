import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_entry_rules.dart';
import 'package:timesand/design/app_theme.dart';
import 'package:timesand/features/bottles/bottle_detail_page.dart';
import 'package:timesand/features/history/history_page.dart';
import 'package:timesand/features/home/home_page.dart';
import 'package:timesand/features/hourglass/hourglass_placeholder.dart';
import 'package:timesand/features/statistics/statistics_page.dart';

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
      startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
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
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(await repository.fetchActiveEntry(), isNull);
    expect((await repository.fetchEntries()).last.endedAt, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('statistics navigation opens actual stored data', (tester) async {
    await _seedBottles(repository, count: 2);
    await _pumpHome(tester, repository, size: const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('nav-statistics')));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsPage), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-lifetime')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsPage), findsNothing);
    expect(find.byKey(const ValueKey('primary-timer-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings navigation exposes working bottle management', (
    tester,
  ) async {
    await _seedBottles(repository, count: 1);
    await _pumpHome(tester, repository, size: const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('我的 · 本地时光'), findsOneWidget);
    final manage = find.text('管理时间之瓶');
    await _reveal(tester, manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();
    expect(find.text('我的时间之瓶'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-bottle-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'selection starts the chosen bottle and stop persists the interval',
    (tester) async {
      final first = await repository.createBottle(
        name: '阅读',
        color: 0xFF8EBCA8,
      );
      final second = await repository.createBottle(
        name: '创作',
        color: 0xFFC6A1D1,
      );
      await _pumpHome(
        tester,
        repository,
        size: const Size(390, 844),
        clock: DateTime.now,
      );
      final select = find.byKey(ValueKey('select-bottle-${second.id}'));
      await _reveal(tester, select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(select).isSelected, isTrue);

      final primary = find.byKey(const ValueKey('primary-timer-button'));
      await _reveal(tester, primary);
      await tester.tap(primary);
      await tester.pumpAndSettle();
      final active = await repository.fetchActiveEntry();
      expect(active, isNotNull);
      expect(active!.bottleId, second.id);
      expect(find.byKey(ValueKey('start-${first.id}')), findsNothing);
      expect(find.byKey(ValueKey('start-${second.id}')), findsNothing);

      // Changing selection while recording cannot silently replace the timer.
      final selectOther = find.byKey(ValueKey('select-bottle-${first.id}'));
      await _reveal(tester, selectOther);
      await tester.tap(selectOther);
      await tester.pumpAndSettle();
      expect((await repository.fetchActiveEntry())!.id, active.id);
      await expectLater(
        repository.startTimer(bottleId: first.id!),
        throwsA(isA<ActiveTimerConflictException>()),
      );
      expect((await repository.fetchEntries()), hasLength(1));

      final stop = find.byKey(const ValueKey('stop-timer-button'));
      await _reveal(tester, stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(await repository.fetchActiveEntry(), isNull);
      final restored = (await TimeRecordsRepository(
        database,
      ).fetchEntries()).single;
      expect(restored.id, active.id);
      expect(restored.bottleId, second.id);
      expect(restored.startedAt, active.startedAt);
      expect(restored.endedAt!.isAfter(restored.startedAt), isTrue);
      expect(
        restored.durationSeconds,
        restored.endedAt!.difference(restored.startedAt).inSeconds,
      );

      // Rebuild the actual homepage against the same SQLite database.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpHome(
        tester,
        TimeRecordsRepository(database),
        size: const Size(390, 844),
        clock: DateTime.now,
      );
      expect(find.byKey(const ValueKey('stop-timer-button')), findsNothing);
      expect(find.text('没有正在进行的计时'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('system reduced motion stops decorative frames on the homepage', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      repository,
      size: const Size(390, 844),
      enableTicker: true,
      disableAnimations: true,
    );
    final hourglass = tester.widget<HourglassPlaceholder>(
      find.byType(HourglassPlaceholder),
    );
    expect(hourglass.animate, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // The real-time clock may update each second; it must not restart the
    // decorative animation or leave a continuous frame stream scheduled.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final save in [false, true]) {
    testWidgets(
      'narrow bottle form with keyboard ${save ? 'saves' : 'cancels'}',
      (tester) async {
        await _pumpHome(
          tester,
          repository,
          size: const Size(320, 740),
          textScale: 1.7,
        );
        final create = find.byKey(const ValueKey('create-bottle-button'));
        await _reveal(tester, create);
        await tester.tap(create);
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        final name = find.byType(TextField);
        expect(name, findsOneWidget);
        await tester.enterText(name, '键盘下创建的时间之瓶');
        final action = find.widgetWithText(TextButton, '取消');
        final submit = find.widgetWithText(FilledButton, '保存');
        await _reveal(tester, save ? submit : action);
        expect(tester.takeException(), isNull);
        await tester.tap(save ? submit : action);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        final bottles = await repository.fetchBottles();
        expect(bottles, hasLength(save ? 1 : 0));
        if (save) {
          expect(bottles.single.name, '键盘下创建的时间之瓶');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('deleting an active history entry refreshes the global timer', (
    tester,
  ) async {
    final bottle = await repository.createBottle(
      name: '跨页计时',
      color: 0xFF8EBCA8,
    );
    await _pumpHome(
      tester,
      repository,
      size: const Size(390, 844),
      clock: DateTime.now,
    );
    final start = find.byKey(ValueKey('start-${bottle.id}'));
    await _reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    final active = await repository.fetchActiveEntry();
    expect(active, isNotNull);
    expect(find.byKey(const ValueKey('stop-timer-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-history')));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
    final delete = find.byKey(ValueKey('delete-entry-${active!.id}'));
    await _reveal(tester, delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('删除时间记录？'), findsOneWidget);
    expect(await repository.fetchActiveEntry(), isNotNull);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '删除'),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    // Check the shared shell immediately, without navigating home or resuming
    // the app: a child-page mutation must invalidate its parent's cache.
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(await repository.fetchActiveEntry(), isNull);
    expect(await repository.fetchEntries(), isEmpty);
    expect(find.byKey(const ValueKey('stop-timer-button')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}

Future<void> _pumpHome(
  WidgetTester tester,
  TimeRecordsRepository repository, {
  required Size size,
  double textScale = 1,
  bool enableTicker = false,
  bool disableAnimations = false,
  DateTime Function()? clock,
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: HomePage(
        repository: repository,
        enableTicker: enableTicker,
        clock: clock ?? () => _sampleNow,
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
