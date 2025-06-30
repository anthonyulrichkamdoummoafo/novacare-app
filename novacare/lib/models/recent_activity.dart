class RecentActivity {
  final String id;
  final String type;
  final String description;
  final DateTime timestamp;

  RecentActivity({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  factory RecentActivity.fromMap(Map<String, dynamic> map) {
    return RecentActivity(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      timestamp: DateTime.parse(
          map['timestamp']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'RecentActivity(id: $id, type: $type, description: $description, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentActivity &&
        other.id == id &&
        other.type == type &&
        other.description == description &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        type.hashCode ^
        description.hashCode ^
        timestamp.hashCode;
  }
}
