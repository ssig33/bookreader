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
  // 本の読み方向を管理するローカル状態
  late bool _isRightToLeft;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _isRightToLeft = widget.book.isRightToLeft; // 初期値を設定
    _pageController = PageController(initialPage: _currentPage);
    print('初期化: 読み方向=${_isRightToLeft ? "右から左" : "左から右"}');
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
              reverse: _isRightToLeft, // 右から左への読み方向に対応
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.book.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.book.totalPages > 0)
                              Text(
                                'ページ: ${_currentPage + 1} / ${widget.book.totalPages}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(
                          _isRightToLeft
                              ? Icons.format_textdirection_r_to_l
                              : Icons.format_textdirection_l_to_r,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isRightToLeft ? '右→左' : '左→右',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          print('読み方向切り替えボタンが押されました');
                          print('現在の読み方向: ${_isRightToLeft ? "右から左" : "左から右"}');

                          try {
                            // サービスで本の読み方向を切り替え
                            final updatedBook = await _bookService
                                .toggleReadingDirection(widget.book.id);

                            print(
                              '更新後の読み方向: ${updatedBook.isRightToLeft ? "右から左" : "左から右"}',
                            );

                            // 現在のページを保存
                            final currentPage = _currentPage;
                            print('現在のページ: $currentPage');

                            // ローカル状態と PageController を更新
                            setState(() {
                              print('setState呼び出し');
                              // ローカル状態を更新
                              _isRightToLeft = updatedBook.isRightToLeft;
                              print(
                                'ローカル状態を更新: _isRightToLeft=$_isRightToLeft',
                              );

                              // PageControllerを再作成
                              _pageController.dispose();
                              _pageController = PageController(
                                initialPage: currentPage,
                              );
                              print('PageController再作成完了');
                            });
                          } catch (e) {
                            print('エラー発生: $e');
                          }
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
                        _isRightToLeft ? '← 右から左へめくる →' : '← 左から右へめくる →',
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
                              _isRightToLeft
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed:
                                _isRightToLeft
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
                            widget.book.totalPages > 0
                                ? 'ページ ${_currentPage + 1} / ${widget.book.totalPages}'
                                : 'ページ ${_currentPage + 1}',
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
                              _isRightToLeft
                                  ? Icons.keyboard_arrow_left
                                  : Icons.keyboard_arrow_right,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed:
                                _isRightToLeft
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
