import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final BookService _bookService = BookService();
  bool _showControls = false;
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _updateLastReadPage(int page) async {
    if (page != widget.book.lastReadPage) {
      await _bookService.updateLastReadPage(widget.book.id, page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ページビュー（ここに実際の本の内容を表示）
            PageView.builder(
              controller: _pageController,
              reverse: widget.book.isRightToLeft, // 右から左への読み方向に対応
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
                _updateLastReadPage(page);
              },
              itemBuilder: (context, index) {
                // ここでは仮のページ表示
                return Container(
                  color: Colors.white,
                  child: Center(
                    child: Text(
                      'ページ ${index + 1}',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),

            // 上部コントロール（タップで表示/非表示）
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        tooltip: '戻る',
                      ),
                      Expanded(
                        child: Text(
                          widget.book.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(
                          widget.book.isRightToLeft
                              ? Icons.format_textdirection_r_to_l
                              : Icons.format_textdirection_l_to_r,
                          color: Colors.white,
                        ),
                        label: Text(
                          widget.book.isRightToLeft ? '右→左' : '左→右',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          final updatedBook = await _bookService
                              .toggleReadingDirection(widget.book.id);
                          // 現在のページを保存
                          final currentPage = _currentPage;

                          // PageControllerを再作成して向きを更新
                          setState(() {
                            _pageController.dispose();
                            _pageController = PageController(
                              initialPage: currentPage,
                            );
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 左右のページめくりコントロール
            if (_showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ページめくり方向の説明
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.book.isRightToLeft
                            ? '← 右から左へめくる →'
                            : '← 左から右へめくる →',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 前のページボタン
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: IconButton(
                            icon: Icon(
                              widget.book.isRightToLeft
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed:
                                widget.book.isRightToLeft
                                    ? _goToNextPage
                                    : _goToPreviousPage,
                            tooltip: '前のページ',
                          ),
                        ),

                        // ページ番号表示
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'ページ ${_currentPage + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),

                        // 次のページボタン
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: IconButton(
                            icon: Icon(
                              widget.book.isRightToLeft
                                  ? Icons.keyboard_arrow_left
                                  : Icons.keyboard_arrow_right,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed:
                                widget.book.isRightToLeft
                                    ? _goToPreviousPage
                                    : _goToNextPage,
                            tooltip: '次のページ',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
