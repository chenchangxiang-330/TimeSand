import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.repository, super.key});

  final TimeRecordsRepository repository;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TimeEntry> _entries = const [];
  List<Bottle> _bottles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      widget.repository.fetchEntries(),
      widget.repository.fetchBottles(includeArchived: true),
    ]);
    if (mounted) {
      setState(() {
        _entries = results[0] as List<TimeEntry>;
        _bottles = results[1] as List<Bottle>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = <int, String>{
      for (final bottle in _bottles) bottle.id!: bottle.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            key: const ValueKey('manual-entry-button'),
            tooltip: '补录时间',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: _bottles.isEmpty
                ? null
                : () => _createManualEntry(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _entries.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('还没有历史投入记录。')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        for (final entry in _entries.reversed)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                entry.source == TimeEntrySource.active
                                    ? Icons.timer_outlined
                                    : Icons.edit_calendar_outlined,
                              ),
                              title: Text(names[entry.bottleId] ?? '已归档的时间之瓶'),
                              subtitle: Text(_formatInterval(entry)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatRecordDuration(
                                      entry.durationAt(DateTime.now()),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '删除记录',
                                    onPressed: () => _deleteEntry(entry),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }

  Future<void> _createManualEntry(BuildContext context) async {
    final result = await _showManualEntryDialog(context);
    if (result == null) {
      return;
    }
    try {
      await widget.repository.createManualEntry(
        bottleId: result.$1.id!,
        startedAt: result.$2,
        endedAt: result.$3,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _deleteEntry(TimeEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除时间记录？'),
        content: const Text('删除后每日瓶、永久成长瓶和时间海洋会重新计算。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await widget.repository.deleteEntry(entry.id!);
      await _load();
    }
  }

  Future<(Bottle, DateTime, DateTime)?> _showManualEntryDialog(
    BuildContext context,
  ) async {
    final now = DateTime.now();
    final startController = TextEditingController(
      text: _formatInput(now.subtract(const Duration(hours: 1))),
    );
    final endController = TextEditingController(text: _formatInput(now));
    Bottle selectedBottle = _bottles.first;
    final result = await showDialog<(Bottle, DateTime, DateTime)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('补录时间'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Bottle>(
                  value: selectedBottle,
                  decoration: const InputDecoration(labelText: '时间之瓶'),
                  items: [
                    for (final bottle in _bottles)
                      DropdownMenuItem(value: bottle, child: Text(bottle.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedBottle = value);
                    }
                  },
                ),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: '开始时间',
                    hintText: '2026-10-13 09:00',
                  ),
                ),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: '结束时间',
                    hintText: '2026-10-13 10:00',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final start = DateTime.parse(startController.text.trim());
                  final end = DateTime.parse(endController.text.trim());
                  if (!end.isAfter(start)) {
                    return;
                  }
                  Navigator.pop(dialogContext, (selectedBottle, start, end));
                } on FormatException {
                  return;
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    startController.dispose();
    endController.dispose();
    return result;
  }

  String _formatInterval(TimeEntry entry) {
    final start = entry.startedAt.toLocal();
    final date =
        start.year.toString() +
        '-' +
        start.month.toString().padLeft(2, '0') +
        '-' +
        start.day.toString().padLeft(2, '0');
    final time = start.toString().substring(11, 16);
    return entry.endedAt == null ? '$date $time · 进行中' : '$date $time';
  }

  String _formatInput(DateTime value) {
    return value.year.toString().padLeft(4, '0') +
        '-' +
        value.month.toString().padLeft(2, '0') +
        '-' +
        value.day.toString().padLeft(2, '0') +
        ' ' +
        value.hour.toString().padLeft(2, '0') +
        ':' +
        value.minute.toString().padLeft(2, '0');
  }
}
