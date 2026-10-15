import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_models.dart';

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({
    required this.repository,
    required this.entry,
    super.key,
  });

  final TimeRecordsRepository repository;
  final TimeEntry entry;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  late final _start = TextEditingController(text: _input(widget.entry.startedAt));
  late final _end = TextEditingController(text: _input(widget.entry.endedAt!));
  String? _error;
  bool _saving = false;

  static String _input(DateTime date) {
    final local = date.toLocal();
    final offset = local.timeZoneOffset;
    final hours = offset.inMinutes.abs() ~/ 60;
    final minutes = offset.inMinutes.abs() % 60;
    return local.toIso8601String() +
        (offset.isNegative ? '-' : '+') +
        hours.toString().padLeft(2, '0') +
        ':' +
        minutes.toString().padLeft(2, '0');
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑时间记录')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('显示本地时间和时区偏移。保留秒数和时区可以避免跨日或夏令时歧义。'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('entry-start-input'),
            controller: _start,
            decoration: const InputDecoration(labelText: '开始时间'),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('entry-end-input'),
            controller: _end,
            decoration: const InputDecoration(labelText: '结束时间'),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('save-entry-button'),
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  DateTime _parse(String value) {
    final input = value.trim();
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
    ).firstMatch(input);
    if (match == null) throw const FormatException('请保留日期、秒数和时区偏移。');
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final calendar = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
    if (calendar.year != parts[0] || calendar.month != parts[1] ||
        calendar.day != parts[2] || calendar.hour != parts[3] ||
        calendar.minute != parts[4] || calendar.second != parts[5]) {
      throw const FormatException('日期或时间不存在。');
    }
    return DateTime.parse(input);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final start = _parse(_start.text);
      final end = _parse(_end.text);
      if (end.isAfter(DateTime.now())) {
        throw const FormatException('结束时间不能在未来。');
      }
      await widget.repository.updateEntry(
        id: widget.entry.id!,
        startedAt: start,
        endedAt: end,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
