import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/database_path.dart';
import 'package:timesand/core/database/time_records_repository.dart';

void main() {
  late Directory temporary;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('timesand-path-test-');
  });
  tearDown(() => temporary.delete(recursive: true));

  test('new Android database uses a writable private support directory', () async {
    final support = Directory('${temporary.path}/private/support');
    final path = await resolveDatabasePath(
      isAndroid: true,
      legacyPath: '${temporary.path}/missing/timesand.db',
      supportDirectory: () async => support,
    );
    expect(path, '${support.path}/timesand.db');
    expect(await support.exists(), isTrue);
    final database = await TimeSandDatabase.open(path: path);
    await database.close();
    expect(await File(path).exists(), isTrue);
  });

  test('an existing legacy database and records survive reopening', () async {
    final legacyPath = '${temporary.path}/timesand.db';
    final database = await TimeSandDatabase.open(path: legacyPath);
    final repository = TimeRecordsRepository(database);
    final bottle = await repository.createBottle(name: '保留时光', color: 0xFF327BC0);
    final entry = await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime.utc(2026, 10, 1, 9),
      endedAt: DateTime.utc(2026, 10, 1, 10),
    );
    await database.close();
    final resolved = await resolveDatabasePath(
      isAndroid: true,
      legacyPath: legacyPath,
      supportDirectory: () => throw StateError('Must not relocate existing data'),
    );
    expect(resolved, legacyPath);
    final reopened = await TimeSandDatabase.open(path: resolved);
    final restored = TimeRecordsRepository(reopened);
    expect((await restored.fetchBottles()).single.id, bottle.id);
    expect((await restored.fetchEntries()).single.id, entry.id);
    await reopened.close();
  });

  test('non-Android platforms keep their established path', () async {
    const legacyPath = '/existing/macos/location/timesand.db';
    expect(
      await resolveDatabasePath(
        isAndroid: false,
        legacyPath: legacyPath,
        supportDirectory: () => throw StateError('Must not change desktop path'),
      ),
      legacyPath,
    );
  });

  test('a damaged existing file is not replaced with an empty database', () async {
    final legacy = File('${temporary.path}/timesand.db');
    await legacy.writeAsString('damaged database kept for recovery');
    expect(
      await resolveDatabasePath(
        isAndroid: true,
        legacyPath: legacy.path,
        supportDirectory: () => throw StateError('Must not discard old file'),
      ),
      legacy.path,
    );
    expect(await legacy.readAsString(), 'damaged database kept for recovery');
  });

  test('support directory failure propagates without creating a fallback', () async {
    final failure = FileSystemException('permission denied');
    await expectLater(
      resolveDatabasePath(
        isAndroid: true,
        legacyPath: '${temporary.path}/missing/timesand.db',
        supportDirectory: () => throw failure,
      ),
      throwsA(same(failure)),
    );
    expect(await temporary.list().isEmpty, isTrue);
  });
}
