import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/file_service.dart';
import '../utils/logger.dart';
import '../utils/page_layout_manager.dart';
import '../utils/keyboard_navigation_manager.dart';
import '../utils/reader_navigation_manager.dart';
import '../widgets/reader_page_view.dart';
import '../widgets/reader_controls.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // サービス
  final BookService _bookService = BookService();
  final FileService _fileService = FileService();

  // ユーティリティマネージャー
  late PageLayoutManager _layoutManager;
  final KeyboardNavigationManager _keyboardManager =
      KeyboardNavigationManager();
  late ReaderNavigationManager _navigationManager;

  // UI状態
  bool _showControls = false;
  bool _isLoading = true;

  // ページ関連
  int _currentPage = 0;
  late PageController _pageController;
  late bool _isRightToLeft;

  // キーボードフォーカス用
  final FocusNode _focusNode = FocusNode();

  // ページ画像のキャッシュ
  List<Uint8List?> _pageImages = [];

  @override
  void initState() {
    super.initState();

    // 初期設定
    _currentPage = widget.book.lastReadPage;
    _isRightToLeft = widget.book.isRightToLeft;
    _pageController = PageController(initialPage: _currentPage);

    // ページレイアウトマネージャーの初期化
    _layoutManager = PageLayoutManager(
      _fileService,
      widget.book.filePath,
      widget.book.totalPages,
    );

    // ナビゲーションマネージャーの初期化
    _navigationManager = ReaderNavigationManager(
      book: widget.book,
      layoutManager: _layoutManager,
      pageController: _pageController,
      currentPage: _currentPage,
    );

    Logger.debug(
      '初期化: 読み方向=${_isRightToLeft ? "右から左" : "左から右"}',
      tag: 'ReaderScreen',
    );

    // ZIPファイルの場合は画像を読み込む
    if (widget.book.fileType == 'zip' || widget.book.fileType == 'cbz') {
      _loadZipImages();
    }

    // フォーカスノードにフォーカスを当てる
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  // ZIPファイルから画像を読み込む
  Future<void> _loadZipImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ZIPファイルから画像を抽出してキャッシュ
      final imagePaths = await _fileService.extractAndCacheZipImages(
        widget.book.filePath,
      );

      if (imagePaths.isEmpty) {
        Logger.warning('ZIPファイルに画像が見つかりませんでした', tag: 'ReaderScreen');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 画像データを読み込む
      _pageImages = List.filled(imagePaths.length, null);

      // 画像のアスペクト比を分析して見開きレイアウトを決定
      await _layoutManager.determinePageLayout(context);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('ZIP画像読み込みエラー', tag: 'ReaderScreen', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  // 読み方向を切り替える
  Future<void> _toggleReadingDirection() async {
    try {
      // サービスで本の読み方向を切り替え
      final updatedBook = await _bookService.toggleReadingDirection(
        widget.book.id,
      );

      // 現在のページを保存
      final currentPage = _currentPage;

      // 状態を更新
      setState(() {
        _isRightToLeft = updatedBook.isRightToLeft;

        // PageControllerを再作成
        _pageController.dispose();
        _pageController = PageController(initialPage: currentPage);

        // ナビゲーションマネージャーを更新
        _navigationManager = ReaderNavigationManager(
          book: updatedBook,
          layoutManager: _layoutManager,
          pageController: _pageController,
          currentPage: currentPage,
        );
      });

      Logger.info(
        '読み方向を切り替えました: ${_isRightToLeft ? "右から左" : "左から右"}',
        tag: 'ReaderScreen',
      );
    } catch (e) {
      Logger.error('読み方向切り替えエラー', tag: 'ReaderScreen', error: e);
    }
  }

  Future<void> _updateLastReadPage(int page) async {
    if (page != widget.book.lastReadPage) {
      try {
        await _bookService.updateLastReadPage(widget.book.id, page);

        // ナビゲーションマネージャーの現在のページを更新
        _navigationManager.currentPage = page;

        Logger.debug('最後に読んだページを更新: $page', tag: 'ReaderScreen');
      } catch (e) {
        Logger.error('最後に読んだページの更新エラー', tag: 'ReaderScreen', error: e);
      }
    }
  }

  // ページビューウィジェットはReaderPageViewクラスに移動しました

  // キーボードイベントを処理するメソッド
  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    // デバッグ情報を出力（詳細モードの場合）
    _keyboardManager.debugKeyEvent(event);

    // キーイベントを処理してアクションを取得
    final action = _keyboardManager.processKeyEvent(event);

    // アクションに応じた処理を実行
    switch (action) {
      case NavigationAction.nextPage:
        _navigationManager.goToNextPage();
        return KeyEventResult.handled;

      case NavigationAction.previousPage:
        _navigationManager.goToPreviousPage();
        return KeyEventResult.handled;

      case NavigationAction.nextSinglePage:
        _navigationManager.goToNextSinglePage();
        return KeyEventResult.handled;

      case NavigationAction.previousSinglePage:
        _navigationManager.goToPreviousSinglePage();
        return KeyEventResult.handled;

      case NavigationAction.debug:
        _navigationManager.debugPageController();
        return KeyEventResult.handled;

      case NavigationAction.none:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _handleKeyEvent,
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // ページビュー
              ReaderPageView(
                book: widget.book,
                fileService: _fileService,
                layoutManager: _layoutManager,
                isRightToLeft: _isRightToLeft,
                isLoading: _isLoading,
                pageImages: _pageImages,
                onReload: () {
                  setState(() {
                    // 再読み込みを強制
                    _pageImages = List.filled(widget.book.totalPages, null);
                    _loadZipImages();
                  });
                },
              ),

              // コントロール
              ReaderControls(
                book: widget.book,
                currentPage: _currentPage,
                isRightToLeft: _isRightToLeft,
                showControls: _showControls,
                onBack: () {
                  Navigator.pop(context);
                },
                onToggleReadingDirection: _toggleReadingDirection,
                onPreviousPage: _navigationManager.goToPreviousPage,
                onNextPage: _navigationManager.goToNextPage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
