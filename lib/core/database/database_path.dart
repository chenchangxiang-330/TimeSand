import 'dart:io';

/// Retain an existing database in place. A permissions/read error must never
/// silently switch the user to an empty database.
Future<String> resolveDatabasePath({
  required bool isAndroid,
  required String legacyPath,
  required Future<Directory> Function() supportDirectory,
}) async {
  if (!isAndroid) return legacyPath;

  try {
    final existing = await File(legacyPath).open(mode: FileMode.read);
    await existing.close();
    return legacyPath;
  } on FileSystemException catch (error) {
    // Android/POSIX: only ENOENT and ENOTDIR mean the old file is absent.
    // Other failures propagate to the retry screen without changing data.
    final code = error.osError?.errorCode;
    if (code != 2 && code != 20) rethrow;
  }

  final directory = await supportDirectory();
  await directory.create(recursive: true);
  return '${directory.path}/timesand.db';
}
