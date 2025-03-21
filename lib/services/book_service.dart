import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import 'file_service.dart';

class BookService {
  List<Book> _books = [];
  final _uuid = Uuid();
  final _fileService = FileService();
  bool _initialized = false;
  late String _booksJsonPath;

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

    // JSONファイルのパスを設定
    final appDir = await _fileService.getAppStoragePath();
    _booksJsonPath = path.join(appDir, 'books.json');

    // JSONファイルが存在する場合は読み込む
    await _loadBooksFromJson();

    _initialized = true;
  }

  // JSONファイルから本の情報を読み込む
  Future<void> _loadBooksFromJson() async {
    final file = File(_booksJsonPath);
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _books = jsonList.map((json) => Book.fromMap(json)).toList();
      } catch (e) {
        print('JSONファイルの読み込みエラー: $e');
        // エラーが発生した場合は空のリストで初期化
        _books = [];
      }
    }
  }

  // 本の情報をJSONファイルに保存
  Future<void> _saveBooksToJson() async {
    if (!_initialized) await initialize();

    final file = File(_booksJsonPath);
    final jsonList = _books.map((book) => book.toMap()).toList();
    final jsonString = json.encode(jsonList);

    try {
      await file.writeAsString(jsonString);
    } catch (e) {
      print('JSONファイルの保存エラー: $e');
    }
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

    // ページ数を取得
    int totalPages = 0;
    try {
      totalPages = await _fileService.getPageCount(managedFilePath, fileType);
    } catch (e) {
      print('ページ数取得エラー: $e');
      // エラーが発生しても処理を続行
    }

    // 新しい本を作成
    final book = Book(
      id: _uuid.v4(),
      title: fileName,
      filePath: managedFilePath, // アプリ管理領域内のパスを保存
      fileType: fileType,
      totalPages: totalPages,
      addedAt: DateTime.now(),
    );

    // リストに追加
    _books.add(book);

    // JSONファイルに保存
    await _saveBooksToJson();

    return book;
  }

  // 本を更新
  Future<Book> updateBook(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index == -1) {
      throw Exception('Book not found: ${book.id}');
    }

    _books[index] = book;

    // JSONファイルに保存
    await _saveBooksToJson();

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

      // JSONファイルに保存
      await _saveBooksToJson();
    }
  }

  // 本の名前を変更
  Future<Book> renameBook(String id, String newTitle) async {
    final index = _books.indexWhere((b) => b.id == id);
    if (index == -1) {
      throw Exception('Book not found: $id');
    }

    final updatedBook = _books[index].copyWith(title: newTitle);
    _books[index] = updatedBook;

    // JSONファイルに保存
    await _saveBooksToJson();

    return updatedBook;
  }

  // タグを追加
  Future<Book> addTag(String bookId, String tag) async {
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

    // JSONファイルに保存
    await _saveBooksToJson();

    return updatedBook;
  }

  // タグを削除
  Future<Book> removeTag(String bookId, String tag) async {
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

    // JSONファイルに保存
    await _saveBooksToJson();

    return updatedBook;
  }

  // 最後に読んだページを更新
  Future<Book> updateLastReadPage(String bookId, int pageNumber) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final updatedBook = _books[index].copyWith(
      lastReadPage: pageNumber,
      lastReadAt: DateTime.now(),
    );
    _books[index] = updatedBook;

    // JSONファイルに保存
    await _saveBooksToJson();

    return updatedBook;
  }

  // ページめくり方向を変更
  Future<Book> toggleReadingDirection(String bookId) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final book = _books[index];
    final updatedBook = book.copyWith(isRightToLeft: !book.isRightToLeft);
    _books[index] = updatedBook;

    // JSONファイルに保存
    await _saveBooksToJson();

    return updatedBook;
  }

  // 総ページ数を更新
  Future<Book> updateTotalPages(String bookId, int totalPages) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) {
      throw Exception('Book not found: $bookId');
    }

    final updatedBook = _books[index].copyWith(totalPages: totalPages);
    _books[index] = updatedBook;

    // JSONファイルに保存
    await _saveBooksToJson();

    return updatedBook;
  }

  // 既存の本のページ数を取得して更新
  Future<void> updateAllBooksPageCount() async {
    if (!_initialized) await initialize();

    for (int i = 0; i < _books.length; i++) {
      final book = _books[i];

      // ページ数が0の場合のみ更新
      if (book.totalPages == 0) {
        try {
          final totalPages = await _fileService.getPageCount(
            book.filePath,
            book.fileType,
          );
          if (totalPages > 0) {
            _books[i] = book.copyWith(totalPages: totalPages);
          }
        } catch (e) {
          print('ページ数更新エラー (${book.title}): $e');
          // エラーが発生しても処理を続行
        }
      }
    }

    // JSONファイルに保存
    await _saveBooksToJson();
  }
}
