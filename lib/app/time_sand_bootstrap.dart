import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/database/app_database.dart';
import '../design/app_theme.dart';
import 'time_sand_app.dart';

typedef TimeSandDatabaseLoader = Future<TimeSandDatabase> Function();

/// Shows a first frame before opening local data, with a safe retry on failure.
class TimeSandBootstrap extends StatefulWidget {
  const TimeSandBootstrap({this.databaseLoader, super.key});

  final TimeSandDatabaseLoader? databaseLoader;

  @override
  State<TimeSandBootstrap> createState() => _TimeSandBootstrapState();
}

class _TimeSandBootstrapState extends State<TimeSandBootstrap> {
  TimeSandDatabase? _database;
  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_open());
      }
    });
  }

  static Future<TimeSandDatabase> _openLocalDatabase() async {
    sqfliteFfiInit();
    return TimeSandDatabase.open();
  }

  static void _logFailure(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('TimeSand local data initialization failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _open() async {
    if (!mounted || _opening || _database != null) {
      return;
    }
    _opening = true;
    setState(() => _loading = true);
    try {
      final database =
          await (widget.databaseLoader ?? _openLocalDatabase)();
      if (!mounted) {
        // Only a result that was never handed to the app is owned here.
        await database.close();
        return;
      }
      setState(() {
        _database = database;
        _loading = false;
      });
    } catch (error, stack) {
      _logFailure(error, stack);
      if (mounted) {
        setState(() => _loading = false);
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = _database;
    if (database != null) {
      return TimeSandApp(database: database);
    }
    return MaterialApp(
      title: 'TimeSand',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: const Color(0xFFF0F7FC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: AppTheme.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TimeSand',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_loading) ...[
                      const CircularProgressIndicator(
                        key: ValueKey('startup-progress'),
                        semanticsLabel: '正在打开本地数据',
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '正在打开你的时间之瓶…',
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const Text(
                        '暂时无法打开本地数据',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '请重试。现有数据不会被清除。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const ValueKey('retry-startup'),
                        onPressed: _open,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
