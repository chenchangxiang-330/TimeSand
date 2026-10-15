import 'package:flutter_test/flutter_test.dart';
import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/features/history/history_filter.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);

  TimeEntry entry({
    required int id,
    required int bottleId,
    required DateTime start,
    required DateTime end,
  }) {
    return TimeEntry(
      id: id,
      bottleId: bottleId,
      startedAt: start,
      endedAt: end,
      durationSeconds: end.difference(start).inSeconds,
      source: TimeEntrySource.manual,
      createdAt: start,
      updatedAt: end,
    );
  }

  test('filters by local date and clips a cross-midnight interval', () {
    final crossing = entry(
      id: 1,
      bottleId: 1,
      start: DateTime(2026, 10, 14, 23, 30),
      end: DateTime(2026, 10, 15, 1, 30),
    );
    final result = HistoryFilter.apply(
      entries: <TimeEntry>[crossing],
      date: DateTime(2026, 10, 15),
      now: now,
    );
    expect(result, hasLength(1));
    expect(
      HistoryFilter.intersectionDuration(
        entry: crossing,
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 10, 16),
        now: now,
      ),
      const Duration(minutes: 90),
    );
  });

  test('filters by month and bottle', () {
    final entries = <TimeEntry>[
      entry(
        id: 1,
        bottleId: 1,
        start: DateTime(2026, 10, 1, 9),
        end: DateTime(2026, 10, 1, 10),
      ),
      entry(
        id: 2,
        bottleId: 2,
        start: DateTime(2026, 11, 1, 9),
        end: DateTime(2026, 11, 1, 10),
      ),
    ];
    expect(
      HistoryFilter.apply(
        entries: entries,
        month: DateTime(2026, 10),
        bottleId: 1,
        now: now,
      ),
      hasLength(1),
    );
  });
}
