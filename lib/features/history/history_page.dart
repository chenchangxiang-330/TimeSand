import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/records/time_statistics.dart';
import 'history_filter.dart';

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
  DateTime? _selectedDate;
  DateTime? _selectedMonth;
  int? _selectedBottleId;

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
    final now = DateTime.now();
    final names = <int, String>{
      for (final bottle in _bottles) bottle.id!: bottle.name,
    };
    final filteredEntries = HistoryFilter.apply(
      entries: _entries,
      date: _selectedDate,
      month: _selectedMonth,
      bottleId: _selectedBottleId,
      now: now,
    );
    final dayStats = _selectedDate == null
        ? null
        : TimeStatistics.forDate(
            date: _selectedDate!,
            now: now,
            entries: _entries,
          );
    final total = filteredEntries.fold<Duration>(
      Duration.zero,
      (sum, entry) {
        if (_selectedDate != null) {
          return sum +
              HistoryFilter.intersectionDuration(
                entry: entry,
                start: _selectedDate!,
                end: _selectedDate!.add(const Duration(days: 1)),
                now: now,
              );
        }
        if (_selectedMonth != null) {
          return sum +
              HistoryFilter.intersectionDuration(
                entry: entry,
                start: DateTime(_selectedMonth!.year, _selectedMonth!.month),
                end: DateTime(
                  _selectedMonth!.year,
                  _selectedMonth!.month + 1,
                ),
                now: now,
              );
        }
        return sum + entry.durationAt(now);
      },
    );

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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _buildFilters(context),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.insights_outlined),
                      title: Text(
                        dayStats == null
                            ? '筛选结果'
                            : '当天投入 ${formatRecordDuration(dayStats.recorded)}',
                      ),
                      subtitle: Text(
                        '${filteredEntries.length} 条记录 · '
                        '筛选范围 ${formatRecordDuration(total)}',
                      ),
                      trailing: dayStats == null
                          ? null
                          : Text(
                              '海洋 ${formatRecordDuration(dayStats.unallocated)}',
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredEntries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: Text('还没有历史投入记录。')),
                      ),
                    )
                  else
                    for (final entry in filteredEntries.reversed)
                      _buildEntryCard(context, entry, names, now),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final bottleLabel = _selectedBottleId == null
        ? '全部时间之瓶'
        : _bottles
              .firstWhere(
                (bottle) => bottle.id == _selectedBottleId,
                orElse: () => _bottles.first,
              )
              .name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('筛选历史', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('history-date-filter'),
                  onPressed: () => _chooseDate(context),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _selectedDate == null
                        ? '按日期'
                        : _formatDate(_selectedDate!),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('history-month-filter'),
                  onPressed: () => _chooseMonth(context),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _selectedMonth == null
                        ? '按月份'
                        : _formatMonth(_selectedMonth!),
                  ),
                ),
                DropdownButton<int?>(
                  key: const ValueKey('history-bottle-filter'),
                  value: _selectedBottleId,
                  hint: Text(bottleLabel),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部时间之瓶'),
                    ),
                    for (final bottle in _bottles)
                      DropdownMenuItem<int?>(
                        value: bottle.id,
                        child: Text(bottle.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedBottleId = value);
                  },
                ),
                if (_selectedDate != null ||
                    _selectedMonth != null ||
                    _selectedBottleId != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                        _selectedMonth = null;
                        _selectedBottleId = null;
                      });
                    },
                    child: const Text('清除筛选'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    TimeEntry entry,
    Map<int, String> names,
    DateTime now,
  ) {
    return Card(
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
            Text(formatRecordDuration(entry.durationAt(now))),
            IconButton(
              key: ValueKey('edit-entry-${entry.id}'),
              tooltip: '编辑记录',
              onPressed: () => _editEntry(context, entry),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: ValueKey('delete-entry-${entry.id}'),
              tooltip: '删除记录',
              onPressed: () => _deleteEntry(entry),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedMonth = null;
      });
    }
  }

  Future<void> _chooseMonth(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _selectedMonth = DateTime(date.year, date.month);
        _selectedDate = null;
      });
    }
  }

  Future<void> _createManualEntry(BuildContext context) async {
    final result = await _showEntryDialog(context);
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
      _showMessage(context, '已保存时间记录。');
    } catch (error) {
      _showMessage(context, '保存失败：$error');
    }
  }

  Future<void> _editEntry(BuildContext context, TimeEntry entry) async {
    final result = await _showEntryDialog(
      context,
      initialStart: entry.startedAt,
      initialEnd: entry.endedAt ?? DateTime.now(),
    );
    if (result == null) {
      return;
    }
    try {
      await widget.repository.updateEntry(
        id: entry.id!,
        startedAt: result.$2,
        endedAt: result.$3,
      );
      await _load();
      _showMessage(context, '已更新时间记录，统计已重新计算。');
    } catch (error) {
      _showMessage(context, '更新失败：$error');
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
      try {
        await widget.repository.deleteEntry(entry.id!);
        await _load();
        _showMessage(context, '已删除时间记录，统计已重新计算。');
      } catch (error) {
        _showMessage(context, '删除失败：$error');
      }
    }
  }

  Future<(Bottle, DateTime, DateTime)?> _showEntryDialog(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
  }) async {
    final now = DateTime.now();
    final startController = TextEditingController(
      text: _formatInput(initialStart ?? now.subtract(const Duration(hours: 1))),
    );
    final endController = TextEditingController(
      text: _formatInput(initialEnd ?? now),
    );
    Bottle selectedBottle = _bottles.first;
    final result = await showDialog<(Bottle, DateTime, DateTime)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(initialStart == null ? '补录时间' : '编辑时间记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (initialStart == null)
                  DropdownButtonFormField<Bottle>(
                    initialValue: selectedBottle,
                    decoration: const InputDecoration(labelText: '时间之瓶'),
                    items: [
                      for (final bottle in _bottles)
                        DropdownMenuItem(
                          value: bottle,
                          child: Text(bottle.name),
                        ),
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
    final date = _formatDate(start);
    final startTime = start.toString().substring(11, 16);
    if (entry.endedAt == null) {
      return '$date $startTime · 进行中';
    }
    final end = entry.endedAt!.toLocal();
    return '$date $startTime - ${end.toString().substring(11, 16)}';
  }

  String _formatDate(DateTime value) {
    return value.year.toString() +
        '-' +
        value.month.toString().padLeft(2, '0') +
        '-' +
        value.day.toString().padLeft(2, '0');
  }

  String _formatMonth(DateTime value) {
    return value.year.toString() +
        '-' +
        value.month.toString().padLeft(2, '0');
  }

  String _formatInput(DateTime value) {
    final local = value.toLocal();
    return _formatDate(local) +
        ' ' +
        local.hour.toString().padLeft(2, '0') +
        ':' +
        local.minute.toString().padLeft(2, '0');
  }

  void _showMessage(BuildContext context, String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
