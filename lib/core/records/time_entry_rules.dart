import 'time_models.dart';

class InvalidTimeEntryException implements Exception {
  const InvalidTimeEntryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OverlappingTimeEntryException implements Exception {
  const OverlappingTimeEntryException();

  @override
  String toString() => '时间记录与已有记录重叠。';
}

class ActiveTimerConflictException implements Exception {
  const ActiveTimerConflictException();

  @override
  String toString() => '已经有一个正在进行的计时器。';
}

abstract final class TimeEntryRules {
  static void validateInterval({
    required DateTime startedAt,
    required DateTime? endedAt,
    required Iterable<TimeEntry> existingEntries,
    int? ignoredEntryId,
  }) {
    if (endedAt != null && !endedAt.isAfter(startedAt)) {
      throw const InvalidTimeEntryException('结束时间必须晚于开始时间。');
    }

    for (final entry in existingEntries) {
      if (ignoredEntryId != null && entry.id == ignoredEntryId) {
        continue;
      }

      final otherEnd = entry.endedAt;
      final overlaps = otherEnd == null
          ? endedAt == null || endedAt.isAfter(entry.startedAt)
          : endedAt == null
              ? startedAt.isBefore(otherEnd)
              : startedAt.isBefore(otherEnd) &&
                  endedAt.isAfter(entry.startedAt);

      if (overlaps) {
        throw const OverlappingTimeEntryException();
      }
    }
  }

  static void validateActiveTimer(Iterable<TimeEntry> entries) {
    if (entries.any((entry) => entry.isActive)) {
      throw const ActiveTimerConflictException();
    }
  }
}
