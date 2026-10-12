String formatRecordDuration(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return hours.toString() + '小时 ' + minutes.toString().padLeft(2, '0') + '分';
  }
  if (minutes > 0) {
    return minutes.toString() + '分 ' + seconds.toString().padLeft(2, '0') + '秒';
  }
  return seconds.toString() + '秒';
}

String formatClockDuration(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return hours.toString().padLeft(2, '0') +
      ':' +
      minutes.toString().padLeft(2, '0') +
      ':' +
      seconds.toString().padLeft(2, '0');
}
