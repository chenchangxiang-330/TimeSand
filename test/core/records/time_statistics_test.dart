import 'package:flutter_test/flutter_test.dart';

import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/core/records/time_statistics.dart';

TimeEntry entry({
  required int bottleId,
  required DateTime startedAt,
  DateTime? endedAt,
  TimeEntrySource source = TimeEntrySource.manual,
}) {
  return TimeEntry(
    id: null,
    bottleId: bottleId,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: endedAt?.difference(startedAt).inSeconds,
    source: source,
    createdAt: startedAt,
    updatedAt: startedAt,
  );
}

void main() {
  test('computes ocean time from elapsed minus recorded time', () {
    final now = DateTime(2026, 10, 13, 12);
    final stats = TimeStatistics.forDate(
      date: now,
      now: now,
      entries: [
        entry(
          bottleId: 1,
          startedAt: DateTime(2026, 10, 13, 9),
          endedAt: DateTime(2026, 10, 13, 10),
        ),
      ],
    );

    expect(stats.elapsed, const Duration(hours: 12));
    expect(stats.recorded, const Duration(hours: 1));
    expect(stats.unallocated, const Duration(hours: 11));
    expect(stats.forBottle(1), const Duration(hours: 1));
  });

  test('splits an entry across midnight into local daily windows', () {
    final entryAcrossMidnight = entry(
      bottleId: 2,
      startedAt: DateTime(2026, 10, 12, 23, 30),
      endedAt: DateTime(2026, 10, 13, 0, 30),
    );

    final previous = TimeStatistics.forDate(
      date: DateTime(2026, 10, 12, 23),
      now: DateTime(2026, 10, 13, 1),
      entries: [entryAcrossMidnight],
    );
    final current = TimeStatistics.forDate(
      date: DateTime(2026, 10, 13, 1),
      now: DateTime(2026, 10, 13, 1),
      entries: [entryAcrossMidnight],
    );

    expect(previous.recorded, const Duration(minutes: 30));
    expect(current.recorded, const Duration(minutes: 30));
  });

  test('includes a running entry only up to the supplied clock time', () {
    final now = DateTime(2026, 10, 13, 11);
    final stats = TimeStatistics.forDate(
      date: now,
      now: now,
      entries: [
        entry(
          bottleId: 3,
          startedAt: DateTime(2026, 10, 13, 10),
          source: TimeEntrySource.active,
        ),
      ],
    );

    expect(stats.recorded, const Duration(hours: 1));
    expect(stats.unallocated, const Duration(hours: 10));
  });

  test('calculates permanent growth totals and monthly buckets', () {
    final now = DateTime(2026, 10, 13);
    final stats = TimeStatistics.lifetime(
      bottleId: 4,
      now: now,
      entries: [
        entry(
          bottleId: 4,
          startedAt: DateTime(2026, 9, 30, 23),
          endedAt: DateTime(2026, 10, 1),
        ),
        entry(
          bottleId: 4,
          startedAt: DateTime(2026, 10, 12, 9),
          endedAt: DateTime(2026, 10, 12, 11),
        ),
      ],
    );

    expect(stats.total, const Duration(hours: 3));
    expect(stats.entryCount, 2);
    expect(stats.byMonth['2026-09'], const Duration(hours: 1));
    expect(stats.byMonth['2026-10'], const Duration(hours: 2));
  });

  test('never reports negative ocean time', () {
    final now = DateTime(2026, 10, 13, 1);
    final stats = TimeStatistics.forDate(
      date: now,
      now: now,
      entries: [
        entry(
          bottleId: 5,
          startedAt: DateTime(2026, 10, 12, 23),
          endedAt: DateTime(2026, 10, 13, 2),
        ),
      ],
    );

    expect(stats.unallocated.isNegative, isFalse);
  });
}
