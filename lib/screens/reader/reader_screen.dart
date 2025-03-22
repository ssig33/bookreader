import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import 'reader_image_loader.dart';
import 'reader_page_layout.dart';
import 'reader_navigation.dart';
import 'reader_keyboard_handler.dart';

/// 本を読むためのスクリーン
class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

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

  // キーボードフォーカス用
  final FocusNode _focusNode = FocusNode();

  // 各コンポーネント
  ReaderImageLoader? _imageLoader;
  ReaderPageLayout? _pageLayout;
  ReaderNavigation? _navigation;
  ReaderKeyboardHandler? _keyboardHandler;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _isRightToLeft = widget.book.isRightToLeft; // 初期値を設定
    _pageController = PageController(initialPage: _currentPage);

    // ファイルタイプに応じて適切なローダーを初期化
    if (widget.book.fileType == 'zip' || widget.book.fileType == 'cbz') {
      _loadZipFile();
    }
    // PDFファイルタイプは現在サポートされていません

    // フォーカスノードにフォーカスを当てる
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  // ZIPファイルを読み込む
  Future<void> _loadZipFile() async {
    setState(() {
      // ローディング状態を設定
    });

    try {
      // ZIPローダーを初期化
      _imageLoader = ReaderImageLoader(book: widget.book);

      // 画像を読み込む
      await _imageLoader!.loadZipImages();

      // ページレイアウトを初期化
      _pageLayout = ReaderPageLayout(
        book: widget.book,
        imageLoader: _imageLoader!,
      );

      // 画像のアスペクト比を分析して見開きレイアウトを決定
      if (!mounted) return;
      await _pageLayout!.determinePageLayout(context);

      // ナビゲーションを初期化
      _navigation = ReaderNavigation(
        book: widget.book,
        pageController: _pageController,
        useDoublePage: _pageLayout!.useDoublePage,
        pageLayout: _pageLayout!,
      );

      // キーボードハンドラーを初期化
      _keyboardHandler = ReaderKeyboardHandler(
        goToPreviousPage: _goToPreviousPage,
        goToNextPage: _goToNextPage,
        goToPreviousSinglePage: _goToPreviousSinglePage,
        goToNextSinglePage: _goToNextSinglePage,
        debugPageController: _debugPageController,
      );

      setState(() {
        // 状態を更新
      });
    } catch (e) {
      setState(() {
        // エラー状態を設定
      });
    }
  }

  // PDFファイルの読み込みは現在サポートされていません

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _goToPreviousPage() {
    _navigation?.goToPreviousPage();
  }

  // 見開き表示でも1ページだけ戻る（Shift+K/l用）
  void _goToPreviousSinglePage() {
    _navigation?.navigateToRelativePage(-1, _currentPage, _isRightToLeft);
  }

  void _goToNextPage() {
    _navigation?.goToNextPage();
  }

  // 見開き表示でも1ページだけ進む（Shift+J/h用）
  void _goToNextSinglePage() {
    _navigation?.navigateToRelativePage(1, _currentPage, _isRightToLeft);
  }

  // ページコントローラーの状態をデバッグ出力
  void _debugPageController() {
    // デバッグ情報
  }

  /// ページ入力ダイアログを表示
  void _showPageInputDialog() {
    // 現在のページ番号を初期値として設定
    final TextEditingController controller = TextEditingController(
      text: '${_currentPage + 1}',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ページ番号を入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'ページ番号',
                  hintText: '1 - ${widget.book.totalPages}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '全${widget.book.totalPages}ページ中',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                // 入力されたページ番号を取得
                final pageText = controller.text.trim();
                int? pageNumber = int.tryParse(pageText);

                if (pageNumber != null) {
                  // 1から始まるページ番号を0から始まるインデックスに変換
                  pageNumber = pageNumber - 1;

                  // 有効なページ番号かチェック
                  if (pageNumber >= 0 && pageNumber < widget.book.totalPages) {
                    // ダイアログを閉じる
                    Navigator.pop(context);

                    // 指定されたページに移動
                    _navigation?.jumpToPage(pageNumber, _isRightToLeft);
                  } else {
                    // 無効なページ番号の場合はエラーメッセージを表示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '有効なページ番号を入力してください (1-${widget.book.totalPages})',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  // 数値以外が入力された場合はエラーメッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('数値を入力してください'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('移動'),
            ),
          ],
        );
      },
    );
  }

  /// 隣接するページをプリロードする
  void _preloadAdjacentPages(int currentPage) {
    // ファイルタイプに応じて適切なローダーを使用
    final fileType = widget.book.fileType;

    // ZIPファイルの場合
    if ((fileType == 'zip' || fileType == 'cbz') && _imageLoader != null) {
      // 読み方向に応じてプリロードするページを決定
      final pagesToPreload = <int>[];

      // 見開きページの場合は、現在のページと次のページ、およびその前後をプリロード
      if (_pageLayout != null && _pageLayout!.useDoublePage) {
        // 現在のページと次のページ
        pagesToPreload.add(currentPage);
        pagesToPreload.add(currentPage + 1);

        // 前後のページもプリロード
        pagesToPreload.add(currentPage - 1);
        pagesToPreload.add(currentPage - 2);
        pagesToPreload.add(currentPage + 2);
        pagesToPreload.add(currentPage + 3);
      } else {
        // 単一ページの場合は前後のページをプリロード
        pagesToPreload.addAll([
          currentPage - 2,
          currentPage - 1,
          currentPage,
          currentPage + 1,
          currentPage + 2,
        ]);
      }

      // 重複を削除し、範囲内のページのみをプリロード
      final uniquePages =
          pagesToPreload.toSet().toList()
            ..removeWhere((page) => page < 0 || page >= widget.book.totalPages);

      // 各ページをプリロード
      for (final page in uniquePages) {
        _imageLoader!.preloadPage(page);
      }
    }
    // PDFファイルの場合は現在サポートされていません
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent:
            (node, event) =>
                _keyboardHandler?.handleKeyEvent(node, event) ??
                KeyEventResult.ignored,
        child: GestureDetector(
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
                  _navigation?.updateLastReadPage(page);

                  // 隣接ページをプリロード
                  _preloadAdjacentPages(page);
                },
                itemCount: widget.book.totalPages,
                itemBuilder: (context, index) {
                  if (widget.book.fileType == 'zip' ||
                      widget.book.fileType == 'cbz') {
                    if (_pageLayout != null) {
                      return _pageLayout!.buildZipPageView(
                        index,
                        _isRightToLeft,
                        context,
                      );
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  } else {
                    // PDFやその他のファイルタイプの場合は仮表示
                    return Container(
                      color: Colors.white,
                      child: Center(
                        child: Text(
                          'ページ ${index + 1}',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }
                },
              ),

              // 上部コントロール（タップで表示/非表示）
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black.withAlpha(179),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                      left: 8,
                      right: 8,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
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
                            try {
                              // サービスで本の読み方向を切り替え
                              final updatedBook = await _bookService
                                  .toggleReadingDirection(widget.book.id);

                              // 現在のページを保存
                              final currentPage = _currentPage;

                              // ローカル状態と PageController を更新
                              setState(() {
                                // ローカル状態を更新
                                _isRightToLeft = updatedBook.isRightToLeft;

                                // PageControllerを再作成
                                _pageController.dispose();
                                _pageController = PageController(
                                  initialPage: currentPage,
                                );

                                // ナビゲーションを更新
                                _navigation = ReaderNavigation(
                                  book: widget.book,
                                  pageController: _pageController,
                                  useDoublePage: _pageLayout!.useDoublePage,
                                  pageLayout: _pageLayout!,
                                );
                              });
                            } catch (e) {
                              // エラー処理
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue.withAlpha(77),
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
                          color: Colors.black.withAlpha(179),
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
                          // 左側のボタン
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(128),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_left,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed:
                                  _isRightToLeft
                                      ? _goToNextPage
                                      : _goToPreviousPage,
                              tooltip: _isRightToLeft ? '次のページ' : '前のページ',
                            ),
                          ),

                          // ページ番号表示（タップでページ入力ダイアログを表示）
                          GestureDetector(
                            onTap: _showPageInputDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(179),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.book.totalPages > 0
                                        ? 'ページ ${_currentPage + 1} / ${widget.book.totalPages}'
                                        : 'ページ ${_currentPage + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 右側のボタン
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(128),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_right,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed:
                                  _isRightToLeft
                                      ? _goToPreviousPage
                                      : _goToNextPage,
                              tooltip: _isRightToLeft ? '前のページ' : '次のページ',
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
      ),
    );
  }
}
