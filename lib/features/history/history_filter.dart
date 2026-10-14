import '../../core/records/time_models.dart';
import '../../core/time/day_window.dart';

abstract final class HistoryFilter {
  static List<TimeEntry> apply({
    required Iterable<TimeEntry> entries,
    DateTime? date,
    DateTime? month,
    int? bottleId,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    return entries.where((entry) {
      if (bottleId != null && entry.bottleId != bottleId) return false;
      if (date != null &&
          intersectionDuration(
                entry: entry,
                start: DayWindow.forDate(date).start,
                end: DayWindow.forDate(date).end,
                now: referenceNow,
              ) <=
              Duration.zero) {
        return false;
      }
      if (month != null &&
          intersectionDuration(
                entry: entry,
                start: DateTime(month.year, month.month),
                end: DateTime(month.year, month.month + 1),
                now: referenceNow,
              ) <=
              Duration.zero) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static Duration intersectionDuration({
    required TimeEntry entry,
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) {
    final rawEnd = entry.endedAt ?? now;
    final effectiveEnd = rawEnd.isAfter(now) ? now : rawEnd;
    final effectiveStart =
        entry.startedAt.isAfter(start) ? entry.startedAt : start;
    final cappedEnd = effectiveEnd.isBefore(end) ? effectiveEnd : end;
    if (!cappedEnd.isAfter(effectiveStart)) return Duration.zero;
    return cappedEnd.difference(effectiveStart);
  }
}
