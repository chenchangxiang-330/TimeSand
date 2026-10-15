import 'package:flutter/material.dart';

import '../../core/database/local_data_transfer.dart';
import '../../core/database/time_records_repository.dart';
import 'backup_files.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({required this.repository, this.files, super.key});

  final TimeRecordsRepository repository;
  final BackupFiles? files;

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _busy = false;

  BackupFiles get _files => widget.files ?? NativeBackupFiles();

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
            const Center(child: Text('正在处理…')),
          ],
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context) => _export(context, true);
  Future<void> _exportCsv(BuildContext context) => _export(context, false);

  Future<void> _export(BuildContext context, bool json) async {
    setState(() => _busy = true);
    try {
      final contents = json
          ? await LocalDataTransfer.exportJson(widget.repository)
          : await LocalDataTransfer.exportCsv(widget.repository);
      final message = await _files.saveText(
        fileName: json ? 'timesand-backup.json' : 'timesand-time-entries.csv',
        mimeType: json ? 'application/json' : 'text/csv',
        contents: contents,
      );
      if (mounted) _showMessage(context, message);
    } on LocalDataTransferException catch (error) {
      if (mounted) _showMessage(context, '导出失败：' + error.message);
    } catch (_) {
      if (mounted) _showMessage(context, '导出失败，请检查保存位置或重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importJson(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final raw = await _files.pickJson();
      if (raw == null) return;
      final preview = LocalDataTransfer.previewJson(
        raw,
        mode: ImportMode.merge,
      );
      if (!mounted) return;
      final mode = await _showImportPreview(context, preview);
      if (mode == null) return;
      if (mode == ImportMode.replace &&
          await _confirmReplacement(context) != true) {
        return;
      }
      await LocalDataTransfer.importJson(widget.repository, raw, mode: mode);
      if (mounted) {
        _showMessage(
          context,
          '导入成功：' +
              preview.bottleCount.toString() +
              ' 个瓶子，' +
              preview.entryCount.toString() +
              ' 条记录。',
        );
      }
    } on LocalDataTransferException catch (error) {
      if (mounted) _showMessage(context, '导入失败：' + error.message);
    } catch (error) {
      if (mounted) _showMessage(context, '导入失败，原有数据保持完整。请检查备份格式或重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
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
          scrollable: true,
          title: const Text('确认导入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('格式版本：' + preview.formatVersion.toString()),
              Text('时区：' + preview.timezone),
              Text('瓶子：' + preview.bottleCount.toString() + ' 个'),
              Text('时间记录：' + preview.entryCount.toString() + ' 条'),
              const SizedBox(height: 16),
              DropdownButtonFormField<ImportMode>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: '导入模式'),
                initialValue: mode,
                items: const [
                  DropdownMenuItem(
                    value: ImportMode.merge,
                    child: Text('合并导入：保留当前数据', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: ImportMode.replace,
                    child: Text('覆盖恢复：替换当前数据', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => mode = value);
                },
              ),
              if (mode == ImportMode.replace)
                Text(
                  '下一步还会再次确认。覆盖恢复会删除当前数据，此操作不可撤销。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
              child: const Text('查看并确认'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmReplacement(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('确认覆盖恢复？'),
        content: const Text('当前瓶子和时间记录将被备份内容替换，原有数据不会自动保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认覆盖'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
