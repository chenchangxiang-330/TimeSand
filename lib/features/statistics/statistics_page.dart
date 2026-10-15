import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/records/time_statistics.dart';
import '../../design/glass.dart';
import '../bottles/bottle_detail_page.dart';
import '../history/history_page.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({required this.repository, super.key});

  final TimeRecordsRepository repository;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with WidgetsBindingObserver {
  List<Bottle> _bottles = const [];
  List<TimeEntry> _entries = const [];
  DateTime _now = DateTime.now();
  DateTime? _selectedDate;
  Timer? _ticker;
  bool _loading = true;
  String? _error;

  DateTime get _date => _selectedDate ?? _now;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    _load();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
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
        widget.repository.fetchBottles(includeArchived: true),
        widget.repository.fetchEntries(),
      ]);
      if (!mounted) return;
      setState(() {
        _bottles = results[0] as List<Bottle>;
        _entries = results[1] as List<TimeEntry>;
        _now = DateTime.now();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '暂时无法读取统计：$error';
        });
      }
    }
  }

  Duration _lifetime({int? bottleId}) {
    return _entries
        .where((entry) => bottleId == null || entry.bottleId == bottleId)
        .fold<Duration>(Duration.zero, (sum, entry) {
          final rawEnd = entry.endedAt ?? _now;
          final end = rawEnd.isAfter(_now) ? _now : rawEnd;
          return end.isAfter(entry.startedAt)
              ? sum + end.difference(entry.startedAt)
              : sum;
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = TimeStatistics.forDate(date: _date, now: _now, entries: _entries);
    final selectedBottles = _bottles.toList()
      ..sort((a, b) => daily.forBottle(b.id!).compareTo(daily.forBottle(a.id!)));
    final ratio = daily.elapsed.inMicroseconds == 0 ? 0.0 :
        (daily.recorded.inMicroseconds / daily.elapsed.inMicroseconds)
            .clamp(0.0, 1.0).toDouble();
    return GlassScaffold(
      title: '时间统计',
      actions: [
        IconButton(
          key: const ValueKey('statistics-history-button'),
          tooltip: '查看这一天的记录',
          onPressed: _openHistory,
          icon: const Icon(Icons.history_rounded),
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
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('看见时间的去向', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text('每一次投入，都在塑造未来的自己。'),
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
                                      key: const ValueKey('statistics-date-filter'),
                                      onPressed: _chooseDate,
                                      icon: const Icon(Icons.calendar_month_outlined),
                                      label: Text(_dateLabel(_date)),
                                    ),
                                    if (_selectedDate != null)
                                      TextButton(
                                        onPressed: () => setState(() => _selectedDate = null),
                                        child: const Text('回到今天'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text('已投入', style: theme.textTheme.labelLarge),
                                const SizedBox(height: 6),
                                Text(
                                  formatRecordDuration(daily.recorded),
                                  key: const ValueKey('statistics-daily-recorded'),
                                  style: theme.textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 9,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text('占当天已流逝时间的 ${(ratio * 100).toStringAsFixed(1)}%'),
                                const SizedBox(height: 22),
                                Wrap(
                                  spacing: 36,
                                  runSpacing: 18,
                                  children: [
                                    _metric('时间海洋', daily.unallocated,
                                        const ValueKey('statistics-ocean')),
                                    _metric('当天已流逝', daily.elapsed,
                                        const ValueKey('statistics-elapsed')),
                                    _metric('永久总投入', _lifetime(),
                                        const ValueKey('statistics-lifetime')),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '时间海洋是当天已流逝但尚未分配的时间。',
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
                                  TextButton(onPressed: _load, child: const Text('重试')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          GlassPanel(child: _weekChart(context)),
                          const SizedBox(height: 24),
                          Text('时间之瓶', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text('每日水位会重新开始，永久积累不会消失。'),
                          const SizedBox(height: 16),
                          if (selectedBottles.isEmpty)
                            const GlassPanel(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Icon(Icons.water_drop_outlined, size: 36),
                                    SizedBox(height: 12),
                                    Text('还没有时间之瓶。'),
                                    SizedBox(height: 6),
                                    Text('创建一个瓶子，开始记录你的投入。'),
                                  ],
                                ),
                              ),
                            )
                          else
                            for (final bottle in selectedBottles) ...[
                              GlassPanel(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          margin: const EdgeInsets.only(top: 7),
                                          decoration: BoxDecoration(
                                            color: Color(bottle.color),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            bottle.name + (bottle.isArchived ? ' · 已归档' : ''),
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 24,
                                      runSpacing: 12,
                                      children: [
                                        _metric(
                                          '当天投入',
                                          daily.forBottle(bottle.id!),
                                          ValueKey('statistics-bottle-${bottle.id}'),
                                        ),
                                        _metric(
                                          '永久累计',
                                          _lifetime(bottleId: bottle.id),
                                          ValueKey('statistics-total-${bottle.id}'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => _openBottle(bottle),
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                      label: const Text('查看成长瓶'),
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

  Widget _metric(String label, Duration value, Key key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Text(
          formatRecordDuration(value),
          key: key,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _weekChart(BuildContext context) {
    final days = [
      for (var offset = 6; offset >= 0; offset--)
        DateTime(_date.year, _date.month, _date.day - offset),
    ];
    final totals = [
      for (final day in days)
        TimeStatistics.forDate(date: day, now: _now, entries: _entries).recorded,
    ];
    final peak = totals.fold<int>(0, (value, total) =>
        total.inMicroseconds > value ? total.inMicroseconds : value);
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('七日投入', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('截至 ${_dateLabel(_date)} · 点击日期查看记录'),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                SizedBox(
                  width: 84,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openHistory(date: days[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 104,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 28,
                                height: peak == 0 ? 1 :
                                    (totals[i].inMicroseconds / peak * 104).clamp(1.0, 104.0).toDouble(),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      color.withValues(alpha: 0.8),
                                      color.withValues(alpha: 0.25),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('${days[i].month}/${days[i].day}'),
                          const SizedBox(height: 4),
                          Text(
                            formatRecordDuration(totals[i]),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (peak == 0) ...[
          const SizedBox(height: 12),
          const Text('这七天还没有投入记录。'),
        ],
      ],
    );
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final initial = _date.isAfter(now) ? now : _date;
    final earliestYear = _entries.isEmpty
        ? 2000
        : _entries.first.startedAt.toLocal().year - 1;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(earliestYear < initial.year ? earliestYear : initial.year),
      lastDate: now,
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Future<void> _openHistory({DateTime? date}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPage(repository: widget.repository, initialDate: date ?? _date),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openBottle(Bottle bottle) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BottleDetailPage(repository: widget.repository, bottle: bottle),
      ),
    );
    if (mounted) await _load();
  }

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
