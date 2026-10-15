import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('fresh database includes v2 and all indexes', () async {
    final db = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);
    expect(await db.database.getVersion(), 2);
    final indexes = await db.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    expect(
      indexes.map((row) => row['name']),
      containsAll([
        'time_entries_bottle_index',
        'time_entries_started_index',
        'one_active_time_entry',
      ]),
    );
  });

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
    expect((await upgraded.database.query('time_entries')).single['notes'], '');
    await upgraded.close();
    await databaseFactoryFfiNoIsolate.deleteDatabase(path);
  });

  test('failed migration rolls back without deleting existing records', () async {
    final path =
        '${await databaseFactoryFfiNoIsolate.getDatabasesPath()}/timesand-migration-failure-${DateTime.now().microsecondsSinceEpoch}.db';
    final legacy = await _createLegacyDatabase(path);
    await legacy.insert('bottles', <String, Object?>{
      'name': '保留瓶子',
      'color': 0xFF9AC7C5,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'is_archived': 0,
    });
    await legacy.insert('time_entries', {
      'bottle_id': 1,
      'started_at': '2020-01-01T09:00:00.000Z',
      'ended_at': '2020-01-01T10:00:00.000Z',
      'duration_seconds': 3600,
      'source': 'manual',
      'created_at': '2020-01-01T10:00:00.000Z',
      'updated_at': '2020-01-01T10:00:00.000Z',
    });
    final originalEntries = await legacy.query('time_entries');
    await legacy.close();

    await expectLater(
      databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, oldVersion, newVersion) async {
            await TimeSandDatabase.migrate(db, oldVersion, newVersion);
            await db.update('bottles', {'name': 'must roll back'});
            await db.delete('time_entries');
            await db.execute('INSERT INTO missing_table VALUES (1)');
          },
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );

    final reopened = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1),
    );
    expect((await reopened.query('bottles')).single['name'], '保留瓶子');
    expect(await reopened.query('time_entries'), originalEntries);
    expect(await reopened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await reopened.rawQuery(
        'PRAGMA table_info(time_entries)',
      )).any((column) => column['name'] == 'notes'),
      isFalse,
    );
    expect(
      (await reopened.rawQuery('PRAGMA user_version')).single['user_version'],
      1,
    );
    await reopened.close();
    await databaseFactoryFfiNoIsolate.deleteDatabase(path);
  });
}

Future<Database> _createLegacyDatabase(String path) async {
  return databaseFactoryFfiNoIsolate.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE bottles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0
          CHECK (is_archived IN (0, 1))
      )
    ''');
    await db.execute('''
      CREATE TABLE time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bottle_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_seconds INTEGER,
        source TEXT NOT NULL
          CHECK (source IN ('active', 'manual')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (bottle_id) REFERENCES bottles(id)
          ON DELETE RESTRICT,
        CHECK (ended_at IS NULL OR ended_at > started_at),
        CHECK (duration_seconds IS NULL OR duration_seconds >= 0)
      )
    ''');
    await db.execute(
      'CREATE INDEX time_entries_bottle_index '
      'ON time_entries (bottle_id)',
    );
    await db.execute(
      'CREATE INDEX time_entries_started_index '
      'ON time_entries (started_at, ended_at)',
    );
    await db.execute(
      "CREATE UNIQUE INDEX one_active_time_entry "
      "ON time_entries (source) "
      "WHERE source = 'active' AND ended_at IS NULL",
    );
      },
    ),
  );
}
