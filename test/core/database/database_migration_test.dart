import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('upgrades schema version 1 and preserves existing data', () async {
    final path =
        '${await databaseFactoryFfiNoIsolate.getDatabasesPath()}/timesand-migration-${DateTime.now().microsecondsSinceEpoch}.db';
    final legacy = await _createLegacyDatabase(path);
    final bottleId = await legacy.insert('bottles', <String, Object?>{
      'name': '旧瓶子',
      'color': 0xFFE8C98D,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'is_archived': 0,
    });
    await legacy.insert('time_entries', <String, Object?>{
      'bottle_id': bottleId,
      'started_at': '2026-01-01T08:00:00.000Z',
      'ended_at': '2026-01-01T09:00:00.000Z',
      'duration_seconds': 3600,
      'source': 'manual',
      'created_at': '2026-01-01T09:00:00.000Z',
      'updated_at': '2026-01-01T09:00:00.000Z',
    });
    await legacy.close();

    final upgraded = await TimeSandDatabase.open(path: path);
    final columns = await upgraded.database.rawQuery(
      'PRAGMA table_info(time_entries)',
    );
    expect(columns.any((column) => column['name'] == 'notes'), isTrue);
    expect(await upgraded.database.query('bottles'), hasLength(1));
    expect(
      (await upgraded.database.query('time_entries')).single['notes'],
      '',
    );
    await upgraded.close();
    await databaseFactoryFfiNoIsolate.deleteDatabase(path);
  });

  test('failed migration rolls back without deleting existing records', () async {
    final path =
        '${await databaseFactoryFfiNoIsolate.getDatabasesPath()}/timesand-migration-failure-${DateTime.now().microsecondsSinceEpoch}.db';
    final legacy = await _createLegacyDatabase(path, notesColumn: true);
    await legacy.insert('bottles', <String, Object?>{
      'name': '保留瓶子',
      'color': 0xFF9AC7C5,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'is_archived': 0,
    });
    await legacy.close();

    await expectLater(
      TimeSandDatabase.open(path: path),
      throwsA(isA<DatabaseException>()),
    );

    final reopened = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1),
    );
    expect(await reopened.query('bottles'), hasLength(1));
    expect(
      (await reopened.rawQuery('PRAGMA user_version')).single['user_version'],
      1,
    );
    await reopened.close();
    await databaseFactoryFfiNoIsolate.deleteDatabase(path);
  });
}

Future<Database> _createLegacyDatabase(
  String path, {
  bool notesColumn = false,
}) async {
  return databaseFactoryFfiNoIsolate.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bottles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_archived INTEGER NOT NULL DEFAULT 0
          )
        ''');
        final notes = notesColumn ? ", notes TEXT NOT NULL DEFAULT ''" : '';
        await db.execute('''
          CREATE TABLE time_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bottle_id INTEGER NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            duration_seconds INTEGER,
            source TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL$notes
          )
        ''');
      },
    ),
  );
}
