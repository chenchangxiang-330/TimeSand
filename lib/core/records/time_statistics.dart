import '../time/day_window.dart';
import 'time_models.dart';

class DailyTimeStats {
  const DailyTimeStats({
    required this.date,
    required this.window,
    required this.elapsed,
    required this.recorded,
    required this.unallocated,
    required this.byBottle,
  });

  final DateTime date;
  final DayWindow window;
  final Duration elapsed;
  final Duration recorded;
  final Duration unallocated;
  final Map<int, Duration> byBottle;

  Duration forBottle(int bottleId) => byBottle[bottleId] ?? Duration.zero;
}

class LifetimeTimeStats {
  const LifetimeTimeStats({
    required this.total,
    required this.entryCount,
    required this.byMonth,
  });

  final Duration total;
  final int entryCount;
  final Map<String, Duration> byMonth;
}

abstract final class TimeStatistics {
  static DailyTimeStats forDate({
    required DateTime date,
    required DateTime now,
    required Iterable<TimeEntry> entries,
  }) {
    final window = DayWindow.forDate(date);
    final snapshot = TimeSnapshot.forWindow(window, now);
    final byBottle = <int, Duration>{};

    for (final entry in entries) {
      final duration = _intersection(entry, window, now);
      if (duration <= Duration.zero) {
        continue;
      }
      byBottle.update(
        entry.bottleId,
        (current) => current + duration,
        ifAbsent: () => duration,
      );
    }

    final recorded = byBottle.values.fold<Duration>(
      Duration.zero,
      (total, value) => total + value,
    );
    final unallocated = snapshot.elapsed > recorded
        ? snapshot.elapsed - recorded
        : Duration.zero;

    return DailyTimeStats(
      date: date,
      window: window,
      elapsed: snapshot.elapsed,
      recorded: recorded,
      unallocated: unallocated,
      byBottle: Map.unmodifiable(byBottle),
    );
  }

  static Duration totalForBottleOnDate({
    required int bottleId,
    required DateTime date,
    required DateTime now,
    required Iterable<TimeEntry> entries,
  }) {
    return forDate(date: date, now: now, entries: entries).forBottle(bottleId);
  }

  static LifetimeTimeStats lifetime({
    required int bottleId,
    required DateTime now,
    required Iterable<TimeEntry> entries,
  }) {
    var total = Duration.zero;
    var count = 0;
    final byMonth = <String, Duration>{};

    for (final entry in entries.where((entry) => entry.bottleId == bottleId)) {
      final rawEnd = entry.endedAt ?? now;
      final end = rawEnd.isAfter(now) ? now : rawEnd;
      if (!end.isAfter(entry.startedAt)) continue;
      total += end.difference(entry.startedAt);
      count++;
      var cursor = entry.startedAt.toLocal();
      while (cursor.isBefore(end)) {
        final monthEnd = DateTime(cursor.year, cursor.month + 1);
        final segmentEnd = monthEnd.isBefore(end) ? monthEnd : end;
        final key = cursor.year.toString().padLeft(4, '0') + '-' +
            cursor.month.toString().padLeft(2, '0');
        final duration = segmentEnd.difference(cursor);
        byMonth.update(key, (value) => value + duration, ifAbsent: () => duration);
        cursor = segmentEnd.toLocal();
      }
    }

    return LifetimeTimeStats(
      total: total,
      entryCount: count,
      byMonth: Map.unmodifiable(byMonth),
    );
  }

  static Duration _intersection(
    TimeEntry entry,
    DayWindow window,
    DateTime now,
  ) {
    final rawEnd = entry.endedAt ?? now;
    final end = rawEnd.isAfter(now) ? now : rawEnd;
    final start = entry.startedAt.isBefore(window.start)
        ? window.start
        : entry.startedAt;
    final cappedEnd = end.isAfter(window.end) ? window.end : end;
    if (!cappedEnd.isAfter(start)) {
      return Duration.zero;
    }
    return cappedEnd.difference(start);
  }
}
