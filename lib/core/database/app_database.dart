import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TimeSandDatabase {
  TimeSandDatabase._(this._database);

  static const int currentSchemaVersion = 2;

  final Database _database;

  Database get database => _database;

  static Future<TimeSandDatabase> open({String? path}) async {
    final databasePath =
        path ??
        '${await databaseFactoryFfiNoIsolate.getDatabasesPath()}/timesand.db';
    final database = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchemaV2(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _upgradeSchema(db, oldVersion, newVersion);
        },
      ),
    );
    return TimeSandDatabase._(database);
  }

  static Future<void> _createSchemaV2(Database db) async {
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
        notes TEXT NOT NULL DEFAULT '',
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
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute(
        "ALTER TABLE time_entries "
        "ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> close() => _database.close();

  Future<void> reset() async {
    await _database.transaction((txn) async {
      await txn.delete('time_entries');
      await txn.delete('bottles');
    });
  }
}
