import 'dart:convert';

import '../records/time_models.dart';
import 'app_database.dart';
import 'time_records_repository.dart';

enum ImportMode { merge, replace }

class LocalDataTransferException implements Exception {
  const LocalDataTransferException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImportPreview {
  const ImportPreview({
    required this.formatVersion,
    required this.timezone,
    required this.bottleCount,
    required this.entryCount,
    required this.mode,
  });

  final int formatVersion;
  final String timezone;
  final int bottleCount;
  final int entryCount;
  final ImportMode mode;
}

class LocalDataBundle {
  const LocalDataBundle({
    required this.formatVersion,
    required this.exportedAt,
    required this.timezone,
    required this.schemaVersion,
    required this.bottles,
    required this.entries,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final String timezone;
  final int schemaVersion;
  final List<Bottle> bottles;
  final List<TimeEntry> entries;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'format_version': formatVersion,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'timezone': timezone,
      'timezone_offset_minutes': exportedAt.timeZoneOffset.inMinutes,
      'database': <String, Object?>{'schema_version': schemaVersion},
      'bottles': bottles.map(_bottleToJson).toList(growable: false),
      'time_entries': entries.map(_entryToJson).toList(growable: false),
    };
  }

  static Map<String, Object?> _bottleToJson(Bottle bottle) {
    return <String, Object?>{
      'id': bottle.id,
      'name': bottle.name,
      'color': bottle.color,
      'created_at': bottle.createdAt.toUtc().toIso8601String(),
      'updated_at': bottle.updatedAt.toUtc().toIso8601String(),
      'is_archived': bottle.isArchived,
    };
  }

  static Map<String, Object?> _entryToJson(TimeEntry entry) {
    return <String, Object?>{
      'id': entry.id,
      'bottle_id': entry.bottleId,
      'started_at': entry.startedAt.toUtc().toIso8601String(),
      'ended_at': entry.endedAt?.toUtc().toIso8601String(),
      'duration_seconds': entry.endedAt == null
          ? null
          : entry.endedAt!.difference(entry.startedAt).inSeconds,
      'source': entry.source.value,
      'notes': entry.notes,
      'created_at': entry.createdAt.toUtc().toIso8601String(),
      'updated_at': entry.updatedAt.toUtc().toIso8601String(),
    };
  }
}

abstract final class LocalDataTransfer {
  static const int formatVersion = 1;
  static const int maxBackupBytes = 20 * 1024 * 1024;

  static Future<LocalDataBundle> capture(
    TimeRecordsRepository repository, {
    DateTime? exportedAt,
  }) async {
    final timestamp = exportedAt ?? DateTime.now();
    return repository.database.database.transaction((txn) async {
      final bottles = await txn.query('bottles', orderBy: 'id');
      final entries = await txn.query('time_entries', orderBy: 'id');
      return LocalDataBundle(
        formatVersion: formatVersion,
        exportedAt: timestamp,
        timezone: timestamp.timeZoneName,
        schemaVersion: TimeSandDatabase.currentSchemaVersion,
        bottles: bottles.map(Bottle.fromMap).toList(),
        entries: entries.map(TimeEntry.fromMap).toList(),
      );
    });
  }

  static Future<String> exportJson(
    TimeRecordsRepository repository, {
    DateTime? exportedAt,
  }) async {
    final bundle = await capture(repository, exportedAt: exportedAt);
    final raw = const JsonEncoder.withIndent('  ').convert(bundle.toJson());
    if (utf8.encode(raw).length > maxBackupBytes) {
      throw const LocalDataTransferException(
        '备份超过 20 MiB，无法导出可恢复的 JSON。请先导出 CSV 保存记录。',
      );
    }
    return raw;
  }

  static Future<String> exportCsv(TimeRecordsRepository repository) async {
    final bundle = await capture(repository);
    final rows = <List<Object?>>[
      <Object?>[
        'time_entry_id',
        'bottle_id',
        'bottle_name',
        'started_at',
        'ended_at',
        'duration_seconds',
        'source',
        'created_at',
        'updated_at',
      ],
    ];
    final names = <int, String>{
      for (final bottle in bundle.bottles) bottle.id!: bottle.name,
    };
    for (final entry in bundle.entries) {
      rows.add(<Object?>[
        entry.id,
        entry.bottleId,
        names[entry.bottleId] ?? '',
        entry.startedAt.toUtc().toIso8601String(),
        entry.endedAt?.toUtc().toIso8601String() ?? '',
        entry.endedAt == null
            ? ''
            : entry.endedAt!.difference(entry.startedAt).inSeconds,
        entry.source.value,
        entry.createdAt.toUtc().toIso8601String(),
        entry.updatedAt.toUtc().toIso8601String(),
      ]);
    }
    return rows.map((row) => row.map(_csvCell).join(',')).join('\n') + '\n';
  }

