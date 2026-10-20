import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/records/time_statistics.dart';
import '../../design/glass.dart';
import '../../design/glass_bottle.dart';
import '../history/history_page.dart';

class BottleDetailPage extends StatefulWidget {
  const BottleDetailPage({
    required this.repository,
    required this.bottle,
    this.clock,
    super.key,
  });

  final TimeRecordsRepository repository;
  final Bottle bottle;
  final DateTime Function()? clock;

  @override
  State<BottleDetailPage> createState() => _BottleDetailPageState();
}

class _BottleDetailPageState extends State<BottleDetailPage>
    with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _ticker;
  List<TimeEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  DateTime _readClock() => (widget.clock ?? DateTime.now)().toLocal();

  @override
  void initState() {
    super.initState();
    _now = _readClock();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    _load();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final now = _readClock();
      final dateChanged = now.year != _now.year ||
          now.month != _now.month ||
          now.day != _now.day;
      if (dateChanged || _entries.any((entry) => entry.isActive)) {
        setState(() => _now = now);
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
      final entries = await widget.repository.fetchEntries(
        bottleId: widget.bottle.id,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _now = _readClock();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '暂时无法读取投入记录：$error';
        });
      }
    }
  }

  Map<String, Duration> _monthlyTotals() {
    final totals = <String, Duration>{};
    for (final entry in _entries) {
      final rawEnd = entry.endedAt ?? _now;
      final end = rawEnd.isAfter(_now) ? _now : rawEnd;
      var cursor = entry.startedAt.toLocal();
      while (cursor.isBefore(end)) {
        final monthEnd = DateTime(cursor.year, cursor.month + 1);
        final stop = monthEnd.isBefore(end) ? monthEnd : end;
        final key = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
        totals.update(
          key,
          (value) => value + stop.difference(cursor),
          ifAbsent: () => stop.difference(cursor),
        );
        cursor = stop.toLocal();
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(widget.bottle.color);
    final today = TimeStatistics.forDate(
      date: _now,
      now: _now,
      entries: _entries,
    );
    final months = _monthlyTotals();
    final lifetime = months.values.fold<Duration>(
      Duration.zero,
      (sum, value) => sum + value,
    );
    final monthKeys = months.keys.toList()..sort((a, b) => b.compareTo(a));
    final peak = months.values.fold<int>(
      0,
      (max, duration) =>
          duration.inMicroseconds > max ? duration.inMicroseconds : max,
    );
    final todayShare = today.window.total.inMicroseconds == 0
        ? 0.0
        : (today.recorded.inMicroseconds / today.window.total.inMicroseconds)
              .clamp(0.0, 1.0)
              .toDouble();

    return GlassScaffold(
      title: '永久成长瓶',
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
                          GlassPanel(
                            child: Column(
                              children: [
                                GlassBottle(
                                  color: color,
                                  fill: todayShare,
                                  height: 160,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.bottle.name,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '水每天重新开始，投入的时间始终留下。',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  formatRecordDuration(lifetime),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 6),
                                Text('永久累计 · ${_entries.length} 条记录'),
                                const SizedBox(height: 18),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      '今天 ${formatRecordDuration(today.recorded)}',
                                    ),
                                    Text(
                                      '创建于 ${_dateLabel(widget.bottle.createdAt)}',
                                    ),
                                    if (widget.bottle.isArchived)
                                      const Text('已归档'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '瓶内水位显示今天投入占本地自然日的比例',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
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
                            const SizedBox(height: 20),
                          ],
                          Text('成长轨迹', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          GlassPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('每个月，积累都看得见'),
                                const SizedBox(height: 16),
                                if (monthKeys.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Text('还没有历史投入。'),
                                  )
                                else
                                  for (final key in monthKeys) ...[
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          key,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        Text(
                                          formatRecordDuration(months[key]!),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: peak == 0
                                            ? 0
                                            : months[key]!.inMicroseconds /
                                                  peak,
                                        minHeight: 7,
                                        color: color,
                                        backgroundColor: color.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text('投入记录', style: theme.textTheme.titleLarge),
                              TextButton.icon(
                                onPressed: _openHistory,
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                ),
                                label: const Text('管理历史'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_entries.isEmpty)
                            const GlassPanel(child: Text('暂无记录。'))
                          else
                            for (final entry in _entries.reversed) ...[
                              GlassPanel(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _dateLabel(entry.startedAt),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(_intervalLabel(entry)),
                                    const SizedBox(height: 10),
                                    Text(
                                      formatRecordDuration(
                                        entry.durationAt(_now),
                                      ),
                                      style: theme.textTheme.titleLarge,
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

  Future<void> _openHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPage(repository: widget.repository),
      ),
    );
    if (mounted) await _load();
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _intervalLabel(TimeEntry entry) {
    final start = entry.startedAt.toLocal().toString().substring(11, 16);
    if (entry.isActive) return '$start · 正在投入';
    final end = entry.endedAt!.toLocal();
    return '$start — ${_dateLabel(end)} ${end.toString().substring(11, 16)}';
  }
}
