import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/records/time_statistics.dart';
import '../../core/time/day_window.dart';
import '../bottles/bottle_detail_page.dart';
import '../data_management/data_management_page.dart';
import '../history/history_page.dart';
import '../hourglass/hourglass_placeholder.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.repository,
    this.enableTicker = true,
    super.key,
  });

  final TimeRecordsRepository repository;
  final bool enableTicker;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _ticker;
  List<Bottle> _bottles = const [];
  List<TimeEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  TimeEntry? get _activeEntry {
    for (final entry in _entries) {
      if (entry.isActive) {
        return entry;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = DateTime.now();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshClock(),
    );
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _now = DateTime.now();
      _load();
    }
  }

  void _refreshClock() {
    if (mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchBottles(),
        widget.repository.fetchEntries(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _bottles = results[0] as List<Bottle>;
        _entries = results[1] as List<TimeEntry>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  DailyTimeStats get _todayStats {
    return TimeStatistics.forDate(date: _now, now: _now, entries: _entries);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = TimeSnapshot.at(_now);
    final theme = Theme.of(context);
    final today = _todayStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TimeSand'),
        actions: [
          IconButton(
            key: const ValueKey('data-management-button'),
            tooltip: '本地数据',
            icon: const Icon(Icons.import_export_rounded),
            onPressed: () => _openDataManagement(context),
          ),
          IconButton(
            key: const ValueKey('history-button'),
            tooltip: '历史记录',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _openHistory(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '时间终将流逝，但你可以决定它流向哪里。',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time will pass, but you decide where it flows.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: HourglassPlaceholder(
                                progress: snapshot.progress,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatDate(_now),
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: snapshot.progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _MetricCard(
                                  label: '已经流逝',
                                  value: formatClockDuration(snapshot.elapsed),
                                ),
                                _MetricCard(
                                  label: '还剩下',
                                  value: formatClockDuration(
                                    snapshot.remaining,
                                  ),
                                ),
                                _MetricCard(
                                  label: '今日进度',
                                  value:
                                      '${(snapshot.progress * 100).toStringAsFixed(1)}%',
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _ErrorCard(message: _error!),
                            ],
                            const SizedBox(height: 24),
                            _buildActiveCard(context),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '时间之瓶',
                                  style: theme.textTheme.headlineSmall,
                                ),
                                FilledButton.icon(
                                  key: const ValueKey('create-bottle-button'),
                                  onPressed: () => _createBottle(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('新建'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_bottles.isEmpty)
                              const _EmptyCard(message: '还没有时间之瓶，先创建一个吧。')
                            else
                              ..._bottles.map(
                                (bottle) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _BottleCard(
                                    bottle: bottle,
                                    todayDuration: today.forBottle(bottle.id!),
                                    isActive:
                                        _activeEntry?.bottleId == bottle.id,
                                    onTap: () => _openBottle(context, bottle),
                                    onStart: () => _startTimer(bottle),
                                    onStop: _stopTimer,
                                    onEdit: () => _editBottle(context, bottle),
                                    onArchive: () => _archiveBottle(bottle),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    const Icon(Icons.water_drop_outlined),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '时间海洋',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '今天尚未分配：' +
                                                formatRecordDuration(
                                                  today.unallocated,
                                                ),
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveCard(BuildContext context) {
    final active = _activeEntry;
    if (active == null) {
      return const Card(
        child: ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: const Text('没有正在进行的计时'),
          subtitle: const Text('选择一个时间之瓶开始投入。'),
        ),
      );
    }

    String bottleName = '时间之瓶';
    for (final bottle in _bottles) {
      if (bottle.id == active.bottleId) {
        bottleName = bottle.name;
        break;
      }
    }

    return Card(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timelapse_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('正在投入：' + bottleName),
                  const SizedBox(height: 4),
                  Text(
                    formatClockDuration(active.durationAt(_now)),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            FilledButton(
              key: const ValueKey('stop-timer-button'),
              onPressed: _stopTimer,
              child: const Text('停止'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTimer(Bottle bottle) async {
    try {
      await widget.repository.startTimer(bottleId: bottle.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    }
  }

  Future<void> _stopTimer() async {
    try {
      await widget.repository.stopTimer();
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    }
  }

  Future<void> _createBottle(BuildContext context) async {
    final result = await _showBottleDialog(context, title: '新建时间之瓶');
    if (result == null) {
      return;
    }
    try {
      await widget.repository.createBottle(name: result.$1, color: result.$2);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    }
  }

  Future<void> _editBottle(BuildContext context, Bottle bottle) async {
    final result = await _showBottleDialog(
      context,
      title: '编辑时间之瓶',
      initialName: bottle.name,
      initialColor: Color(bottle.color),
    );
    if (result == null) {
      return;
    }
    try {
      await widget.repository.updateBottle(
        id: bottle.id!,
        name: result.$1,
        color: result.$2,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    }
  }

  Future<void> _archiveBottle(Bottle bottle) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('归档时间之瓶？'),
        content: const Text('归档后不会出现在首页，但历史投入仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (shouldArchive == true) {
      await widget.repository.archiveBottle(bottle.id!);
      await _load();
    }
  }

  Future<(String, int)?> _showBottleDialog(
    BuildContext context, {
    required String title,
    String initialName = '',
    Color? initialColor,
  }) async {
    final controller = TextEditingController(text: initialName);
    var selectedColor = initialColor ?? const Color(0xFFE8C98D);
    final colors = <Color>[
      const Color(0xFFE8C98D),
      const Color(0xFF9AC7C5),
      const Color(0xFFD8A7B1),
      const Color(0xFFA8B5D1),
      const Color(0xFFC5B8A5),
    ];
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                controller: controller,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  for (final color in colors)
                    InkWell(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: CircleAvatar(
                        backgroundColor: color,
                        child: selectedColor.toARGB32() == color.toARGB32()
                            ? const Icon(Icons.check)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, (
                    name,
                    selectedColor.toARGB32(),
                  ));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openHistory(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HistoryPage(repository: widget.repository),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openDataManagement(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DataManagementPage(repository: widget.repository),
      ),
    );
    if (mounted) await _load();
  }

  void _openBottle(BuildContext context, Bottle bottle) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            BottleDetailPage(repository: widget.repository, bottle: bottle),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    const weekdays = <String>['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return date.year.toString() +
        '年' +
        date.month.toString() +
        '月' +
        date.day.toString() +
        '日 · ' +
        weekdays[date.weekday - 1];
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _BottleCard extends StatelessWidget {
  const _BottleCard({
    required this.bottle,
    required this.todayDuration,
    required this.isActive,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onEdit,
    required this.onArchive,
  });

  final Bottle bottle;
  final Duration todayDuration;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(bottle.color),
                child: const Icon(Icons.water_drop_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bottle.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '今天 ' + formatRecordDuration(todayDuration),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isActive)
                IconButton(
                  key: const ValueKey('bottle-stop-button'),
                  tooltip: '停止计时',
                  onPressed: () => onStop(),
                  icon: const Icon(Icons.stop_circle_outlined),
                )
              else
                IconButton(
                  key: ValueKey('start-' + bottle.id.toString()),
                  tooltip: '开始计时',
                  onPressed: () => onStart(),
                  icon: const Icon(Icons.play_circle_outline),
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else {
                    onArchive();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'archive', child: Text('归档')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
    );
  }
}
