import 'package:flutter/foundation.dart';

class Book {
  final String id;
  final String title;
  final String filePath;
  final String fileType; // zip, cbz, pdf
  final List<String> tags;
  final bool isRightToLeft; // 右から左へのページめくり方向
  final int lastReadPage;
  final DateTime addedAt;
  final DateTime? lastReadAt;

  Book({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileType,
    this.tags = const [],
    this.isRightToLeft = true, // 日本の漫画はデフォルトで右から左
    this.lastReadPage = 0,
    required this.addedAt,
    this.lastReadAt,
  });

  Book copyWith({
    String? id,
    String? title,
    String? filePath,
    String? fileType,
    List<String>? tags,
    bool? isRightToLeft,
    int? lastReadPage,
    DateTime? addedAt,
    DateTime? lastReadAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      tags: tags ?? this.tags,
      isRightToLeft: isRightToLeft ?? this.isRightToLeft,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'fileType': fileType,
      'tags': tags,
      'isRightToLeft': isRightToLeft,
      'lastReadPage': lastReadPage,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      filePath: map['filePath'],
      fileType: map['fileType'],
      tags: List<String>.from(map['tags']),
      isRightToLeft: map['isRightToLeft'],
      lastReadPage: map['lastReadPage'],
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt']),
      lastReadAt:
          map['lastReadAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['lastReadAt'])
              : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
