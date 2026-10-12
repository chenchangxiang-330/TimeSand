import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_entry_rules.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
  });

  tearDown(() => database.close());

  test('creates, updates, and archives a bottle', () async {
    final created = await repository.createBottle(
      name: '学习',
      color: 0xFFE8C98D,
      now: DateTime(2026, 10, 13),
    );
    expect(created.id, isNotNull);
    expect((await repository.fetchBottles()).single.name, '学习');

    final updated = await repository.updateBottle(
      id: created.id!,
      name: '深度学习',
      color: 0xFF9AC7C5,
    );
    expect(updated.name, '深度学习');
    expect(updated.color, 0xFF9AC7C5);

    await repository.archiveBottle(created.id!);
    expect(await repository.fetchBottles(), isEmpty);
    expect(
      (await repository.fetchBottles(includeArchived: true)).single.isArchived,
      isTrue,
    );
  });

  test('persists and restores an active timer from the database', () async {
    final bottle = await repository.createBottle(
      name: '写作',
      color: 0xFFE8C98D,
    );
    final startedAt = DateTime(2026, 10, 13, 9);
    final active = await repository.startTimer(
      bottleId: bottle.id!,
      startedAt: startedAt,
    );

    expect(active.isActive, isTrue);
    final restored = await TimeRecordsRepository(database).fetchActiveEntry();
    expect(restored?.startedAt, startedAt);

    final stopped = await repository.stopTimer(
      endedAt: startedAt.add(const Duration(minutes: 45)),
    );
    expect(stopped.isActive, isFalse);
    expect(stopped.durationSeconds, 45 * 60);
  });

  test('blocks a second active timer', () async {
    final first = await repository.createBottle(name: '第一瓶', color: 1);
    final second = await repository.createBottle(name: '第二瓶', color: 2);
    await repository.startTimer(bottleId: first.id!);

    expect(
      () => repository.startTimer(bottleId: second.id!),
      throwsA(isA<ActiveTimerConflictException>()),
    );
  });

  test('rejects overlaps and allows touching boundaries', () async {
    final bottle = await repository.createBottle(name: '阅读', color: 3);
    final start = DateTime(2026, 10, 13, 10);
    await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
    );

    expect(
      () => repository.createManualEntry(
        bottleId: bottle.id!,
        startedAt: start.add(const Duration(minutes: 30)),
        endedAt: start.add(const Duration(hours: 2)),
      ),
      throwsA(isA<OverlappingTimeEntryException>()),
    );

    final touching = await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: start.add(const Duration(hours: 1)),
      endedAt: start.add(const Duration(hours: 2)),
    );
    expect(touching.durationSeconds, 3600);
  });

  test('deleting an entry removes it from all subsequent reads', () async {
    final bottle = await repository.createBottle(name: '运动', color: 4);
    final entry = await repository.createManualEntry(
      bottleId: bottle.id!,
      startedAt: DateTime(2026, 10, 13, 7),
      endedAt: DateTime(2026, 10, 13, 8),
    );
    await repository.deleteEntry(entry.id!);
    expect(await repository.fetchEntries(), isEmpty);
  });

  test('rejects invalid intervals', () async {
    final bottle = await repository.createBottle(name: '无效', color: 5);
    expect(
      () => repository.createManualEntry(
        bottleId: bottle.id!,
        startedAt: DateTime(2026, 10, 13, 8),
        endedAt: DateTime(2026, 10, 13, 8),
      ),
      throwsA(isA<InvalidTimeEntryException>()),
    );
  });
}
