import '../records/time_entry_rules.dart';
import '../records/time_models.dart';
import 'app_database.dart';

class TimeRecordsRepository {
  TimeRecordsRepository(this.database);

  final TimeSandDatabase database;

  Future<List<Bottle>> fetchBottles({bool includeArchived = false}) async {
    final rows = await database.database.query(
      'bottles',
      where: includeArchived ? null : 'is_archived = ?',
      whereArgs: includeArchived ? null : <Object>[0],
      orderBy: 'created_at ASC',
    );
    return rows.map(Bottle.fromMap).toList(growable: false);
  }

  Future<Bottle?> fetchBottle(int id) async {
    final rows = await database.database.query(
      'bottles',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : Bottle.fromMap(rows.first);
  }

  Future<Bottle> createBottle({
    required String name,
    required int color,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const InvalidTimeEntryException('时间之瓶名称不能为空。');
    }
    final timestamp = now ?? DateTime.now();
    final id = await database.database.insert(
      'bottles',
      Bottle(
        name: trimmed,
        color: color,
        createdAt: timestamp,
        updatedAt: timestamp,
      ).toMap(),
    );
    return (await fetchBottle(id))!;
  }

  Future<Bottle> updateBottle({
    required int id,
    String? name,
    int? color,
    DateTime? now,
  }) async {
    final current = await fetchBottle(id);
    if (current == null) {
      throw StateError('找不到时间之瓶 $id。');
    }
    final timestamp = now ?? DateTime.now();
    final updatedName = name?.trim() ?? current.name;
    if (updatedName.isEmpty) {
      throw const InvalidTimeEntryException('时间之瓶名称不能为空。');
    }
    await database.database.update(
      'bottles',
      <String, Object?>{
        'name': updatedName,
        'color': color ?? current.color,
        'updated_at': timestamp.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    return (await fetchBottle(id))!;
  }

  Future<void> archiveBottle(int id, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    await database.database.update(
      'bottles',
      <String, Object?>{
        'is_archived': 1,
        'updated_at': timestamp.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  Future<List<TimeEntry>> fetchEntries({int? bottleId}) async {
    final rows = await database.database.query(
      'time_entries',
      where: bottleId == null ? null : 'bottle_id = ?',
      whereArgs: bottleId == null ? null : <Object>[bottleId],
      orderBy: 'started_at ASC',
    );
    return rows.map(TimeEntry.fromMap).toList(growable: false);
  }

  Future<TimeEntry?> fetchActiveEntry() async {
    final rows = await database.database.query(
      'time_entries',
      where: 'ended_at IS NULL',
      orderBy: 'started_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : TimeEntry.fromMap(rows.first);
  }

  Future<TimeEntry> startTimer({
    required int bottleId,
    DateTime? startedAt,
  }) async {
    final bottle = await fetchBottle(bottleId);
    if (bottle == null || bottle.isArchived) {
      throw StateError('只能在未归档的时间之瓶中开始计时。');
    }

    final start = startedAt ?? DateTime.now();
    final entries = await fetchEntries();
    TimeEntryRules.validateActiveTimer(entries);
    TimeEntryRules.validateInterval(
      startedAt: start,
      endedAt: null,
      existingEntries: entries,
    );

    final timestamp = DateTime.now();
    final id = await database.database.insert(
      'time_entries',
      TimeEntry(
        bottleId: bottleId,
        startedAt: start,
        source: TimeEntrySource.active,
        createdAt: timestamp,
        updatedAt: timestamp,
      ).toMap(),
    );
    final result = await fetchEntries();
    return result.firstWhere((entry) => entry.id == id);
  }

  Future<TimeEntry> stopTimer({DateTime? endedAt}) async {
    final active = await fetchActiveEntry();
    if (active == null) {
      throw StateError('当前没有正在进行的计时器。');
    }

    final end = endedAt ?? DateTime.now();
    final entries = await fetchEntries();
    TimeEntryRules.validateInterval(
      startedAt: active.startedAt,
      endedAt: end,
      existingEntries: entries,
      ignoredEntryId: active.id,
    );

    final timestamp = DateTime.now();
    await database.database.update(
      'time_entries',
      <String, Object?>{
        'ended_at': end.toUtc().toIso8601String(),
        'duration_seconds': end.difference(active.startedAt).inSeconds,
        'updated_at': timestamp.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[active.id!],
    );
    final updated = await fetchEntries();
    return updated.firstWhere((entry) => entry.id == active.id);
  }

  Future<TimeEntry> createManualEntry({
    required int bottleId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final bottle = await fetchBottle(bottleId);
    if (bottle == null || bottle.isArchived) {
      throw StateError('只能为未归档的时间之瓶补录时间。');
    }
    final entries = await fetchEntries();
    TimeEntryRules.validateInterval(
      startedAt: startedAt,
      endedAt: endedAt,
      existingEntries: entries,
    );

    final timestamp = DateTime.now();
    final id = await database.database.insert(
      'time_entries',
      TimeEntry(
        bottleId: bottleId,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: endedAt.difference(startedAt).inSeconds,
        source: TimeEntrySource.manual,
        createdAt: timestamp,
        updatedAt: timestamp,
      ).toMap(),
    );
    final result = await fetchEntries();
    return result.firstWhere((entry) => entry.id == id);
  }

  Future<TimeEntry> updateEntry({
    required int id,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final currentEntries = await fetchEntries();
    final current = currentEntries.firstWhere(
      (entry) => entry.id == id,
      orElse: () => throw StateError('找不到时间记录 $id。'),
    );
    TimeEntryRules.validateInterval(
      startedAt: startedAt,
      endedAt: endedAt,
      existingEntries: currentEntries,
      ignoredEntryId: id,
    );

    final timestamp = DateTime.now();
    await database.database.update(
      'time_entries',
      <String, Object?>{
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_seconds': endedAt.difference(startedAt).inSeconds,
        'updated_at': timestamp.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    final updated = await fetchEntries();
    return updated.firstWhere((entry) => entry.id == current.id);
  }

  Future<void> deleteEntry(int id) async {
    await database.database.delete(
      'time_entries',
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }
}
