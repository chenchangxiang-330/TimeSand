import 'package:flutter_test/flutter_test.dart';

import 'package:timesand/core/time/day_window.dart';

void main() {
  group('DayWindow', () {
    test('creates local-day boundaries without assuming 24 hours', () {
      final instant = DateTime(2026, 10, 12, 14, 30);
      final window = DayWindow.forInstant(instant);

      expect(window.start, DateTime(2026, 10, 12));
      expect(window.end, DateTime(2026, 10, 13));
      expect(window.contains(instant), isTrue);
    });

    test('supports UTC dates as a separate calendar context', () {
      final instant = DateTime.utc(2026, 10, 12, 23, 59);
      final window = DayWindow.forInstant(instant);

      expect(window.start, DateTime.utc(2026, 10, 12));
      expect(window.end, DateTime.utc(2026, 10, 13));
      expect(window.total, const Duration(hours: 24));
    });
  });

  group('TimeSnapshot', () {
    final window = DayWindow(
      start: DateTime.utc(2026, 10, 12),
      end: DateTime.utc(2026, 10, 13),
    );

    test('calculates elapsed, remaining, and progress', () {
      final snapshot = TimeSnapshot.forWindow(
        window,
        DateTime.utc(2026, 10, 12, 12),
      );

      expect(snapshot.elapsed, const Duration(hours: 12));
      expect(snapshot.remaining, const Duration(hours: 12));
      expect(snapshot.progress, 0.5);
    });

    test('returns zero at the start boundary', () {
      final snapshot = TimeSnapshot.forWindow(window, window.start);

      expect(snapshot.elapsed, Duration.zero);
      expect(snapshot.remaining, window.total);
      expect(snapshot.progress, 0);
    });

    test('returns the full window at the end boundary', () {
      final snapshot = TimeSnapshot.forWindow(window, window.end);

      expect(snapshot.elapsed, window.total);
      expect(snapshot.remaining, Duration.zero);
      expect(snapshot.progress, 1);
    });

    test('clamps values before and after the window', () {
      final before = TimeSnapshot.forWindow(
        window,
        window.start.subtract(const Duration(minutes: 1)),
      );
      final after = TimeSnapshot.forWindow(
        window,
        window.end.add(const Duration(minutes: 1)),
      );

      expect(before.elapsed, Duration.zero);
      expect(before.remaining, window.total);
      expect(before.progress, 0);
      expect(after.elapsed, window.total);
      expect(after.remaining, Duration.zero);
      expect(after.progress, 1);
    });

    test('supports a 23-hour natural day', () {
      final shortWindow = DayWindow(
        start: DateTime.utc(2026, 3, 29),
        end: DateTime.utc(2026, 3, 29, 23),
      );
      final snapshot = TimeSnapshot.forWindow(
        shortWindow,
        DateTime.utc(2026, 3, 29, 22),
      );

      expect(shortWindow.total, const Duration(hours: 23));
      expect(snapshot.elapsed, const Duration(hours: 22));
      expect(snapshot.remaining, const Duration(hours: 1));
      expect(snapshot.progress, closeTo(22 / 23, 0.000001));
    });

    test('supports a 25-hour natural day', () {
      final longWindow = DayWindow(
        start: DateTime.utc(2026, 10, 25),
        end: DateTime.utc(2026, 10, 26, 1),
      );
      final snapshot = TimeSnapshot.forWindow(
        longWindow,
        DateTime.utc(2026, 10, 25, 12),
      );

      expect(longWindow.total, const Duration(hours: 25));
      expect(snapshot.elapsed, const Duration(hours: 12));
      expect(snapshot.remaining, const Duration(hours: 13));
      expect(snapshot.progress, closeTo(12 / 25, 0.000001));
    });

    test('never produces negative durations or progress outside bounds', () {
      final snapshot = TimeSnapshot.forWindow(
        window,
        DateTime.utc(2026, 10, 12, 23, 59, 59),
      );

      expect(snapshot.elapsed.isNegative, isFalse);
      expect(snapshot.remaining.isNegative, isFalse);
      expect(snapshot.progress, inInclusiveRange(0, 1));
    });
  });
}
