import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/time_records_repository.dart';
import '../../core/records/time_format.dart';
import '../../core/records/time_models.dart';
import '../../core/records/time_statistics.dart';
import '../../core/time/day_window.dart';
import '../../design/app_theme.dart';
import '../../design/glass.dart';
import '../../design/glass_bottle.dart';
import '../bottles/bottle_detail_page.dart';
import '../bottles/bottle_editor_dialog.dart';
import '../history/history_page.dart';
import '../hourglass/hourglass_placeholder.dart';
import '../statistics/statistics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.repository,
    this.enableTicker = true,
    this.clock,
    super.key,
  });
  final TimeRecordsRepository repository;
  final bool enableTicker;
  final DateTime Function()? clock;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _ticker;
  List<Bottle> _allBottles = [];
  List<TimeEntry> _entries = [];
  int? _selectedId;
  int _tab = 0;
  int _historyRevision = 0;
  int _dataRevision = 0;
  DateTime? _historyDate;
  bool _loading = true;
  bool _foreground = true;
  bool _routeOpen = false;
  bool _busy = false;
  String? _error;
  final _scroll = ScrollController();
  DateTime _readClock() => (widget.clock ?? DateTime.now)().toLocal();
  List<Bottle> get _bottles => _allBottles.where((b) => !b.isArchived).toList();
  TimeEntry? get _activeEntry {
    for (final entry in _entries) {
      if (entry.isActive) return entry;
    }
    return null;
  }

  DailyTimeStats get _today =>
      TimeStatistics.forDate(date: _now, now: _now, entries: _entries);
  TimeSnapshot get _snapshot => TimeSnapshot.at(_now);

  @override
  void initState() {
    super.initState();
    _now = _readClock();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
    _load();
  }

  void _startClock() {
    _ticker?.cancel();
    if (!widget.enableTicker ||
        !_foreground ||
        _routeOpen ||
        (_tab != 0 && _tab != 4 && _activeEntry == null))
      return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        setState(() => _now = _readClock());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _ticker?.cancel();
    if (_foreground) {
      _load();
      _startClock();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bottles = await widget.repository.fetchBottles(
        includeArchived: true,
      );
      final entries = await widget.repository.fetchEntries();
      if (!mounted) return;
      setState(() {
        _allBottles = bottles;
        _entries = entries;
        _dataRevision++;
        _now = _readClock();
        _loading = false;
        _error = null;
        if (_selectedId != null && !_bottles.any((b) => b.id == _selectedId))
          _selectedId = null;
      });
      _startClock();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = '暂时无法读取本地记录，请重试。';
        });
    }
  }

  void _navigate(int tab, {bool calendar = false}) {
    setState(() {
      _tab = tab;
      if (tab == 1) {
        _historyDate = calendar ? _now : null;
        _historyRevision++;
      }
    });
    _startClock();
    _load();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4;
      return ScenicBackground(
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) SizedBox(width: 224, child: _sidebar()),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _content(desktop)),
                      if (_activeEntry != null) _activeControl(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          desktop ? 32 : 12,
                          6,
                          desktop ? 32 : 12,
                          10,
                        ),
                        child: desktop ? _dock() : _mobileNavigation(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _content(bool desktop) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tab == 1)
      return HistoryPage(
        key: ValueKey('history-$_historyRevision'),
        repository: widget.repository,
        initialDate: _historyDate,
        revision: _dataRevision,
      );
    if (_tab == 2) return StatisticsPage(repository: widget.repository, revision: _dataRevision);
    if (_tab == 3) return _settings();
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          desktop ? 32 : 18,
          desktop ? 24 : 12,
          desktop ? 32 : 18,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              GlassPanel(
                child: Column(
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            if (_tab == 0) ...[
              if (!desktop) _mobileHeader(),
              _hero(desktop),
              const SizedBox(height: 16),
            ] else ...[
              Text('我的时间之瓶', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
            ],
            _bottleShelf(desktop),
            const SizedBox(height: 18),
            _ocean(desktop),
          ],
        ),
      ),
    );
  }

  Widget _mobileHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TimeSand',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w500,
                letterSpacing: -.7,
              ),
            ),
            Text('时间之沙', style: TextStyle(fontSize: 12, letterSpacing: 3)),
          ],
        ),
      ),
      Flexible(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            children: [
              const Text('今天', style: TextStyle(fontSize: 17)),
              Text(
                _now.month.toString() +
                    '月' +
                    _now.day.toString() +
                    '日 · ' +
                    _weekday(_now),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      IconButton(
        key: const ValueKey('history-button'),
        tooltip: '日历与历史记录',
        onPressed: () => _navigate(1, calendar: true),
        icon: const Icon(Icons.calendar_month_outlined),
      ),
    ],
  );

  Widget _hero(bool desktop) {
    final glass = RepaintBoundary(
      child: HourglassPlaceholder(
        progress: _snapshot.progress,
        height: desktop ? 330 : 252,
        animate: widget.enableTicker && _foreground && !_routeOpen,
      ),
    );
    if (desktop)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _now.month.toString() + '月' + _now.day.toString() + '日',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  _now.year.toString() + ' · ' + _weekday(_now),
                  style: const TextStyle(fontSize: 16, letterSpacing: 2),
                ),
                const SizedBox(height: 18),
                const Text('今天也在认真生活', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 36),
                const Text(
                  '让每一刻，\n流向喜欢的自己。',
                  style: TextStyle(fontSize: 20, height: 1.7),
                ),
                const SizedBox(height: 14),
                Text(
                  '今日已流逝 ' +
                      (_snapshot.progress * 100).toStringAsFixed(1) +
                      '%',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Expanded(flex: 4, child: Center(child: glass)),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: _summary()),
        ],
      );
    return Column(
      children: [
        const SizedBox(height: 8),
        glass,
        const Text(
          '时间终将流逝，但你可以决定它流向哪里。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 4,
          children: [
            Text(
              '已流逝 ' + formatClockDuration(_snapshot.elapsed),
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              '今日剩余 ' + formatClockDuration(_snapshot.remaining),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary() => GlassPanel(
    blur: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('今日已记录', style: TextStyle(fontSize: 15, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(
          formatRecordDuration(_today.recorded),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 18),
        LinearProgressIndicator(
          value: _snapshot.progress,
          minHeight: 5,
          borderRadius: BorderRadius.circular(6),
          backgroundColor: Colors.white.withValues(alpha: .6),
        ),
        const SizedBox(height: 8),
        Text(
          '自然日已流逝 ' + (_snapshot.progress * 100).toStringAsFixed(1) + '%',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 18),
        Text('未记录  ' + formatRecordDuration(_today.unallocated)),
        const SizedBox(height: 8),
        Text('今日剩余  ' + formatRecordDuration(_snapshot.remaining)),
        const SizedBox(height: 20),
        const Text('每一段专注的时光，\n都在靠近更好的自己。', style: TextStyle(height: 1.8)),
      ],
    ),
  );

  Widget _bottleShelf(bool desktop) => GlassPanel(
    padding: EdgeInsets.all(desktop ? 20 : 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text('今日 · 时间之瓶', style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              key: const ValueKey('create-bottle-button'),
              onPressed: () => _createBottle(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建'),
            ),
          ],
        ),
        const Text(
          '点击瓶子，查看累计时光',
          style: TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        if (_bottles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    size: 32,
                    color: AppTheme.blue,
                  ),
                  const SizedBox(height: 10),
                  const Text('还没有时间之瓶，先创建一个吧。', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => _createBottle(context),
                    child: const Text('创建第一个瓶子'),
                  ),
                ],
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bottle in _bottles) _bottleTile(bottle, desktop),
              ],
            ),
          ),
        if (_bottles.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '瓶内比例表示今日已记录时间的占比',
              style: TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          ),
      ],
    ),
  );

  Widget _bottleTile(Bottle bottle, bool desktop) {
    final selected =
        bottle.id == _selectedId || bottle.id == _activeEntry?.bottleId;
    final duration = _today.forBottle(bottle.id!);
    final fill = _today.recorded.inMicroseconds == 0
        ? 0.0
        : duration.inMicroseconds / _today.recorded.inMicroseconds;
    return Container(
      width: desktop ? 148 : 122,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0x55D6EDFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppTheme.blue.withValues(alpha: .6)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: bottle.name + '，永久成长瓶详情',
            child: InkWell(
              key: ValueKey('bottle-detail-' + bottle.id.toString()),
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openRoute(
                BottleDetailPage(repository: widget.repository, bottle: bottle),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Column(
                  children: [
                    GlassBottle(
                      color: Color(bottle.color),
                      fill: fill,
                      height: desktop ? 128 : 100,
                      icon: _bottleIcon(bottle.name),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bottle.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatRecordDuration(duration),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              IconButton(
                key: ValueKey('select-bottle-' + bottle.id.toString()),
                tooltip: (selected ? '已选择 ' : '选择 ') + bottle.name,
                isSelected: selected,
                onPressed: () => setState(() => _selectedId = bottle.id),
                icon: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppTheme.blue : AppTheme.muted,
                ),
              ),
              if (_activeEntry == null)
                IconButton(
                  key: ValueKey('start-' + bottle.id.toString()),
                  tooltip: '开始记录 ' + bottle.name,
                  onPressed: _busy ? null : () => _startTimer(bottle),
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppTheme.blue,
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: '管理 ' + bottle.name,
                icon: const Icon(Icons.more_horiz, size: 20),
                onSelected: (value) => value == 'edit'
                    ? _editBottle(context, bottle)
                    : _archiveBottle(bottle),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑名称与颜色')),
                  PopupMenuItem(value: 'archive', child: Text('归档瓶子')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ocean(bool desktop) => GlassPanel(
    tint: const Color(0xB7D7F0FC),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '时间海洋',
              style: TextStyle(fontSize: 12, letterSpacing: 3),
            ),
            const SizedBox(height: 5),
            const Text('已流逝但未记录', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              formatRecordDuration(_today.unallocated),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 4),
            const Text('让尚未归属的时光，也有迹可循。', style: TextStyle(fontSize: 12)),
          ],
        );
        final action = _activeEntry == null
            ? Column(
                children: [
                  SizedBox(
                    key: const ValueKey('primary-timer-button'),
                    width: 240,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _primaryAction,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('开始记录'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('没有正在进行的计时', style: TextStyle(fontSize: 10)),
                ],
              )
            : const Text('当前投入正在汇入时间之瓶。');
        if (desktop && constraints.maxWidth > 700)
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 20),
              action,
            ],
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            info,
            const SizedBox(height: 16),
            Center(child: action),
          ],
        );
      },
    ),
  );

  Widget _activeControl() {
    final active = _activeEntry!;
    var name = '已归档的时间之瓶';
    for (final bottle in _allBottles) {
      if (bottle.id == active.bottleId) name = bottle.name;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在投入：' + name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formatClockDuration(active.durationAt(_now)),
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              key: const ValueKey('primary-timer-button'),
              child: FilledButton(
                key: const ValueKey('stop-timer-button'),
                onPressed: _busy ? null : _stopTimer,
                child: const Text('停止记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileNavigation() => GlassPanel(
    blur: true,
    radius: 32,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        _navigationItem('首页', Icons.home_rounded, 0, 'nav-home'),
        _navigationItem('记录', Icons.history_rounded, 1, 'nav-history'),
        _navigationItem('统计', Icons.bar_chart_rounded, 2, 'nav-statistics'),
        _navigationItem('我的', Icons.person_outline_rounded, 3, 'nav-settings'),
      ],
    ),
  );
  Widget _navigationItem(String label, IconData icon, int tab, String key) =>
      Expanded(
        child: Semantics(
          selected: _tab == tab,
          button: true,
          label: label,
          child: TextButton(
            key: ValueKey(key),
            onPressed: () => _navigate(tab),
            style: TextButton.styleFrom(
              foregroundColor: _tab == tab ? AppTheme.blue : AppTheme.muted,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              backgroundColor: _tab == tab
                  ? const Color(0x55CBE5FC)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 25),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
  Widget _sidebar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
    child: GlassPanel(
      blur: true,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TimeSand',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                ),
                Text('时间之沙', style: TextStyle(fontSize: 12, letterSpacing: 4)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _sideLink('首页', Icons.home_rounded, 0, 'nav-home'),
                  _sideLink(
                    '时间瓶子',
                    Icons.water_drop_outlined,
                    4,
                    'nav-bottles',
                  ),
                  _sideLink(
                    '统计分析',
                    Icons.bar_chart_rounded,
                    2,
                    'nav-statistics',
                  ),
                  _sideLink(
                    '日历视图',
                    Icons.calendar_month_outlined,
                    1,
                    'history-button',
                    calendar: true,
                  ),
                  _sideLink('记录', Icons.history_rounded, 1, 'nav-history'),
                  _sideLink('设置', Icons.tune_rounded, 3, 'nav-settings'),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Text(
              '时间终将流逝，\n但你可以决定\n它流向哪里。',
              style: TextStyle(height: 1.9, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _sideLink(
    String label,
    IconData icon,
    int tab,
    String key, {
    bool calendar = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      key: ValueKey(key),
      selected: _tab == tab && (tab != 1 || calendar == (_historyDate != null)),
      selectedTileColor: const Color(0x55B6D9FF),
      selectedColor: AppTheme.blue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: () => _navigate(tab, calendar: calendar),
    ),
  );
  Widget _dock() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: GlassPanel(
        blur: true,
        radius: 36,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  _navigate(0);
                  if (_activeEntry == null) _primaryAction();
                },
                icon: const Icon(Icons.add_circle, size: 32),
                label: Text(_activeEntry == null ? '记录时间' : '当前计时'),
              ),
            ),
            _navigationItem(
              '统计',
              Icons.bar_chart_rounded,
              2,
              'dock-statistics',
            ),
            _navigationItem(
              '日历',
              Icons.calendar_month_outlined,
              1,
              'dock-history',
            ),
            _navigationItem('更多', Icons.more_horiz, 3, 'dock-settings'),
          ],
        ),
      ),
    ),
  );

  Widget _settings() => GlassScaffold(
    title: '我的 · 本地时光',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TimeSand', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 8),
              const Text('时间终将流逝，但你可以决定它流向哪里。'),
              const SizedBox(height: 20),
              const Text('数据只存放在此设备。没有账户和云端同步。'),
              const SizedBox(height: 10),
              Text(
                _allBottles.length.toString() +
                    ' 个瓶子 · ' +
                    _entries.length.toString() +
                    ' 条时间记录',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.water_drop_outlined),
                title: const Text('管理时间之瓶'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigate(4),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('查看已归档瓶子'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showArchived,
              ),
              ListTile(
                leading: const Icon(Icons.accessibility_new),
                title: const Text('动画跟随系统偏好'),
                subtitle: Text(
                  MediaQuery.disableAnimationsOf(context)
                      ? '系统已要求减少动画'
                      : '后台停止动画；可在系统中开启减少动画',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('开源组件许可'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openRoute(const ScenicBackground(
                  child: LicensePage(applicationName: 'TimeSand'),
                )),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Future<void> _showArchived() async {
    final archived = _allBottles.where((b) => b.isArchived).toList();
    await _openRoute(
      GlassScaffold(
        title: '已归档的时间之瓶',
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: archived.isEmpty
              ? [const GlassPanel(child: Text('暂无已归档瓶子。'))]
              : [
                  for (final bottle in archived)
                    Card(
                      child: ListTile(
                        title: Text(bottle.name),
                        subtitle: const Text('历史投入仍然保留'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => BottleDetailPage(
                              repository: widget.repository,
                              bottle: bottle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
        ),
      ),
    );
  }

  Future<void> _primaryAction() async {
    if (_activeEntry != null) return;
    Bottle? selected;
    for (final b in _bottles) {
      if (b.id == _selectedId) selected = b;
    }
    if (selected != null) {
      await _startTimer(selected);
      return;
    }
    if (_bottles.isEmpty) {
      await _createBottle(context);
      return;
    }
    final choice = await showModalBottomSheet<Bottle>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .65,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              const Text('选择这段时光的去处', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              for (final bottle in _bottles)
                ListTile(
                  leading: Icon(
                    _bottleIcon(bottle.name),
                    color: Color(bottle.color).withAlpha(255),
                  ),
                  title: Text(bottle.name),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => Navigator.pop(context, bottle),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted) await _startTimer(choice);
  }

  Future<void> _openRoute(Widget page) async {
    _routeOpen = true;
    _ticker?.cancel();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (!mounted) return;
    _routeOpen = false;
    await _load();
    _startClock();
  }

  Future<void> _startTimer(Bottle bottle) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.startTimer(bottleId: bottle.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopTimer() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.stopTimer();
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
    } finally {
      if (mounted) setState(() => _busy = false);
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveBottle(Bottle bottle) async {
    if (_activeEntry?.bottleId == bottle.id) {
      _showMessage('请先停止此瓶子的计时，再归档。');
      return;
    }
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
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
  }) => showDialog<(String, int)>(
    context: context,
    builder: (_) => BottleEditorDialog(
      title: title,
      initialName: initialName,
      initialColor: initialColor,
    ),
  );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _weekday(DateTime date) =>
      const ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][date.weekday - 1];
  static IconData _bottleIcon(String name) {
    if (RegExp('运动|跑|健身').hasMatch(name)) return Icons.directions_run;
    if (RegExp('工作|编程').hasMatch(name)) return Icons.laptop_mac_outlined;
    if (RegExp('创|画|音乐').hasMatch(name)) return Icons.palette_outlined;
    if (RegExp('生活|休息').hasMatch(name)) return Icons.home_outlined;
    return Icons.auto_stories_outlined;
  }
}
