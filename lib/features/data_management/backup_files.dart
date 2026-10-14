import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class BackupFiles {
  Future<String?> pickJson();
  Future<String> saveText({
    required String fileName,
    required String mimeType,
    required String contents,
  });
}

class NativeBackupFiles implements BackupFiles {
  @override
  Future<String?> pickJson() async {
    const group = XTypeGroup(
      label: 'TimeSand JSON',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json'],
      uniformTypeIdentifiers: <String>['public.json'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return null;
    const maxBytes = 20 * 1024 * 1024;
    if (await file.length() > maxBytes) {
      throw const FormatException('备份文件不能超过 20 MiB。');
    }
    return file.readAsString();
  }

  @override
  Future<String> saveText({
    required String fileName,
    required String mimeType,
    required String contents,
  }) async {
    final file = XFile.fromData(
      utf8.encode(contents),
      mimeType: mimeType,
      name: fileName,
    );
    if (Platform.isMacOS) {
      final location = await getSaveLocation(suggestedName: fileName);
      if (location == null) return '已取消导出。';
      await file.saveTo(location.path);
      return '文件已保存。';
    }
    final result = await SharePlus.instance.share(
      ShareParams(
        title: fileName,
        files: <XFile>[file],
        fileNameOverrides: <String>[fileName],
      ),
    );
    if (result.status == ShareResultStatus.dismissed) {
      return '已取消导出。';
    }
    return '已交给系统分享面板，请在所选应用中确认保存。';
  }
}
