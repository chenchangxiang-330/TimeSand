import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timesand/app/time_sand_app.dart';
import 'package:timesand/core/database/app_database.dart';
import 'package:timesand/core/database/time_records_repository.dart';
import 'package:timesand/core/records/time_models.dart';
import 'package:timesand/features/home/home_page.dart';
import 'package:timesand/main.dart' as app;

const _bottleName = '__timesand_android_startup_smoke__';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'production startup writes a timer to disk and restores it after reopening',
    (tester) async {
      expect(Platform.isAndroid, isTrue, reason: 'Run this test on Android.');
      TimeSandDatabase? database;

      try {
        await _launchProductionApp(tester);
        database = tester
            .widget<TimeSandApp>(find.byType(TimeSandApp))
            .database;
        final databasePath = database.database.path;
        expect(databasePath, isNot(':memory:'));
        expect(databasePath.startsWith('/'), isTrue);
        expect(databasePath, isNot(contains('.dart_tool')));
        expect(await File(databasePath).exists(), isTrue);

        // Use the real app-private directory, never an injected test database.
        final probeDirectory = await File(
          databasePath,
        ).parent.createTemp('timesand-startup-smoke-');
        try {
          final probe = File('${probeDirectory.path}/write-check');
          await probe.writeAsString('writable', flush: true);
          expect(await probe.readAsString(), 'writable');
        } finally {
          await probeDirectory.delete(recursive: true);
        }

        final repository = TimeRecordsRepository(database);
        final existingIds = (await repository.fetchBottles(
          includeArchived: true,
        )).map((bottle) => bottle.id).toSet();
        expect(
          await repository.fetchActiveEntry(),
          isNull,
          reason: 'Use a fresh emulator; do not stop an unrelated timer.',
        );

        await _tap(tester, find.byKey(const ValueKey('create-bottle-button')));
        await _pumpUntil(
          tester,
          find.byKey(const ValueKey('bottle-name-input')),
          reason: 'The bottle creation dialog did not open.',
        );
        await tester.enterText(
          find.byKey(const ValueKey('bottle-name-input')),
          _bottleName,
        );
        await _tap(tester, find.byKey(const ValueKey('save-bottle-button')));
        await _pumpUntil(
          tester,
          find.byType(AlertDialog),
          absent: true,
          reason: 'The bottle dialog did not close.',
        );

        Bottle? createdBottle;
        final saveDeadline = Stopwatch()..start();
        while (saveDeadline.elapsed < const Duration(seconds: 30)) {
          final matches = (await repository.fetchBottles()).where(
            (bottle) =>
                bottle.name == _bottleName && !existingIds.contains(bottle.id),
          );
          if (matches.isNotEmpty) {
            expect(matches.length, 1);
            createdBottle = matches.single;
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          createdBottle,
          isNotNull,
          reason: 'The bottle was not persisted.',
        );
        final bottle = createdBottle!;
        final bottleId = bottle.id!;
        final startButton = find.byKey(ValueKey('start-$bottleId'));
        final stopButton = find.byKey(const ValueKey('stop-timer-button'));
        await _pumpUntil(
          tester,
          startButton,
          reason: 'The persisted bottle did not appear on the home page.',
        );
        await _tap(tester, startButton);
        await _pumpUntil(
          tester,
          stopButton,
          reason: 'Starting the timer did not update the active controls.',
        );
        final active = await repository.fetchActiveEntry();
        expect(active, isNotNull);
        expect(active!.bottleId, bottleId);
        expect(active.source, TimeEntrySource.active);

        // Integration-test pumps advance actual device time.
        await tester.pump(const Duration(seconds: 2));
        await _tap(tester, stopButton);
        await _pumpUntil(
          tester,
          stopButton,
          absent: true,
          reason: 'Stopping the timer did not clear the active controls.',
        );
        expect(await repository.fetchActiveEntry(), isNull);
        final savedEntries = await repository.fetchEntries(bottleId: bottleId);
        expect(savedEntries, hasLength(1));
        final savedEntry = savedEntries.single;
        expect(savedEntry.id, active.id);
        expect(savedEntry.endedAt, isNotNull);
        expect(savedEntry.endedAt!.isAfter(savedEntry.startedAt), isTrue);
        expect(savedEntry.durationSeconds, greaterThanOrEqualTo(1));
        final persistedEntry = savedEntry.toMap();
        final persistedBottle = bottle.toMap();

        // Dispose timers and widgets before closing their shared connection.
        // This is a real close/reopen, not a hot-reload or an in-memory reload.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await database.close();
        database = null;

        await _launchProductionApp(tester);
        database = tester
            .widget<TimeSandApp>(find.byType(TimeSandApp))
            .database;
        expect(database.database.path, databasePath);
        final reopenedRepository = TimeRecordsRepository(database);
        expect(
          (await reopenedRepository.fetchBottle(bottleId))?.toMap(),
          persistedBottle,
        );
        final restoredEntries = await reopenedRepository.fetchEntries(
          bottleId: bottleId,
        );
        expect(restoredEntries, hasLength(1));
        expect(restoredEntries.single.toMap(), persistedEntry);
        expect(await reopenedRepository.fetchActiveEntry(), isNull);
        await _pumpUntil(
          tester,
          startButton,
          reason: 'The saved bottle was not restored to the home page.',
        );
        expect(tester.takeException(), isNull);
        debugPrint('TIMESAND_STARTUP_SMOKE: persisted timer restored');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final openDatabase = database;
        if (openDatabase != null && openDatabase.database.isOpen) {
          await openDatabase.close();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _launchProductionApp(WidgetTester tester) async {
  await Future<void>.sync(app.main).timeout(const Duration(seconds: 30));
  await _pumpUntil(
    tester,
    find.byType(HomePage),
    reason: 'Production startup did not reach HomePage.',
  );
  await _pumpUntil(
    tester,
    find.byKey(const ValueKey('create-bottle-button')),
    reason: 'The home page could not load the real SQLite database.',
  );
  expect(find.byType(TimeSandApp), findsOneWidget);
  debugPrint('TIMESAND_STARTUP_SMOKE: production home ready');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required String reason,
  bool absent = false,
}) async {
  final deadline = Stopwatch()..start();
  while ((absent ? finder.evaluate().isNotEmpty : finder.evaluate().isEmpty) &&
      deadline.elapsed < const Duration(seconds: 30)) {
    // The hourglass animates continuously, so pumpAndSettle cannot be used.
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, absent ? findsNothing : findsOneWidget, reason: reason);
  expect(tester.takeException(), isNull);
}
