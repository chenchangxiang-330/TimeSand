import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_statistics.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'edit and delete recalculate daily lifetime and ocean without cached totals',
    () async {
      final database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final repo = TimeRecordsRepository(database);
      final bottle = await repo.createBottle(name: '学习', color: 1);
      final start = DateTime(2020, 1, 1, 9);
      final now = DateTime(2020, 1, 1, 12);
      final entry = await repo.createManualEntry(
        bottleId: bottle.id!,
        startedAt: start,
        endedAt: DateTime(2020, 1, 1, 10),
      );
      await repo.updateEntry(
        id: entry.id!,
        startedAt: start,
        endedAt: DateTime(2020, 1, 1, 11),
      );
      var entries = await repo.fetchEntries();
      var daily = TimeStatistics.forDate(
        date: start,
        now: now,
        entries: entries,
      );
      expect(daily.recorded, const Duration(hours: 2));
      expect(daily.elapsed, daily.recorded + daily.unallocated);
      expect(
        TimeStatistics.lifetime(
          bottleId: bottle.id!,
          now: now,
          entries: entries,
        ).total,
        const Duration(hours: 2),
      );
      await repo.deleteEntry(entry.id!);
      entries = await repo.fetchEntries();
      daily = TimeStatistics.forDate(date: start, now: now, entries: entries);
      expect(daily.recorded, Duration.zero);
      expect(daily.unallocated, daily.elapsed);
      expect(
        TimeStatistics.lifetime(
          bottleId: bottle.id!,
          now: now,
          entries: entries,
        ).total,
        Duration.zero,
      );
    },
  );

  test(
    'editing into another interval fails without changing either record',
    () async {
      final database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final repo = TimeRecordsRepository(database);
      final bottle = await repo.createBottle(name: '学习', color: 1);
      final entry = await repo.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2020, 1, 1, 9),
        endedAt: DateTime(2020, 1, 1, 10),
      );
      await repo.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2020, 1, 1, 11),
        endedAt: DateTime(2020, 1, 1, 12),
      );
      final before = await database.database.query('time_entries');
      await expectLater(
        repo.updateEntry(
          id: entry.id!,
          startedAt: DateTime(2020, 1, 1, 9),
          endedAt: DateTime(2020, 1, 1, 11, 1),
        ),
        throwsException,
      );
      expect(await database.database.query('time_entries'), before);
    },
  );

  test(
    'permanent monthly totals split records spanning a month boundary',
    () async {
      final database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final repo = TimeRecordsRepository(database);
      final bottle = await repo.createBottle(name: '学习', color: 1);
      await repo.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2020, 1, 31, 23),
        endedAt: DateTime(2020, 2, 1, 1),
      );
      final stats = TimeStatistics.lifetime(
        bottleId: bottle.id!,
        now: DateTime(2020, 3),
        entries: await repo.fetchEntries(),
      );
      expect(stats.total, const Duration(hours: 2));
      expect(stats.byMonth['2020-01'], const Duration(hours: 1));
      expect(stats.byMonth['2020-02'], const Duration(hours: 1));
    },
  );
}