  static LocalDataBundle parseJson(String raw, {DateTime? now}) {
    final referenceNow = now ?? DateTime.now();
    if (utf8.encode(raw).length > maxBackupBytes) {
      throw const LocalDataTransferException('备份文件不能超过 20 MiB。');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const LocalDataTransferException('导入文件必须是 JSON 对象。');
    }

    final version = _requiredInt(decoded, 'format_version');
    if (version != formatVersion) {
      throw LocalDataTransferException('不支持的导出格式版本：$version。');
    }
    final exportedAt = _requiredDate(decoded, 'exported_at');
    final timezone = _requiredString(decoded, 'timezone');
    final offset = _requiredInt(decoded, 'timezone_offset_minutes');
    if (offset < -24 * 60 || offset > 24 * 60) {
      throw const LocalDataTransferException('时区偏移无效。');
    }
    final database = decoded['database'];
    final schemaVersion = database is Map<String, dynamic>
        ? _requiredInt(database, 'schema_version')
        : 0;

    if (schemaVersion < 1 ||
        schemaVersion > TimeSandDatabase.currentSchemaVersion) {
      throw const LocalDataTransferException('缺少或不支持的数据库版本。');
    }
    if (timezone.trim().isEmpty) {
      throw const LocalDataTransferException('时区信息不能为空。');
    }
    final bottlesRaw = decoded['bottles'];
    final entriesRaw = decoded['time_entries'];
    if (bottlesRaw is! List || entriesRaw is! List) {
      throw const LocalDataTransferException('导入文件缺少 bottles 或 time_entries。');
    }

    final bottles = <Bottle>[];
    final bottleIds = <int>{};
    for (final value in bottlesRaw) {
      if (value is! Map<String, dynamic>) {
        throw const LocalDataTransferException('瓶子记录格式无效。');
      }
      final id = _requiredInt(value, 'id');
      if (id <= 0) throw const LocalDataTransferException('ID 必须为正整数。');
      if (!bottleIds.add(id)) {
        throw LocalDataTransferException('瓶子 ID 重复：$id。');
      }
      final name = _requiredString(value, 'name').trim();
      if (name.isEmpty) {
        throw const LocalDataTransferException('瓶子名称不能为空。');
      }
      final color = _requiredInt(value, 'color');
      if (color < 0 || color > 0xFFFFFFFF) {
        throw const LocalDataTransferException('颜色必须为 32 位 ARGB 值。');
      }
      bottles.add(
        Bottle(
          id: id,
          name: name,
          color: color,
          createdAt: _requiredDate(value, 'created_at'),
          updatedAt: _requiredDate(value, 'updated_at'),
          isArchived: _requiredBool(value, 'is_archived'),
        ),
      );
    }

    final entries = <TimeEntry>[];
    final entryIds = <int>{};
    for (final value in entriesRaw) {
      if (value is! Map<String, dynamic>) {
        throw const LocalDataTransferException('时间记录格式无效。');
      }
      final id = _requiredInt(value, 'id');
      if (id <= 0) throw const LocalDataTransferException('ID 必须为正整数。');
      if (!entryIds.add(id)) {
        throw LocalDataTransferException('时间记录 ID 重复：$id。');
      }
      final bottleId = _requiredInt(value, 'bottle_id');
      if (!bottleIds.contains(bottleId)) {
        throw LocalDataTransferException('时间记录引用了未知瓶子：$bottleId。');
      }
      final startedAt = _requiredDate(value, 'started_at');
      if (!value.containsKey('ended_at') ||
          !value.containsKey('duration_seconds')) {
        throw const LocalDataTransferException('缺少结束时间或时长字段。');
      }
      final endedAt = _optionalDate(value['ended_at']);
      if (startedAt.isAfter(referenceNow) ||
          (endedAt != null && endedAt.isAfter(referenceNow))) {
        throw const LocalDataTransferException('时间记录不能位于未来。');
      }
      final source = TimeEntrySourceCodec.parse(
        _requiredString(value, 'source'),
      );
      if (endedAt == null && source == TimeEntrySource.manual) {
        throw const LocalDataTransferException('manual 记录必须有结束时间。');
      }
      if (endedAt != null && !endedAt.isAfter(startedAt)) {
        throw const LocalDataTransferException('时间记录区间无效。');
      }
      final suppliedDuration = value['duration_seconds'];
      if (suppliedDuration != null && suppliedDuration is! int) {
        throw const LocalDataTransferException('duration_seconds 格式无效。');
      }
      if ((endedAt == null && suppliedDuration != null) ||
          (endedAt != null && suppliedDuration == null)) {
        throw const LocalDataTransferException('结束时间与时长字段不一致。');
      }
      if (suppliedDuration is int &&
          endedAt != null &&
          suppliedDuration != endedAt.difference(startedAt).inSeconds) {
        throw const LocalDataTransferException('时间记录时长与起止时间不一致。');
      }
      entries.add(
        TimeEntry(
          id: id,
          bottleId: bottleId,
          startedAt: startedAt,
          endedAt: endedAt,
          durationSeconds: endedAt == null
              ? null
              : endedAt.difference(startedAt).inSeconds,
          source: source,
          notes: schemaVersion >= 2 || value.containsKey('notes')
              ? _requiredString(value, 'notes')
              : '',
          createdAt: _requiredDate(value, 'created_at'),
          updatedAt: _requiredDate(value, 'updated_at'),
        ),
      );
    }

    _validateNoOverlaps(entries);
    return LocalDataBundle(
      formatVersion: version,
      exportedAt: exportedAt,
      timezone: timezone,
      schemaVersion: schemaVersion,
      bottles: List.unmodifiable(bottles),
      entries: List.unmodifiable(entries),
    );
  }

