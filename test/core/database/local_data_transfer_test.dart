import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/local_data_transfer.dart';
import 'package:timesand/core/database/time_records_repository.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
  });

  tearDown(() => database.close());

  test('exports stable JSON metadata and CSV columns', () async {
    final bottle = await repository.createBottle(
      name: '阅读,专注',
      color: 1,
      now: DateTime(2026, 10, 14, 8),
    );
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime(2026, 10, 14, 9),
      endedAt: DateTime(2026, 10, 14, 10),
    );
    final json = await LocalDataTransfer.exportJson(
      repository,
      exportedAt: DateTime.utc(2026, 10, 14, 12),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['format_version'], 1);
    expect(decoded['timezone'], isA<String>());
    expect((decoded['database'] as Map)['schema_version'], 2);
    expect((decoded['bottles'] as List), hasLength(1));
    expect((decoded['time_entries'] as List), hasLength(1));

    final csv = await LocalDataTransfer.exportCsv(repository);
    expect(
      csv.split('\n').first,
      'time_entry_id,bottle_id,bottle_name,started_at,ended_at,'
      'duration_seconds,source,created_at,updated_at',
    );
    expect(csv, contains('"阅读,专注"'));
  });

  test('round trips JSON through replace restore', () async {
    final bottle = await repository.createBottle(name: '写作', color: 2);
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime(2026, 10, 14, 9),
      endedAt: DateTime(2026, 10, 14, 9, 30),
    );
    final exported = await LocalDataTransfer.exportJson(repository);
    await database.reset();
    await LocalDataTransfer.importJson(
      repository,
      exported,
      mode: ImportMode.replace,
    );
    expect(await repository.fetchBottles(includeArchived: true), hasLength(1));
    expect(await repository.fetchEntries(), hasLength(1));
  });

  test(
    'rejects malformed JSON, missing fields, unknown bottles, and overlaps',
    () async {
      expect(
        () => LocalDataTransfer.parseJson('{not json'),
        throwsA(isA<FormatException>()),
      );
      final bottle = await repository.createBottle(name: '学习', color: 3);
      await repository.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2026, 10, 14, 10),
        endedAt: DateTime(2026, 10, 14, 11),
      );
      final exported = await LocalDataTransfer.exportJson(repository);
      final map = jsonDecode(exported) as Map<String, dynamic>;
      final missing = Map<String, dynamic>.from(map)..remove('bottles');
      expect(
        () => LocalDataTransfer.parseJson(jsonEncode(missing)),
        throwsA(isA<LocalDataTransferException>()),
      );
      final unknown = jsonDecode(exported) as Map<String, dynamic>;
      (unknown['time_entries'] as List).first['bottle_id'] = 999;
      expect(
        () => LocalDataTransfer.parseJson(jsonEncode(unknown)),
        throwsA(isA<LocalDataTransferException>()),
      );
      final overlap = jsonDecode(exported) as Map<String, dynamic>;
      final entry = Map<String, dynamic>.from(
        (overlap['time_entries'] as List).first as Map,
      )..['id'] = 2;
      (overlap['time_entries'] as List).add(entry);
      expect(
        () => LocalDataTransfer.parseJson(jsonEncode(overlap)),
        throwsA(isA<LocalDataTransferException>()),
      );
    },
  );

  test(
    'merge rejects overlaps and failed replace preserves existing data',
    () async {
      final bottle = await repository.createBottle(name: '已有', color: 4);
      await repository.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2026, 10, 14, 12),
        endedAt: DateTime(2026, 10, 14, 13),
      );
      final exported = await LocalDataTransfer.exportJson(repository);
      expect(
        () => LocalDataTransfer.importJson(
          repository,
          exported,
          mode: ImportMode.merge,
        ),
        throwsA(isA<LocalDataTransferException>()),
      );
      expect(
        () => LocalDataTransfer.importJson(
          repository,
          '{"format_version":1}',
          mode: ImportMode.replace,
        ),
        throwsA(isA<LocalDataTransferException>()),
      );
      expect(
        await repository.fetchBottles(includeArchived: true),
        hasLength(1),
      );
      expect(await repository.fetchEntries(), hasLength(1));
    },
  );
}
