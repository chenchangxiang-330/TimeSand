enum TimeEntrySource { active, manual }

extension TimeEntrySourceCodec on TimeEntrySource {
  String get value => name;

  static TimeEntrySource parse(String value) {
    return TimeEntrySource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => throw FormatException('Unknown time entry source: $value'),
    );
  }
}

class Bottle {
  const Bottle({
    this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final int? id;
  final String name;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  Bottle copyWith({
    int? id,
    String? name,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Bottle(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Bottle.fromMap(Map<String, Object?> map) {
    return Bottle(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      isArchived: (map['is_archived'] as int) == 1,
    );
  }
}

class TimeEntry {
  const TimeEntry({
    this.id,
    required this.bottleId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int bottleId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final TimeEntrySource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => endedAt == null;

  Duration durationAt(DateTime now) {
    final end = endedAt ?? now;
    final difference = end.difference(startedAt);
    return difference.isNegative ? Duration.zero : difference;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'bottle_id': bottleId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'source': source.value,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory TimeEntry.fromMap(Map<String, Object?> map) {
    final endedAt = map['ended_at'] as String?;
    return TimeEntry(
      id: map['id'] as int?,
      bottleId: map['bottle_id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: endedAt == null ? null : DateTime.parse(endedAt).toLocal(),
      durationSeconds: map['duration_seconds'] as int?,
      source: TimeEntrySourceCodec.parse(map['source'] as String),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }
}
