import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../models/search_condition.dart';
import 'file_service.dart';

class BookService {
  List<Book> _books = [];
  List<SearchCondition> _searchConditions = [];
  final _uuid = Uuid();
  final _fileService = FileService();
  bool _initialized = false;
  late String _booksJsonPath;
  late String _searchConditionsJsonPath;

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
    _searchConditionsJsonPath = path.join(appDir, 'search_conditions.json');

    // JSONファイルが存在する場合は読み込む
    await _loadBooksFromJson();
    await _loadSearchConditionsFromJson();

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
        // エラーが発生した場合は空のリストで初期化
        _books = [];
      }
    }
  }

  // 検索条件をJSONファイルから読み込む
  Future<void> _loadSearchConditionsFromJson() async {
    final file = File(_searchConditionsJsonPath);
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _searchConditions =
            jsonList.map((json) => SearchCondition.fromMap(json)).toList();
      } catch (e) {
        // エラーが発生した場合は空のリストで初期化
        _searchConditions = [];
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
      // エラー処理
    }
  }

  // 検索条件をJSONファイルに保存
  Future<void> _saveSearchConditionsToJson() async {
    if (!_initialized) await initialize();

    try {
      final file = File(_searchConditionsJsonPath);
      final jsonList =
          _searchConditions.map((condition) => condition.toMap()).toList();
      final jsonString = json.encode(jsonList);

      await file.writeAsString(jsonString);
    } catch (e) {
      // エラー処理
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

  // ファイル名とタグで検索した本を取得（スペース区切りで複数キーワード対応）
  List<Book> searchBooks(String query, {List<String> selectedTags = const []}) {
    if (query.isEmpty && selectedTags.isEmpty) return getAllBooks();

    // スペースで区切られた検索キーワードを取得
    final keywords =
        query.toLowerCase().split(' ').where((k) => k.isNotEmpty).toList();

    // タグでフィルタリングした本を取得
    List<Book> filteredBooks = getBooksByTags(selectedTags);

    // キーワードが空の場合はタグでフィルタリングした結果を返す
    if (keywords.isEmpty) return filteredBooks;

    // キーワードでさらにフィルタリング
    return filteredBooks.where((book) {
      final title = book.title.toLowerCase();
      final tags = book.tags.map((t) => t.toLowerCase()).toList();

      // すべてのキーワードがタイトルまたはタグに含まれているかチェック
      return keywords.every((keyword) {
        return title.contains(keyword) ||
            tags.any((tag) => tag.contains(keyword));
      });
    }).toList();
  }

  // 検索結果をファイル名で降順ソート
  List<Book> sortBooksByTitleDesc(List<Book> books) {
    final sortedBooks = List<Book>.from(books);
    sortedBooks.sort((a, b) => b.title.compareTo(a.title));
    return sortedBooks;
  }

  // 全ての保存済み検索条件を取得
  List<SearchCondition> getAllSearchConditions() {
    return List.unmodifiable(_searchConditions);
  }

  // 使用順に並べた保存済み検索条件を取得
  List<SearchCondition> getSearchConditionsByLastUsed() {
    final sortedConditions = List<SearchCondition>.from(_searchConditions);
    sortedConditions.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return sortedConditions;
  }

  // 検索条件を保存
  Future<SearchCondition> saveSearchCondition(String name, String query) async {
    if (!_initialized) await initialize();

    try {
      // 同じ名前の検索条件がある場合は上書き
      final existingIndex = _searchConditions.indexWhere((c) => c.name == name);

      final searchCondition = SearchCondition(name: name, query: query);

      if (existingIndex != -1) {
        _searchConditions[existingIndex] = searchCondition;
      } else {
        _searchConditions.add(searchCondition);
      }

      // JSONファイルに保存
      await _saveSearchConditionsToJson();

      return searchCondition;
    } catch (e) {
      rethrow; // エラーを再スロー
    }
  }

  // 検索条件を削除
  Future<void> deleteSearchCondition(String id) async {
    if (!_initialized) await initialize();

    try {
      _searchConditions.removeWhere((condition) => condition.id == id);

      // JSONファイルに保存
      await _saveSearchConditionsToJson();
    } catch (e) {
      rethrow; // エラーを再スロー
    }
  }

  // 検索条件を使用（最終使用日時を更新）
  Future<SearchCondition> useSearchCondition(String id) async {
    if (!_initialized) await initialize();

    try {
      final index = _searchConditions.indexWhere((c) => c.id == id);
      if (index == -1) {
        throw Exception('Search condition not found: $id');
      }

      final updatedCondition = _searchConditions[index].copyWith(
        lastUsedAt: DateTime.now(),
      );
      _searchConditions[index] = updatedCondition;

      // JSONファイルに保存
      await _saveSearchConditionsToJson();

      return updatedCondition;
    } catch (e) {
      rethrow; // エラーを再スロー
    }
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
          // エラーが発生しても処理を続行
        }
      }
    }

    // JSONファイルに保存
    await _saveBooksToJson();
  }
}