  static ImportPreview previewJson(
    String raw, {
    ImportMode mode = ImportMode.merge,
  }) {
    final bundle = parseJson(raw);
    return ImportPreview(
      formatVersion: bundle.formatVersion,
      timezone: bundle.timezone,
      bottleCount: bundle.bottles.length,
      entryCount: bundle.entries.length,
      mode: mode,
    );
  }

  static Future<void> importJson(
    TimeRecordsRepository repository,
    String raw, {
    required ImportMode mode,
  }) async {
    final bundle = parseJson(raw);
    await repository.database.database.transaction((txn) async {
      if (mode == ImportMode.merge) {
        final existing = await txn.query('time_entries');
        _validateNoOverlaps([
          ...existing.map(TimeEntry.fromMap),
          ...bundle.entries,
        ]);
      }
      if (mode == ImportMode.replace) {
        await txn.delete('time_entries');
        await txn.delete('bottles');
      }

      final bottleIds = <int, int>{};
      for (final bottle in bundle.bottles) {
        final values = <String, Object?>{
          if (mode == ImportMode.replace) 'id': bottle.id,
          'name': bottle.name,
          'color': bottle.color,
          'created_at': bottle.createdAt.toUtc().toIso8601String(),
          'updated_at': bottle.updatedAt.toUtc().toIso8601String(),
          'is_archived': bottle.isArchived ? 1 : 0,
        };
        final id = await txn.insert('bottles', values);
        bottleIds[bottle.id!] = id;
      }

      for (final entry in bundle.entries) {
        final endedAt = entry.endedAt;
        await txn.insert('time_entries', <String, Object?>{
          if (mode == ImportMode.replace) 'id': entry.id,
          'bottle_id': bottleIds[entry.bottleId],
          'started_at': entry.startedAt.toUtc().toIso8601String(),
          'ended_at': endedAt?.toUtc().toIso8601String(),
          'duration_seconds': endedAt == null
              ? null
              : endedAt.difference(entry.startedAt).inSeconds,
          'source': entry.source.value,
          'notes': entry.notes,
          'created_at': entry.createdAt.toUtc().toIso8601String(),
          'updated_at': entry.updatedAt.toUtc().toIso8601String(),
        });
      }
    });
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw LocalDataTransferException('缺少或无效字段：$key。');
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw LocalDataTransferException('缺少或无效字段：$key。');
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw LocalDataTransferException('缺少或无效字段：$key。');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, dynamic> map, String key) {
    return _optionalDate(map[key]) ??
        (throw LocalDataTransferException('缺少或无效字段：$key。'));
  }

  static DateTime? _optionalDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw const LocalDataTransferException('时间字段格式无效。');
    }
    try {
      final parsed = DateTime.parse(value);
      if (!parsed.isUtc || parsed.toIso8601String() != value) {
        throw const FormatException('Expected canonical UTC ISO-8601');
      }
      return parsed.toLocal();
    } on FormatException {
      throw const LocalDataTransferException('时间字段格式无效。');
    }
  }

  static String _csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'" + text;
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static void _validateNoOverlaps(Iterable<TimeEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      if (previous.endedAt == null ||
          current.startedAt.isBefore(previous.endedAt!)) {
        throw const LocalDataTransferException('导入内容与已有记录重叠或包含多个活动计时器。');
      }
    }
  }
}
