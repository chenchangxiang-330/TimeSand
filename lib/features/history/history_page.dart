import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/time/day_window.dart';
import '../../design/glass.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.repository,
    this.initialDate,
    this.revision = 0,
    this.onChanged,
    super.key,
  });

  final TimeRecordsRepository repository;
  final DateTime? initialDate;
  final int revision;
  final VoidCallback? onChanged;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with WidgetsBindingObserver {
  List<TimeEntry> _entries = const [];
  List<Bottle> _bottles = const [];
  DateTime? _date;
  DateTime _now = DateTime.now();
  Timer? _ticker;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate?.toLocal();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    _load();
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          _entries.any((entry) => entry.isActive)) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ticker?.cancel();
    if (state == AppLifecycleState.resumed) {
      _startTicker();
      _load();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchEntries(),
        widget.repository.fetchBottles(includeArchived: true),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<TimeEntry>;
        _bottles = results[1] as List<Bottle>;
        _now = DateTime.now();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '暂时无法读取记录：$error';
        });
      }
    }
  }

  Duration _duration(TimeEntry entry) {
    final rawEnd = entry.endedAt ?? _now;
    final end = rawEnd.isAfter(_now) ? _now : rawEnd;
    var start = entry.startedAt;
    var stop = end;
    if (_date != null) {
      final window = DayWindow.forDate(_date!);
      if (start.isBefore(window.start)) start = window.start;
      if (stop.isAfter(window.end)) stop = window.end;
    }
    return stop.isAfter(start) ? stop.difference(start) : Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _entries
        .where((entry) => _date == null || _duration(entry) > Duration.zero)
        .toList();
    final total = filtered.fold<Duration>(
      Duration.zero,
      (sum, entry) => sum + _duration(entry),
    );
    final names = {for (final bottle in _bottles) bottle.id!: bottle.name};
    final colors = {for (final bottle in _bottles) bottle.id!: bottle.color};
    return GlassScaffold(
      title: '历史记录',
      actions: [
        IconButton(
          key: const ValueKey('manual-entry-button'),
          tooltip: '补录时间',
          onPressed: _bottles.any((bottle) => !bottle.isArchived)
              ? () => _editRecord()
              : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '每一刻，都有迹可循',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text('时间流过，投入留下。', style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 24),
                          GlassPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      key: const ValueKey(
                                        'history-date-filter',
                                      ),
                                      onPressed: _chooseDate,
                                      icon: const Icon(
                                        Icons.calendar_month_outlined,
                                      ),
                                      label: Text(
                                        _date == null
                                            ? '选择日期'
                                            : _dateLabel(_date!),
                                      ),
                                    ),
                                    if (_date != null)
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _date = null),
                                        child: const Text('查看全部'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _date == null ? '历史总投入' : '当天总投入',
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatRecordDuration(total),
                                  style: theme.textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${filtered.length} 条记录'
                                  '${_date == null ? '' : ' · 跨日记录仅计算当天部分'}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null) ...[
                            GlassPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_error!),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('重试'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (filtered.isEmpty)
                            GlassPanel(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.history_rounded, size: 36),
                                    const SizedBox(height: 14),
                                    Text(
                                      _date == null
                                          ? '还没有历史投入记录。'
                                          : '这一天还没有投入记录。',
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('从一个小小的开始，积累自己的时间。'),
                                  ],
                                ),
                              ),
                            )
                          else
                            for (final entry in filtered.reversed) ...[
                              GlassPanel(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              colors[entry.bottleId] ??
                                                  0xFFBCA9E8,
                                            ).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Icon(
                                            entry.source ==
                                                    TimeEntrySource.active
                                                ? Icons.timelapse_rounded
                                                : Icons.edit_calendar_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                names[entry.bottleId] ?? '时间之瓶',
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                entry.isActive
                                                    ? '正在投入'
                                                    : '已留下的时间',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(_intervalLabel(entry)),
                                    const SizedBox(height: 8),
                                    Text(
                                      formatRecordDuration(_duration(entry)),
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        TextButton.icon(
                                          key: ValueKey(
                                            'edit-entry-${entry.id}',
                                          ),
                                          onPressed: entry.isActive
                                              ? null
                                              : () => _editRecord(entry: entry),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            entry.isActive ? '停止计时后可编辑' : '编辑',
                                          ),
                                        ),
                                        TextButton.icon(
                                          key: ValueKey(
                                            'delete-entry-${entry.id}',
                                          ),
                                          onPressed: () => _deleteEntry(entry),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          label: const Text('删除'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _chooseDate() async {
    final today = DateTime.now();
    final firstDate = _entries.isEmpty
        ? DateTime(2000)
        : DateTime(_entries.first.startedAt.toLocal().year - 1);
    final initial = _date != null && _date!.isBefore(today) ? _date! : today;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: firstDate.isBefore(initial)
          ? firstDate
          : DateTime(initial.year),
      lastDate: today,
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _deleteEntry(TimeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除时间记录？'),
        content: Text(
          entry.isActive
              ? '这会删除正在进行的计时。每日瓶、永久成长瓶和时间海洋会重新计算。'
              : '删除后每日瓶、永久成长瓶和时间海洋会重新计算。',
        ),
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
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteEntry(entry.id!);
      await _load();
      if (mounted) {
        widget.onChanged?.call();
        _message('记录已删除，统计已更新。');
      }
    } catch (error) {
      if (mounted) _message('删除失败：$error');
    }
  }

  Future<void> _editRecord({TimeEntry? entry}) async {
    if (entry?.isActive == true) return;
    final available = _bottles.where((bottle) => !bottle.isArchived).toList();
    if (entry == null && available.isEmpty) return;
    final now = DateTime.now();
    var startText = _input(
      entry?.startedAt ?? now.subtract(const Duration(hours: 1)),
    );
    var endText = _input(entry?.endedAt ?? now);
    var bottleId = entry?.bottleId ?? available.first.id!;
    String? error;
    var saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? '补录时间' : '编辑时间记录'),
          scrollable: true,
          content: SizedBox(
            width: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry == null) ...[
                  DropdownButtonFormField<int>(
                    initialValue: bottleId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '时间之瓶'),
                    items: [
                      for (final bottle in available)
                        DropdownMenuItem(
                          value: bottle.id!,
                          child: Text(
                            bottle.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null)
                              setDialogState(() => bottleId = value);
                          },
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('填写本地日期与时间。末尾为时区偏移，保留它可避免夏令时歧义。'),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('entry-start-input'),
                  initialValue: startText,
                  onChanged: (value) => startText = value,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: '开始时间'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('entry-end-input'),
                  initialValue: endText,
                  onChanged: (value) => endText = value,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: '结束时间'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('save-entry-button'),
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final startedAt = _parseInput(startText);
                        final endedAt = _parseInput(endText);
                        if (!endedAt.isAfter(startedAt)) {
                          throw const FormatException('结束时间必须晚于开始时间。');
                        }
                        if (endedAt.isAfter(DateTime.now())) {
                          throw const FormatException('结束时间不能在未来。');
                        }
                        if (entry == null) {
                          await widget.repository.createManualEntry(
                            bottleId: bottleId,
                            startedAt: startedAt,
                            endedAt: endedAt,
                          );
                        } else {
                          await widget.repository.updateEntry(
                            id: entry.id!,
                            startedAt: startedAt,
                            endedAt: endedAt,
                          );
                        }
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, true);
                      } catch (failure) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            error = failure.toString();
                          });
                        }
                      }
                    },
              child: Text(saving ? '正在保存…' : '保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _load();
      if (mounted) {
        widget.onChanged?.call();
        _message('时间已保存，统计已更新。');
      }
    }
  }

  DateTime _parseInput(String value) {
    final input = value.trim();
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?(Z|[+-]\d{2}:\d{2})?$',
    ).firstMatch(input);
    if (match == null) throw const FormatException('请输入有效日期、时间和可选时区偏移。');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6] ?? '0');
    final check = DateTime.utc(year, month, day, hour, minute, second);
    if (check.year != year ||
        check.month != month ||
        check.day != day ||
        check.hour != hour ||
        check.minute != minute ||
        check.second != second) {
      throw const FormatException('日期或时间不存在。');
    }
    final zone = match[8];
    if (zone != null &&
        zone != 'Z' &&
        (int.parse(zone.substring(1, 3)) > 23 ||
            int.parse(zone.substring(4, 6)) > 59)) {
      throw const FormatException('时区偏移无效。');
    }
    final parsed = DateTime.parse(input);
    if (zone == null &&
        (parsed.year != year ||
            parsed.month != month ||
            parsed.day != day ||
            parsed.hour != hour ||
            parsed.minute != minute)) {
      throw const FormatException('本地时间不存在，请检查夏令时变化。');
    }
    return parsed;
  }

  String _input(DateTime date) {
    final local = date.toLocal();
    final offset = local.timeZoneOffset;
    return '${local.toIso8601String()}${offset.isNegative ? '-' : '+'}'
        '${(offset.inMinutes.abs() ~/ 60).toString().padLeft(2, '0')}:'
        '${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}';
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _intervalLabel(TimeEntry entry) {
    final start = entry.startedAt.toLocal();
    final startLabel =
        '${_dateLabel(start)} ${start.toString().substring(11, 16)}';
    if (entry.endedAt == null) return '$startLabel · 进行中';
    final end = entry.endedAt!.toLocal();
    return '$startLabel — ${_dateLabel(end)} ${end.toString().substring(11, 16)}';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
