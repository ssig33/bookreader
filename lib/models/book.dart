class Book {
  final String id;
  final String title;
  final String filePath;
  final String fileType; // zip, cbz, pdf
  final List<String> tags;
  final bool isRightToLeft; // 右から左へのページめくり方向
  final int lastReadPage;
  final int totalPages; // 総ページ数
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final Map<int, double>? aspectRatios; // ページごとのアスペクト比情報

  Book({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileType,
    this.tags = const [],
    this.isRightToLeft = true, // 日本の漫画はデフォルトで右から左
    this.lastReadPage = 0,
    this.totalPages = 0, // デフォルトは0（未取得）
    required this.addedAt,
    this.lastReadAt,
    this.aspectRatios,
  });

  Book copyWith({
    String? id,
    String? title,
    String? filePath,
    String? fileType,
    List<String>? tags,
    bool? isRightToLeft,
    int? lastReadPage,
    int? totalPages,
    DateTime? addedAt,
    DateTime? lastReadAt,
    Map<int, double>? aspectRatios,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      tags: tags ?? this.tags,
      isRightToLeft: isRightToLeft ?? this.isRightToLeft,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      totalPages: totalPages ?? this.totalPages,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      aspectRatios: aspectRatios ?? this.aspectRatios,
    );
  }

  // アスペクト比を更新した新しいBookインスタンスを作成
  Book copyWithAspectRatio(int pageIndex, double aspectRatio) {
    final newAspectRatios = Map<int, double>.from(aspectRatios ?? {});
    newAspectRatios[pageIndex] = aspectRatio;

    return copyWith(aspectRatios: newAspectRatios);
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
      'totalPages': totalPages,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
      'aspectRatios': aspectRatios,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    // アスペクト比情報の変換（文字列キーをintに変換）
    Map<int, double>? aspectRatiosMap;
    if (map['aspectRatios'] != null) {
      aspectRatiosMap = {};
      (map['aspectRatios'] as Map).forEach((key, value) {
        if (value is num) {
          aspectRatiosMap![int.parse(key.toString())] = value.toDouble();
        }
      });
    }

    return Book(
      id: map['id'],
      title: map['title'],
      filePath: map['filePath'],
      fileType: map['fileType'],
      tags: List<String>.from(map['tags']),
      isRightToLeft: map['isRightToLeft'],
      lastReadPage: map['lastReadPage'],
      totalPages: map['totalPages'] ?? 0, // 古いデータ互換性のため
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt']),
      lastReadAt:
          map['lastReadAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['lastReadAt'])
              : null,
      aspectRatios: aspectRatiosMap,
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
