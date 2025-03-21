import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import 'file_service.dart';

class BookService {
  // 本来はデータベースやファイルに保存するが、簡易的にメモリ内リストで管理
  List<Book> _books = [];
  final _uuid = Uuid();
  final _fileService = FileService();
  bool _initialized = false;

  // シングルトンパターン
  static final BookService _instance = BookService._internal();

  factory BookService() {
    return _instance;
  }

  BookService._internal();

  // サービスを初期化
  Future<void> initialize() async {
    if (_initialized) return;

    await _fileService.initialize();
    _initialized = true;
  }

  // 全ての本を取得
  List<Book> getAllBooks() {
    return List.unmodifiable(_books);
  }

  // タグでフィルタリングした本を取得
  List<Book> getBooksByTags(List<String> tags) {
    if (tags.isEmpty) return getAllBooks();

    return _books.where((book) {
      return tags.every((tag) => book.tags.contains(tag));
    }).toList();
  }

  // 本を追加
  Future<Book> addBook(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    // ファイルタイプを取得
    final extension = path.extension(filePath).toLowerCase();
    String fileType;
    if (extension == '.zip' || extension == '.cbz') {
      fileType = extension.substring(1); // 先頭の.を除去
    } else if (extension == '.pdf') {
      fileType = 'pdf';
    } else {
      throw Exception('Unsupported file type: $extension');
    }

    // ファイル名を取得（拡張子なし）
    final fileName = path.basenameWithoutExtension(filePath);

    // ファイルをアプリの管理領域にコピー
    final managedFilePath = await _fileService.copyFileToAppStorage(filePath);

    // 新しい本を作成
    final book = Book(
      id: _uuid.v4(),
      title: fileName,
      filePath: managedFilePath, // アプリ管理領域内のパスを保存
      fileType: fileType,
      addedAt: DateTime.now(),
    );

    // リストに追加
    _books.add(book);

    return book;
  }

  // 本を更新
  Book updateBook(Book book) {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index == -1) {
      throw Exception('Book not found: ${book.id}');
    }

    _books[index] = book;
    return book;
  }

  // 本を削除
  Future<void> deleteBook(String id) async {
    if (!_initialized) await initialize();

    final bookIndex = _books.indexWhere((book) => book.id == id);
    if (bookIndex != -1) {
      final book = _books[bookIndex];

      // アプリの管理領域からファイルを削除
      try {
        await _fileService.deleteFile(book.filePath);
      } catch (e) {
        print('ファイル削除エラー: $e');
        // ファイル削除に失敗しても、リストからは削除する
      }

      // リストから削除
      _books.removeAt(bookIndex);
    }
  }

  // 本の名前を変更
  Book renameBook(String id, String newTitle) {
    final index = _books.indexWhere((b) => b.id == id);
    if (index == -1) {
      throw Exception('Book not found: $id');
    }

    final updatedBook = _books[index].copyWith(title: newTitle);
    _books[index] = updatedBook;
    return updatedBook;
  }

  // タグを追加
  Book addTag(String bookId, String tag) {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final book = _books[index];
    if (book.tags.contains(tag)) {
      return book; // タグが既に存在する場合は何もしない
    }

    final updatedTags = List<String>.from(book.tags)..add(tag);
    final updatedBook = book.copyWith(tags: updatedTags);
    _books[index] = updatedBook;
    return updatedBook;
  }

  // タグを削除
  Book removeTag(String bookId, String tag) {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final book = _books[index];
    if (!book.tags.contains(tag)) {
      return book; // タグが存在しない場合は何もしない
    }

    final updatedTags = List<String>.from(book.tags)..remove(tag);
    final updatedBook = book.copyWith(tags: updatedTags);
    _books[index] = updatedBook;
    return updatedBook;
  }

  // 最後に読んだページを更新
  Book updateLastReadPage(String bookId, int pageNumber) {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final updatedBook = _books[index].copyWith(
      lastReadPage: pageNumber,
      lastReadAt: DateTime.now(),
    );
    _books[index] = updatedBook;
    return updatedBook;
  }

  // ページめくり方向を変更
  Book toggleReadingDirection(String bookId) {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final book = _books[index];
    final updatedBook = book.copyWith(isRightToLeft: !book.isRightToLeft);
    _books[index] = updatedBook;
    return updatedBook;
  }
}
