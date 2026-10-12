import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/records/time_statistics.dart';

class BottleDetailPage extends StatefulWidget {
  const BottleDetailPage({
    required this.repository,
    required this.bottle,
    super.key,
  });

  final TimeRecordsRepository repository;
  final Bottle bottle;

  @override
  State<BottleDetailPage> createState() => _BottleDetailPageState();
}

class _BottleDetailPageState extends State<BottleDetailPage> {
  late DateTime _now;
  Timer? _ticker;
  List<TimeEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      },
    );
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await widget.repository.fetchEntries(
      bottleId: widget.bottle.id,
    );
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = TimeStatistics.lifetime(
      bottleId: widget.bottle.id!,
      now: _now,
      entries: _entries,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.bottle.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(widget.bottle.color),
                    child: const Icon(Icons.water_drop_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    formatRecordDuration(stats.total),
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '永久成长累计 · ' +
                        stats.entryCount.toString() +
                        ' 条记录',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                Text('按月份', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (stats.byMonth.isEmpty)
                  const Card(child: ListTile(title: Text('还没有历史投入。')))
                else
                  ...stats.byMonth.entries
                      .toList()
                      .reversed
                      .map(
                        (entry) => Card(
                          child: ListTile(
                            title: Text(entry.key),
                            trailing: Text(formatRecordDuration(entry.value)),
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
                Text('投入记录', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_entries.isEmpty)
                  const Card(child: ListTile(title: Text('暂无记录。')))
                else
                  ..._entries.reversed.map(
                    (entry) => Card(
                      child: ListTile(
                        leading: Icon(
                          entry.source == TimeEntrySource.active
                              ? Icons.timer_outlined
                              : Icons.edit_calendar_outlined,
                        ),
                        title: Text(_formatDate(entry.startedAt)),
                        subtitle: Text(
                          entry.endedAt == null
                              ? '进行中'
                              : entry.startedAt
                                      .toLocal()
                                      .toString()
                                      .substring(11, 16) +
                                  ' - ' +
                                  entry.endedAt!
                                      .toLocal()
                                      .toString()
                                      .substring(11, 16),
                        ),
                        trailing: Text(
                          formatRecordDuration(entry.durationAt(_now)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return date.year.toString() +
        '-' +
        date.month.toString().padLeft(2, '0') +
        '-' +
        date.day.toString().padLeft(2, '0');
  }
}
