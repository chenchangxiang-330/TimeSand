import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/local_data_transfer.dart';
import 'package:timesand/core/database/time_records_repository.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;
  late Map<String, dynamic> backup;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
    final bottle = await repository.createBottle(name: '写作', color: 12);
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime.utc(2020, 1, 1, 9),
      endedAt: DateTime.utc(2020, 1, 1, 10),
    );
    await database.database.update('time_entries', {'notes': '保留备注'});
    backup = jsonDecode(await LocalDataTransfer.exportJson(repository))
        as Map<String, dynamic>;
  });
  tearDown(() => database.close());

  test('round trip preserves all stored fields including notes and archived state', () async {
    await repository.archiveBottle(1);
    final beforeBottles = await database.database.query('bottles');
    final beforeEntries = await database.database.query('time_entries');
    final raw = await LocalDataTransfer.exportJson(repository);
    await LocalDataTransfer.importJson(repository, raw, mode: ImportMode.replace);
    expect(await database.database.query('bottles'), beforeBottles);
    expect(await database.database.query('time_entries'), beforeEntries);
  });

  test('restore transaction rolls back deletes and inserts on SQL failure', () async {
    final beforeBottles = await database.database.query('bottles');
    final beforeEntries = await database.database.query('time_entries');
    await database.database.execute("""
      CREATE TRIGGER fail_restore BEFORE INSERT ON time_entries
      BEGIN SELECT RAISE(ABORT, 'injected failure'); END
    """);
    await expectLater(
      LocalDataTransfer.importJson(repository, jsonEncode(backup), mode: ImportMode.replace),
      throwsA(isA<DatabaseException>()),
    );
    expect(await database.database.query('bottles'), beforeBottles);
    expect(await database.database.query('time_entries'), beforeEntries);
  });

  test('merge allocates new IDs and preserves original bottle metadata', () async {
    final imported = (backup['time_entries'] as List).single as Map<String, dynamic>;
    imported['started_at'] = '2020-01-02T09:00:00.000Z';
    imported['ended_at'] = '2020-01-02T10:00:00.000Z';
    await LocalDataTransfer.importJson(repository, jsonEncode(backup), mode: ImportMode.merge);
    final bottles = await repository.fetchBottles();
    final entries = await repository.fetchEntries();
    expect(bottles, hasLength(2));
    expect(entries, hasLength(2));
    expect(entries[0].bottleId, isNot(entries[1].bottleId));
    expect(entries[1].notes, '保留备注');
  });

  test('merge conflicts leave existing database exactly unchanged', () async {
    final original = await database.database.query('time_entries');
    await expectLater(
      LocalDataTransfer.importJson(repository, jsonEncode(backup), mode: ImportMode.merge),
      throwsA(isA<LocalDataTransferException>()),
    );
    expect(await database.database.query('time_entries'), original);
    expect(await repository.fetchBottles(), hasLength(1));
  });

  for (final key in ['format_version', 'exported_at', 'timezone', 'database', 'bottles', 'time_entries']) {
    test('missing top-level field $key is refused', () {
      backup.remove(key);
      expect(() => LocalDataTransfer.parseJson(jsonEncode(backup)), throwsException);
    });
  }

  for (final key in ['id', 'bottle_id', 'started_at', 'ended_at', 'duration_seconds', 'source', 'created_at', 'updated_at']) {
    test('missing record field $key is refused', () {
      ((backup['time_entries'] as List).single as Map).remove(key);
      expect(() => LocalDataTransfer.parseJson(jsonEncode(backup)), throwsException);
    });
  }

  test('unsupported format and schema versions are refused', () {
    backup['format_version'] = 99;
    expect(() => LocalDataTransfer.parseJson(jsonEncode(backup)), throwsException);
    backup['format_version'] = 1;
    backup['database'] = {'schema_version': 99};
    expect(() => LocalDataTransfer.parseJson(jsonEncode(backup)), throwsException);
  });

  test('invalid normalized dates and ambiguous timestamps are refused', () {
    for (final timestamp in [
      '2020-02-31T09:00:00.000Z',
      '2020-01-01T09:00:00.000',
      'not a timestamp',
    ]) {
      (backup['time_entries'] as List).single['started_at'] = timestamp;
      expect(() => LocalDataTransfer.parseJson(jsonEncode(backup)), throwsException);
    }
  });

  test('active timer has null duration and remains active after restore', () async {
    (backup['time_entries'] as List).single
      ..['source'] = 'active'
      ..['ended_at'] = null
      ..['duration_seconds'] = null;
    await LocalDataTransfer.importJson(repository, jsonEncode(backup), mode: ImportMode.replace);
    final active = await repository.fetchActiveEntry();
    expect(active, isNotNull);
    expect(active!.startedAt.toUtc(), DateTime.utc(2020, 1, 1, 9));
  });

  test('open active interval conflicts with every later record', () {
    final entries = backup['time_entries'] as List;
    final later = Map<String, dynamic>.from(entries.single as Map)
      ..['id'] = 2
      ..['started_at'] = '2090-01-02T09:00:00.000Z'
      ..['ended_at'] = '2090-01-02T10:00:00.000Z';
    entries.single
      ..['source'] = 'active'
      ..['ended_at'] = null
      ..['duration_seconds'] = null;
    entries.add(later);
    expect(() => LocalDataTransfer.parseJson(jsonEncode(backup)), throwsException);
  });

  test('CSV quotes commas newlines quotes and protects spreadsheet formulas', () async {
    await repository.updateBottle(id: 1, name: '=SUM(1,2)\n"quoted"');
    final csv = await LocalDataTransfer.exportCsv(repository);
    expect(csv, contains('""quoted""'));
    expect(csv, contains("'=SUM"));
  });

  test('empty backup is valid and replacement clears both tables atomically', () async {
    backup['bottles'] = [];
    backup['time_entries'] = [];
    await LocalDataTransfer.importJson(repository, jsonEncode(backup), mode: ImportMode.replace);
    expect(await repository.fetchBottles(), isEmpty);
    expect(await repository.fetchEntries(), isEmpty);
  });
}
