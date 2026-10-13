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
      if (bottleId != null && entry.bottleId != bottleId) {
        return false;
      }
      if (date != null && !_intersectsDay(entry, DayWindow.forDate(date), referenceNow)) {
        return false;
      }
      if (month != null && !_intersectsMonth(entry, month, referenceNow)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static bool _intersectsDay(
    TimeEntry entry,
    DayWindow window,
    DateTime now,
  ) {
    return _intersects(entry, window.start, window.end, now);
  }

  static bool _intersectsMonth(
    TimeEntry entry,
    DateTime month,
    DateTime now,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _intersects(entry, start, end, now);
  }

  static bool _intersects(
    TimeEntry entry,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime now,
  ) {
    final end = (entry.endedAt ?? now).isAfter(now) ? now : entry.endedAt ?? now;
    return entry.startedAt.isBefore(windowEnd) && end.isAfter(windowStart);
  }
}
