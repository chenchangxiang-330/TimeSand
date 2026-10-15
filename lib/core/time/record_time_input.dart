/// Parses a user-entered calendar time without DateTime.parse's overflow repair.
/// Editing an existing entry requires an explicit offset to retain its instant.
DateTime parseRecordTime(String value, {bool requireOffset = false}) {
  final input = value.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?(Z|[+-]\d{2}:\d{2})?$',
  ).firstMatch(input);
  if (match == null ||
      (requireOffset && (match.group(6) == null || match.group(8) == null))) {
    throw const FormatException('请保留日期、秒数和时区偏移，或输入有效的本地日期和时间。');
  }
  final parts = [
    for (var i = 1; i <= 5; i++) int.parse(match.group(i)!),
    int.parse(match.group(6) ?? '0'),
  ];
  bool matches(DateTime date) =>
      date.year == parts[0] &&
      date.month == parts[1] &&
      date.day == parts[2] &&
      date.hour == parts[3] &&
      date.minute == parts[4] &&
      date.second == parts[5];
  if (!matches(
    DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]),
  )) {
    throw const FormatException('日期或时间不存在。');
  }
  final zone = match.group(8);
  if (zone != null &&
      zone != 'Z' &&
      (int.parse(zone.substring(1, 3)) > 23 ||
          int.parse(zone.substring(4, 6)) > 59)) {
    throw const FormatException('时区偏移无效。');
  }
  final parsed = DateTime.parse(input);
  if (zone == null && !matches(parsed)) {
    throw const FormatException('此本地时间因夏令时变化而不存在，请提供明确时区偏移。');
  }
  return parsed;
}
