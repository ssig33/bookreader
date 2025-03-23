import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import '../models/book.dart';
import '../models/search_condition.dart';
import '../services/book_service.dart';
import '../services/platform_service.dart';
import '../widgets/book_list_item.dart';
import 'storage_info_screen.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BookService _bookService = BookService();
  final PlatformService _platformService = PlatformService();
  List<Book> _books = [];
  final List<String> _selectedTags = [];
  List<String> _allTags = [];
  bool _isDragging = false;

  // 検索関連の状態
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<SearchCondition> _savedSearchConditions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _bookService.initialize();
      _loadBooks();
      _loadSavedSearchConditions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('初期化エラー: ${e.toString()}')));
      }
    }
  }

  void _loadBooks() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _books = _bookService.getBooksByTags(_selectedTags);
      } else {
        _books = _bookService.searchBooks(
          _searchQuery,
          selectedTags: _selectedTags,
        );
      }
      // ファイル名で降順ソート
      _books = _bookService.sortBooksByTitleDesc(_books);
      _updateAllTags();
    });
  }

  void _loadSavedSearchConditions() {
    setState(() {
      _savedSearchConditions = _bookService.getSearchConditionsByLastUsed();
    });
  }

  void _updateAllTags() {
    final Set<String> tags = {};
    for (final book in _bookService.getAllBooks()) {
      tags.addAll(book.tags);
    }
    _allTags = tags.toList()..sort();
  }

  // 検索を実行
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _loadBooks();
    });
  }

  // 検索条件を保存
  Future<void> _saveSearchCondition(String name, String query) async {
    try {
      await _bookService.saveSearchCondition(name, query);
      _loadSavedSearchConditions();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('検索条件「$name」を保存しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存エラー: ${e.toString()}')));
      }
    }
  }

  // 保存した検索条件を使用
  Future<void> _useSearchCondition(SearchCondition condition) async {
    try {
      await _bookService.useSearchCondition(condition.id);
      _searchController.text = condition.query;
      _performSearch(condition.query);
      _loadSavedSearchConditions(); // 使用順を更新するため再読み込み
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    }
  }

  // 保存した検索条件を削除
  Future<void> _deleteSearchCondition(SearchCondition condition) async {
    try {
      await _bookService.deleteSearchCondition(condition.id);
      _loadSavedSearchConditions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索条件「${condition.name}」を削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除エラー: ${e.toString()}')));
      }
    }
  }

  // 検索条件保存ダイアログを表示
  void _showSaveSearchDialog() {
    // デフォルトの名前として検索クエリを使用
    final nameController = TextEditingController(text: _searchQuery);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('検索条件を保存'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    hintText: '検索条件の名前を入力してください',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Text('検索条件: $_searchQuery'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    _saveSearchCondition(name, _searchQuery);
                  }
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }

  // 保存した検索条件一覧ダイアログを表示
  void _showSavedSearchesDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('保存した検索条件'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  _savedSearchConditions.isEmpty
                      ? const Center(child: Text('保存された検索条件はありません'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _savedSearchConditions.length,
                        itemBuilder: (context, index) {
                          final condition = _savedSearchConditions[index];
                          return ListTile(
                            title: Text(condition.name),
                            subtitle: Text(condition.query),
                            onTap: () {
                              Navigator.pop(context);
                              _useSearchCondition(condition);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteSearchCondition(condition);
                              },
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
    );
  }

  Future<void> _pickAndAddBook() async {
    try {
      // プラットフォームに応じて許可される拡張子を決定
      List<String> allowedExtensions = ['zip', 'cbz'];

      // PDFをサポートしているプラットフォームの場合のみPDFを許可
      if (_platformService.isPdfSupported()) {
        allowedExtensions.add('pdf');
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          await _bookService.addBook(path);
          _loadBooks();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('ファイルを追加しました')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) return;

    int successCount = 0;
    List<String> errors = [];

    for (final file in files) {
      try {
        final path = file.path;
        final extension = path.split('.').last.toLowerCase();

        // プラットフォームに応じて許可される拡張子を決定
        List<String> allowedExtensions = ['zip', 'cbz'];
        if (_platformService.isPdfSupported()) {
          allowedExtensions.add('pdf');
        }

        if (allowedExtensions.contains(extension)) {
          await _bookService.addBook(path);
          successCount++;
        } else if (extension == 'pdf' && !_platformService.isPdfSupported()) {
          // PDFファイルがサポートされていないプラットフォームの場合
          errors.add(
            '${file.name}: このプラットフォーム(${_platformService.getPlatformName()})ではPDFはサポートされていません',
          );
        } else {
          errors.add('${file.name}: サポートされていないファイル形式です');
        }
      } catch (e) {
        errors.add('${file.name}: ${e.toString()}');
      }
    }

    _loadBooks();

    if (mounted) {
      if (successCount > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$successCount 件のファイルを追加しました')));
      }

      if (errors.isNotEmpty) {
        // エラーがある場合は別途表示
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('エラー: ${errors.join(', ')}'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  void _deleteBook(String id) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('削除の確認'),
            content: const Text('このファイルを削除してもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  // 非同期処理の前にcontextを保存
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  try {
                    await _bookService.deleteBook(id);
                    _loadBooks();
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('ファイルを削除しました')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('削除エラー: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('削除'),
              ),
            ],
          ),
    );
  }

  void _renameBook(String id, String currentTitle) {
    final textController = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('名前変更'),
            content: TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                hintText: '新しいタイトルを入力してください',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  final newTitle = textController.text.trim();
                  if (newTitle.isNotEmpty) {
                    _bookService.renameBook(id, newTitle);
                    _loadBooks();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('名前を変更しました')));
                  }
                  Navigator.pop(context);
                },
                child: const Text('変更'),
              ),
            ],
          ),
    );
  }

  void _addTag(String bookId, String tag) {
    _bookService.addTag(bookId, tag);
    _loadBooks();
  }

  void _toggleTagFilter(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
      _loadBooks();
    });
  }

  void _clearTagFilters() {
    setState(() {
      _selectedTags.clear();
      _loadBooks();
    });
  }

  void _openBook(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReaderScreen(book: book)),
    ).then((_) => _loadBooks()); // 戻ってきたら本のリストを更新
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ファイル名またはタグで検索...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.black),
                  autofocus: true,
                  onChanged: _performSearch,
                )
                : const Text('ブックリーダー'),
        actions: [
          // 検索ボタン
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                  _loadBooks();
                } else {
                  _isSearching = true;
                }
              });
            },
            tooltip: _isSearching ? '検索をクリア' : '検索',
          ),
          // 検索条件保存ボタン（検索中のみ表示）
          if (_isSearching && _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _showSaveSearchDialog,
              tooltip: '検索条件を保存',
            ),
          // 保存した検索条件ボタン
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showSavedSearchesDialog,
            tooltip: '保存した検索条件',
          ),
          // タグフィルターボタン
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'タグでフィルター',
          ),
          // ストレージ情報ボタン
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StorageInfoScreen(),
                ),
              ).then((_) => _loadBooks()); // 戻ってきたら本のリストを更新
            },
            tooltip: 'ストレージ情報',
          ),
        ],
      ),
      body: DropTarget(
        onDragDone: (detail) {
          _handleDroppedFiles(detail.files);
        },
        onDragEntered: (detail) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (detail) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Stack(
          children: [
            _books.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return BookListItem(
                      book: book,
                      onTap: () => _openBook(book),
                      onRename: () => _renameBook(book.id, book.title),
                      onDelete: () => _deleteBook(book.id),
                      onAddTag: (tag) => _addTag(book.id, tag),
                    );
                  },
                ),
            if (_isDragging)
              Container(
                color: Colors.blue.withAlpha(51),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.file_download, size: 48, color: Colors.blue),
                        SizedBox(height: 16),
                        Text(
                          'ファイルをドロップしてライブラリに追加',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('対応形式: ZIP, CBZ, PDF'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndAddBook,
        tooltip: 'ファイルを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _selectedTags.isEmpty ? 'ファイルがありません' : 'フィルター条件に一致するファイルがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          if (_selectedTags.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list_off),
              label: const Text('フィルターをクリア'),
              onPressed: _clearTagFilters,
            )
          else
            Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('ファイルを追加'),
                  onPressed: _pickAndAddBook,
                ),
                const SizedBox(height: 16),
                Text(
                  'または、ファイルをここにドラッグ＆ドロップ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  '対応形式: ZIP, CBZ, PDF',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('タグでフィルター'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  _allTags.isEmpty
                      ? const Center(child: Text('タグがありません'))
                      : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _allTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (selected) {
                                  Navigator.pop(context);
                                  _toggleTagFilter(tag);
                                },
                              );
                            }).toList(),
                      ),
            ),
            actions: [
              if (_selectedTags.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearTagFilters();
                  },
                  child: const Text('フィルターをクリア'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
    );
  }
}
