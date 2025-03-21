import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../widgets/book_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BookService _bookService = BookService();
  List<Book> _books = [];
  List<String> _selectedTags = [];
  List<String> _allTags = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    setState(() {
      _books = _bookService.getBooksByTags(_selectedTags);
      _updateAllTags();
    });
  }

  void _updateAllTags() {
    final Set<String> tags = {};
    for (final book in _bookService.getAllBooks()) {
      tags.addAll(book.tags);
    }
    _allTags = tags.toList()..sort();
  }

  Future<void> _pickAndAddBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'cbz', 'pdf'],
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
                onPressed: () {
                  Navigator.pop(context);
                  _bookService.deleteBook(id);
                  _loadBooks();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('ファイルを削除しました')));
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
    // TODO: 本を開く画面に遷移する
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${book.title}を開きます（未実装）')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ブックリーダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'タグでフィルター',
          ),
        ],
      ),
      body:
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
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('ファイルを追加'),
              onPressed: _pickAndAddBook,
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
