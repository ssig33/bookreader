import 'package:uuid/uuid.dart';

class SearchCondition {
  final String id;
  final String name;
  final String query;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  SearchCondition({
    String? id,
    required this.name,
    required this.query,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       lastUsedAt = lastUsedAt ?? DateTime.now();

  SearchCondition copyWith({
    String? id,
    String? name,
    String? query,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return SearchCondition(
      id: id ?? this.id,
      name: name ?? this.name,
      query: query ?? this.query,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'query': query,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUsedAt': lastUsedAt.millisecondsSinceEpoch,
    };
  }

  factory SearchCondition.fromMap(Map<String, dynamic> map) {
    return SearchCondition(
      id: map['id'],
      name: map['name'],
      query: map['query'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastUsedAt: DateTime.fromMillisecondsSinceEpoch(map['lastUsedAt']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchCondition && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
