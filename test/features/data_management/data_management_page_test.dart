import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/local_data_transfer.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/features/data_management/backup_files.dart';
import 'package:timesand/features/data_management/data_management_page.dart';

class MemoryFiles implements BackupFiles {
  String? picked;
  String? saved;
  bool fail = false;
  @override
  Future<String?> pickJson() async => picked;
  @override
  Future<String> saveText({
    required String fileName, required String mimeType, required String contents,
  }) async {
    if (fail) throw StateError('save failed');
    saved = contents;
    return '文件已保存。';
  }
}

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repo;
  late MemoryFiles files;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repo = TimeRecordsRepository(database);
    files = MemoryFiles();
  });
  tearDown(() => database.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DataManagementPage(repository: repo, files: files)));
    await tester.pumpAndSettle();
  }

  testWidgets('exports JSON and reports save failure', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('export-json-button')));
    await tester.pumpAndSettle();
    expect(jsonDecode(files.saved!)['format_version'], 1);
    expect(find.text('文件已保存。'), findsOneWidget);
    files.fail = true;
    await tester.tap(find.byKey(const ValueKey('export-csv-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('导出失败'), findsOneWidget);
  });

  testWidgets('invalid import reports error without altering current data', (tester) async {
    await repo.createBottle(name: '保留', color: 1);
    files.picked = '{broken';
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('import-json-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('导入失败'), findsOneWidget);
    expect((await repo.fetchBottles()).single.name, '保留');
  });

  testWidgets('replace requires preview and a second explicit confirmation', (tester) async {
    files.picked = await LocalDataTransfer.exportJson(repo);
    await repo.createBottle(name: '保留', color: 1);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('import-json-button')));
    await tester.pumpAndSettle();
    expect(find.text('确认导入'), findsOneWidget);
    expect(find.text('合并导入：保留当前数据'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<ImportMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('覆盖恢复：替换当前数据').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看并确认'));
    await tester.pumpAndSettle();
    expect(find.text('确认覆盖恢复？'), findsOneWidget);
    expect(await repo.fetchBottles(), hasLength(1));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await repo.fetchBottles(), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('import-json-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ImportMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('覆盖恢复：替换当前数据').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看并确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认覆盖'));
    await tester.pumpAndSettle();
    expect(await repo.fetchBottles(), isEmpty);
    expect(find.textContaining('导入成功'), findsOneWidget);
  });
}
