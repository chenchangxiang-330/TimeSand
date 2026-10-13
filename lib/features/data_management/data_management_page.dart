import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/local_data_transfer.dart';
import '../../core/database/time_records_repository.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({required this.repository, super.key});

  final TimeRecordsRepository repository;

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本地数据')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            '数据只保存在本设备。导出备份不会包含密钥、系统路径或账户信息。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('export-json-button'),
                  leading: const Icon(Icons.data_object),
                  title: const Text('导出 JSON 备份'),
                  subtitle: const Text('包含瓶子、时间记录和数据库元信息'),
                  onTap: _busy ? null : () => _exportJson(context),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('export-csv-button'),
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('导出 CSV'),
                  subtitle: const Text('适合在表格工具中查看时间记录'),
                  onTap: _busy ? null : () => _exportCsv(context),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('import-json-button'),
                  leading: const Icon(Icons.restore_page_outlined),
                  title: const Text('从 JSON 恢复'),
                  subtitle: const Text('导入前会校验格式、时间区间和瓶子引用'),
                  onTap: _busy ? null : () => _importJson(context),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context) async {
    await _shareFile(
      context,
      filename: 'timesand-backup.json',
      mimeType: 'application/json',
      contents: await LocalDataTransfer.exportJson(widget.repository),
      title: 'TimeSand JSON 备份',
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    await _shareFile(
      context,
      filename: 'timesand-time-entries.csv',
      mimeType: 'text/csv',
      contents: await LocalDataTransfer.exportCsv(widget.repository),
      title: 'TimeSand CSV',
    );
  }

  Future<void> _shareFile(
    BuildContext context, {
    required String filename,
    required String mimeType,
    required String contents,
    required String title,
  }) async {
    setState(() => _busy = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: title,
          files: <XFile>[
            XFile.fromData(
              utf8.encode(contents),
              mimeType: mimeType,
            ),
          ],
          fileNameOverrides: <String>[filename],
        ),
      );
      if (mounted) {
        _showMessage(context, '已打开系统分享面板。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, '导出失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importJson(BuildContext context) async {
    setState(() => _busy = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'TimeSand JSON',
        extensions: <String>['json'],
        mimeTypes: <String>['application/json'],
      );
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[typeGroup],
      );
      if (file == null) {
        return;
      }
      final raw = await file.readAsString();
      final preview = LocalDataTransfer.previewJson(raw);
      if (!mounted) {
        return;
      }
      final mode = await _showImportPreview(context, preview);
      if (mode == null) {
        return;
      }
      await LocalDataTransfer.importJson(
        widget.repository,
        raw,
        mode: mode,
      );
      if (mounted) {
        _showMessage(
          context,
          '导入成功：${preview.bottleCount} 个瓶子，${preview.entryCount} 条记录。',
        );
      }
    } on LocalDataTransferException catch (error) {
      if (mounted) {
        _showMessage(context, '导入失败：${error.message}');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<ImportMode?> _showImportPreview(
    BuildContext context,
    ImportPreview preview,
  ) async {
    var mode = preview.mode;
    return showDialog<ImportMode>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('确认导入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('格式版本：${preview.formatVersion}'),
              Text('时区：${preview.timezone}'),
              Text('瓶子：${preview.bottleCount} 个'),
              Text('时间记录：${preview.entryCount} 条'),
              const SizedBox(height: 16),
              RadioListTile<ImportMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('覆盖恢复'),
                subtitle: const Text('删除当前本地数据后恢复备份'),
                value: ImportMode.replace,
                groupValue: mode,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => mode = value);
                  }
                },
              ),
              RadioListTile<ImportMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('合并导入'),
                subtitle: const Text('保留当前数据并追加备份内容'),
                value: ImportMode.merge,
                groupValue: mode,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => mode = value);
                  }
                },
              ),
              if (mode == ImportMode.replace)
                Text(
                  '覆盖恢复会删除当前瓶子和时间记录，此操作不可撤销。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, mode),
              child: const Text('确认导入'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
