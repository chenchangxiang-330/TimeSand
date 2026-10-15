import 'package:flutter_test/flutter_test.dart';
import 'package:timesand/core/time/record_time_input.dart';

void main() {
  test('accepts local minutes and preserves explicit offset and precision', () {
    expect(parseRecordTime('2020-02-29 09:30'), DateTime(2020, 2, 29, 9, 30));
    expect(
      parseRecordTime('2020-02-29T09:30:15.123456+08:00', requireOffset: true),
      DateTime.utc(2020, 2, 29, 1, 30, 15, 123, 456),
    );
  });
  test('rejects impossible dates, times and offsets without normalization', () {
    for (final input in [
      '2020-02-30 09:00',
      '2021-02-29 09:00',
      '2020-13-01 09:00',
      '2020-01-01 24:00',
      '2020-01-01 09:60',
      '2020-01-01T09:00:00+24:00',
      '2020-01-01T09:00:00+08:60',
    ]) {
      expect(
        () => parseRecordTime(input),
        throwsFormatException,
        reason: input,
      );
    }
  });
  test('editing requires seconds and explicit time zone', () {
    for (final input in ['2020-01-01 09:00', '2020-01-01T09:00:00']) {
      expect(
        () => parseRecordTime(input, requireOffset: true),
        throwsFormatException,
      );
    }
  });
}
