import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_entry_rules.dart';
import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/core/records/time_statistics.dart';

void main() {
  late TimeSandDatabase database;
  late TimeRecordsRepository repository;
  late Bottle first;
  late Bottle second;
  late TimeEntry original;
  final startedAt = DateTime.utc(2026, 10, 27, 9);
  final boundary = startedAt.add(const Duration(minutes: 15));

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
    repository = TimeRecordsRepository(database);
    first = await repository.createBottle(name: '阅读', color: 0xFF4080C0);
    second = await repository.createBottle(name: '写作', color: 0xFFC08040);
    original = await repository.startTimer(
      bottleId: first.id!,
      startedAt: startedAt,
    );
  });
  tearDown(() => database.close());

  Future<List<Map<String, Object?>>> snapshot() =>
      database.database.query('time_entries', orderBy: 'id');

  Future<void> expectRejected(
    Future<TimeEntry> Function() action,
    Matcher error,
  ) async {
    final before = await snapshot();
    await expectLater(action(), throwsA(error));
    expect(await snapshot(), before);
    expect((await repository.fetchActiveEntry())?.id, original.id);
  }

  test('switches at a contiguous UTC boundary and conserves recorded time', () async {
    final next = await repository.switchTimer(
      expectedActiveEntryId: original.id!,
      bottleId: second.id!,
      at: boundary.toLocal(),
    );

    final entries = await repository.fetchEntries();
    expect(entries, hasLength(2));
    final closed = entries.firstWhere((entry) => entry.id == original.id);
    expect(closed.endedAt!.isAtSameMomentAs(boundary), isTrue);
    expect(closed.durationSeconds, 15 * 60);
    expect(closed.createdAt, original.createdAt);
    expect(next.id, isNot(original.id));
    expect(next.bottleId, second.id);
    expect(next.isActive, isTrue);
    expect(next.source, TimeEntrySource.active);
    expect(next.startedAt.isAtSameMomentAs(closed.endedAt!), isTrue);
    expect(entries.where((entry) => entry.isActive), hasLength(1));
    expect((await repository.fetchActiveEntry())?.id, next.id);
    final rows = await snapshot();
    expect(rows.first['ended_at'], boundary.toIso8601String());
    expect(rows.last['started_at'], boundary.toIso8601String());

    final now = boundary.add(const Duration(minutes: 15));
    final daily = TimeStatistics.forDate(
      date: now.toLocal(),
      now: now,
      entries: entries,
    );
    expect(daily.forBottle(first.id!), const Duration(minutes: 15));
    expect(daily.forBottle(second.id!), const Duration(minutes: 15));
    expect(daily.recorded, const Duration(minutes: 30));
    expect(daily.recorded + daily.unallocated, daily.elapsed);
  });

  test('rejects a confirmation for a different active entry', () async {
    await expectRejected(
      () => repository.switchTimer(
        expectedActiveEntryId: original.id! + 1,
        bottleId: second.id!,
        at: boundary,
      ),
      isA<StateError>(),
    );
  });

  test('rejects an archived target without stopping the current timer', () async {
    await repository.archiveBottle(second.id!);
    await expectRejected(
      () => repository.switchTimer(
        expectedActiveEntryId: original.id!,
        bottleId: second.id!,
        at: boundary,
      ),
      isA<StateError>(),
    );
  });

  test('rejects a missing target without stopping the current timer', () async {
    await expectRejected(
      () => repository.switchTimer(
        expectedActiveEntryId: original.id!,
        bottleId: second.id! + 100,
        at: boundary,
      ),
      isA<StateError>(),
    );
  });

  test('same-bottle requests are rejected without splitting the record', () async {
    await expectRejected(
      () => repository.switchTimer(
        expectedActiveEntryId: original.id!,
        bottleId: first.id!,
        at: boundary,
      ),
      isA<StateError>(),
    );
  });

  test('rejects a stale confirmation after the timer has stopped', () async {
    await repository.stopTimer(endedAt: boundary);
    final before = await snapshot();
    await expectLater(
      repository.switchTimer(
        expectedActiveEntryId: original.id!,
        bottleId: second.id!,
        at: boundary.add(const Duration(seconds: 1)),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await snapshot(), before);
    expect(await repository.fetchActiveEntry(), isNull);
  });

  test('repeating the old confirmation cannot create another timer', () async {
    final next = await repository.switchTimer(
      expectedActiveEntryId: original.id!,
      bottleId: second.id!,
      at: boundary,
    );
    final before = await snapshot();
    await expectLater(
      repository.switchTimer(
        expectedActiveEntryId: original.id!,
        bottleId: first.id!,
        at: boundary.add(const Duration(seconds: 1)),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await snapshot(), before);
    expect((await repository.fetchActiveEntry())?.id, next.id);
  });

  test('concurrent confirmations commit exactly one switch', () async {
    final third = await repository.createBottle(name: '运动', color: 0xFF40A080);
    Future<bool> attempt(int bottleId) async {
      try {
        await repository.switchTimer(
          expectedActiveEntryId: original.id!,
          bottleId: bottleId,
          at: boundary,
        );
        return true;
      } on StateError {
        return false;
      }
    }

    final results = await Future.wait([
      attempt(second.id!),
      attempt(third.id!),
    ]);
    expect(results.where((success) => success), hasLength(1));
    final entries = await repository.fetchEntries();
    expect(entries, hasLength(2));
    expect(entries.where((entry) => entry.isActive), hasLength(1));
    expect(
      entries.singleWhere((entry) => !entry.isActive).endedAt!
          .isAtSameMomentAs(boundary),
      isTrue,
    );
  });

  for (final offset in [Duration.zero, const Duration(microseconds: -1)]) {
    test('rejects a non-positive original interval ($offset)', () async {
      await expectRejected(
        () => repository.switchTimer(
          expectedActiveEntryId: original.id!,
          bottleId: second.id!,
          at: startedAt.add(offset),
        ),
        isA<InvalidTimeEntryException>(),
      );
    });
  }

  test('failed insertion rolls back the already closed original timer', () async {
    await database.database.execute('''
      CREATE TRIGGER reject_switch_insert
      BEFORE INSERT ON time_entries
      WHEN NEW.bottle_id = ${second.id}
        AND (SELECT ended_at FROM time_entries WHERE id = ${original.id})
          IS NOT NULL
      BEGIN
        SELECT RAISE(ABORT, 'injected switch failure after closing original');
      END
    ''');
    await expectRejected(
      () => repository.switchTimer(
        expectedActiveEntryId: original.id!,
        bottleId: second.id!,
        at: boundary,
      ),
      predicate<Object>(
        (error) => error.toString().contains(
          'injected switch failure after closing original',
        ),
        'the insertion trigger ran after the original record was closed',
      ),
    );
    final restored = (await repository.fetchEntries()).single;
    expect(restored.toMap(), original.toMap());
    expect(restored.durationSeconds, isNull);
  });

  for (final otherStart in [
    startedAt.add(const Duration(minutes: 5)),
    boundary.add(const Duration(minutes: 5)),
  ]) {
    test('rejects overlap with an existing interval at $otherStart', () async {
      // Simulate inconsistent pre-existing data to check both the ending
      // interval and the new open-ended interval before either is written.
      await database.database.insert(
        'time_entries',
        TimeEntry(
          bottleId: second.id!,
          startedAt: otherStart,
          endedAt: otherStart.add(const Duration(minutes: 2)),
          durationSeconds: 120,
          source: TimeEntrySource.manual,
          createdAt: startedAt,
          updatedAt: startedAt,
        ).toMap(),
      );
      await expectRejected(
        () => repository.switchTimer(
          expectedActiveEntryId: original.id!,
          bottleId: second.id!,
          at: boundary,
        ),
        isA<OverlappingTimeEntryException>(),
      );
    });
  }
}
