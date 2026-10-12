class DayWindow {
  const DayWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory DayWindow.forDate(DateTime date) {
    final DateTime start;
    final DateTime end;

    if (date.isUtc) {
      start = DateTime.utc(date.year, date.month, date.day);
      end = DateTime.utc(date.year, date.month, date.day + 1);
    } else {
      start = DateTime(date.year, date.month, date.day);
      end = DateTime(date.year, date.month, date.day + 1);
    }

    return DayWindow(start: start, end: end);
  }

  factory DayWindow.forInstant(DateTime instant) {
    return DayWindow.forDate(instant);
  }

  Duration get total => end.difference(start);

  bool contains(DateTime instant) {
    return !instant.isBefore(start) && instant.isBefore(end);
  }
}

class TimeSnapshot {
  const TimeSnapshot({
    required this.now,
    required this.window,
    required this.elapsed,
    required this.remaining,
    required this.progress,
  });

  final DateTime now;
  final DayWindow window;
  final Duration elapsed;
  final Duration remaining;
  final double progress;

  factory TimeSnapshot.at(DateTime now) {
    return TimeSnapshot.forWindow(DayWindow.forInstant(now), now);
  }

  factory TimeSnapshot.forWindow(DayWindow window, DateTime now) {
    final elapsed = _clampDuration(
      now.difference(window.start),
      Duration.zero,
      window.total,
    );
    final totalMicroseconds = window.total.inMicroseconds;
    final progress = totalMicroseconds == 0
        ? 0.0
        : (elapsed.inMicroseconds / totalMicroseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final remaining = window.total - elapsed;

    return TimeSnapshot(
      now: now,
      window: window,
      elapsed: elapsed,
      remaining: remaining,
      progress: progress,
    );
  }

  static Duration _clampDuration(
    Duration value,
    Duration minimum,
    Duration maximum,
  ) {
    if (value < minimum) {
      return minimum;
    }
    if (value > maximum) {
      return maximum;
    }
    return value;
  }
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
