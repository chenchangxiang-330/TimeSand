import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:timesand/app/time_sand_app.dart';
import 'package:timesand/app/time_sand_bootstrap.dart';
import 'package:timesand/core/database/app_database.dart';

void main() {
  late TimeSandDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await TimeSandDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    if (database.database.isOpen) {
      await database.close();
    }
  });

  testWidgets('shows loading until the database is ready', (tester) async {
    final pending = Completer<TimeSandDatabase>();
    var attempts = 0;
    await tester.pumpWidget(
      TimeSandBootstrap(
        databaseLoader: () {
          attempts++;
          return pending.future;
        },
      ),
    );

    expect(find.byKey(const ValueKey('startup-progress')), findsOneWidget);
    expect(find.byType(TimeSandApp), findsNothing);
    expect(find.byKey(const ValueKey('retry-startup')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 1);

    pending.complete(database);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TimeSandApp), findsOneWidget);
    expect(
      tester.widget<TimeSandApp>(find.byType(TimeSandApp)).database,
      same(database),
    );
    expect(find.byKey(const ValueKey('startup-progress')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failure is private and retry cannot open twice', (tester) async {
    final retry = Completer<TimeSandDatabase>();
    var attempts = 0;
    await tester.pumpWidget(
      TimeSandBootstrap(
        databaseLoader: () {
          attempts++;
          if (attempts == 1) {
            return Future<TimeSandDatabase>.error(
              StateError('private-path/timesand.db could not open'),
            );
          }
          return retry.future;
        },
      ),
    );
    await tester.pump();

    expect(find.text('暂时无法打开本地数据'), findsOneWidget);
    expect(find.text('请重试。现有数据不会被清除。'), findsOneWidget);
    expect(find.textContaining('private-path'), findsNothing);
    final retryButton = find.byKey(const ValueKey('retry-startup'));
    await tester.tap(retryButton);
    await tester.tap(retryButton);
    expect(attempts, 2);
    await tester.pump();
    expect(find.byKey(const ValueKey('startup-progress')), findsOneWidget);
    expect(retryButton, findsNothing);

    retry.complete(database);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TimeSandApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late failure after disposal never updates the UI', (
    tester,
  ) async {
    final pending = Completer<TimeSandDatabase>();
    await tester.pumpWidget(
      TimeSandBootstrap(databaseLoader: () => pending.future),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    pending.completeError(StateError('database unavailable'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TimeSandApp), findsNothing);
  });

  testWidgets('closes an undelivered database after disposal', (tester) async {
    final pending = Completer<TimeSandDatabase>();
    await tester.pumpWidget(
      TimeSandBootstrap(databaseLoader: () => pending.future),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    pending.complete(database);
    await tester.pump();
    await tester.pump();
    expect(database.database.isOpen, isFalse);
    expect(tester.takeException(), isNull);
    expect(find.byType(TimeSandApp), findsNothing);
  });
}
