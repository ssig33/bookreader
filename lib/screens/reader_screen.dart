import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/file_service.dart';
import '../utils/logger.dart';
import '../utils/page_layout_manager.dart';
import '../utils/keyboard_navigation_manager.dart';

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

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 見開き表示でも1ページだけ戻る（Shift+K/l用）
  void _goToPreviousSinglePage() {
    // 直接ページコントローラーを使用してページ移動
    _navigateToRelativePage(-1);
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 見開き表示でも1ページだけ進む（Shift+J/h用）
  void _goToNextSinglePage() {
    // 直接ページコントローラーを使用してページ移動
    _navigateToRelativePage(1);
  }

  // 相対的なページ移動を行う（見開き表示でも1ページだけ移動）
  void _navigateToRelativePage(int direction) {
    try {
      Logger.debug('相対的なページ移動: 方向=$direction', tag: 'ReaderScreen');
      Logger.debug('現在のページ: $_currentPage', tag: 'ReaderScreen');

      if (_layoutManager.useDoublePage) {
        // 見開き表示の場合
        final currentLayoutIndex = _currentPage;

        if (currentLayoutIndex >= _layoutManager.pageLayout.length) {
          Logger.error(
            'レイアウトインデックスが範囲外です: $_currentPage / ${_layoutManager.pageLayout.length}',
            tag: 'ReaderScreen',
          );
          return;
        }

        // 現在表示中の実際のページ番号を取得
        final currentPages = _layoutManager.getPagesForLayout(
          currentLayoutIndex,
        );
        if (currentPages.isEmpty) {
          Logger.error('現在のページ情報を取得できませんでした', tag: 'ReaderScreen');
          return;
        }

        Logger.debug('現在のページ構成: $currentPages', tag: 'ReaderScreen');

        // 移動先のページ構成を計算
        List<int> targetPages = [];
        if (direction > 0) {
          // 次のページへ
          if (currentPages.length == 1) {
            // 現在シングルページの場合、次の2ページを表示
            int nextPage = currentPages[0] + 1;
            if (nextPage < widget.book.totalPages) {
              // 次のページが存在する場合
              if (nextPage + 1 < widget.book.totalPages) {
                // 次の2ページを表示
                targetPages.add(nextPage);
                targetPages.add(nextPage + 1);
              } else {
                // 最後のページの場合は単独表示
                targetPages.add(nextPage);
              }
            }
          } else {
            // 現在ダブルページの場合、右ページを左ページにして新しい右ページを表示
            int rightPage = currentPages[1];
            int newRightPage = rightPage + 1;
            if (newRightPage < widget.book.totalPages) {
              // 次のページが存在する場合、右ページを左ページにして新しい右ページを表示
              targetPages.add(rightPage);
              targetPages.add(newRightPage);
            } else if (rightPage < widget.book.totalPages) {
              // 最後のページの場合は単独表示
              targetPages.add(rightPage);
            }
          }
        } else {
          // 前のページへ
          if (currentPages.length == 1) {
            // 現在シングルページの場合、前の2ページを表示
            int prevPage = currentPages[0] - 1;
            if (prevPage >= 0) {
              // 前のページが存在する場合
              if (prevPage - 1 >= 0) {
                // 前の2ページを表示
                targetPages.add(prevPage - 1);
                targetPages.add(prevPage);
              } else {
                // 最初のページの場合は単独表示
                targetPages.add(prevPage);
              }
            }
          } else {
            // 現在ダブルページの場合、左ページを右ページにして新しい左ページを表示
            int leftPage = currentPages[0];
            int newLeftPage = leftPage - 1;
            if (newLeftPage >= 0) {
              targetPages.add(newLeftPage);
              targetPages.add(leftPage);
            } else if (leftPage >= 0) {
              // 最初のページの場合は単独表示
              targetPages.add(leftPage);
            }
          }
        }

        if (targetPages.isEmpty) {
          Logger.warning('移動先のページがありません', tag: 'ReaderScreen');
          return;
        }

        Logger.debug('目標ページ構成: $targetPages', tag: 'ReaderScreen');

        // 目標ページ構成に対応するレイアウトインデックスを探す
        int targetIndex = _layoutManager.findLayoutIndexForPages(targetPages);

        // 既存のレイアウトに見つからない場合は、新しいレイアウトを作成
        if (targetIndex == -1) {
          Logger.debug(
            '既存のレイアウトに見つかりませんでした: $targetPages',
            tag: 'ReaderScreen',
          );

          if (targetPages.length == 1) {
            // 単一ページの場合
            final targetPage = targetPages[0];
            Logger.debug('単一ページを直接表示します: $targetPage', tag: 'ReaderScreen');

            // ページに直接ジャンプ
            _pageController.jumpToPage(targetPage);
            Logger.debug('ページ移動完了', tag: 'ReaderScreen');
            return;
          } else if (targetPages.length == 2) {
            // ダブルページの場合
            Logger.debug(
              'ダブルページを直接表示します: ${targetPages[0]}と${targetPages[1]}',
              tag: 'ReaderScreen',
            );

            // 新しいレイアウトを追加
            targetIndex = _layoutManager.addCustomLayout(targetPages);
            if (targetIndex == -1) {
              Logger.error('新しいレイアウトの作成に失敗しました', tag: 'ReaderScreen');
              return;
            }

            Logger.debug(
              '新しいレイアウトを作成しました: インデックス $targetIndex',
              tag: 'ReaderScreen',
            );
          } else {
            Logger.error('適切なレイアウトが見つかりませんでした', tag: 'ReaderScreen');
            return;
          }
        }

        // 見つかったインデックスに移動
        Logger.debug(
          '_pageController.jumpToPage($targetIndex) を呼び出します',
          tag: 'ReaderScreen',
        );
        _pageController.jumpToPage(targetIndex);
        Logger.debug('ページ移動完了', tag: 'ReaderScreen');
      } else {
        // 通常の単一ページ表示の場合は単純に移動
        final targetPage = _currentPage + direction;
        Logger.debug('目標ページ: $targetPage', tag: 'ReaderScreen');

        if (targetPage >= 0 && targetPage < widget.book.totalPages) {
          Logger.debug(
            '_pageController.jumpToPage($targetPage) を呼び出します',
            tag: 'ReaderScreen',
          );
          _pageController.jumpToPage(targetPage);
          Logger.debug('ページ移動完了', tag: 'ReaderScreen');
        } else {
          Logger.warning('目標ページが範囲外です: $targetPage', tag: 'ReaderScreen');
        }
      }
    } catch (e) {
      Logger.error('ページ移動中にエラーが発生しました', tag: 'ReaderScreen', error: e);
    }
  }

  Future<void> _updateLastReadPage(int page) async {
    if (page != widget.book.lastReadPage) {
      await _bookService.updateLastReadPage(widget.book.id, page);
    }
  }

  // ZIPファイルのページを表示するウィジェットを構築
  Widget _buildZipPageView(int layoutIndex) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: 16),
            Text(
              '画像を読み込み中...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_layoutManager.useDoublePage) {
      // 見開きページの場合
      final pages = _layoutManager.getPagesForLayout(layoutIndex);

      if (pages.isEmpty) {
        Logger.error('ページ情報を取得できませんでした: $layoutIndex', tag: 'ReaderScreen');
        return const Center(
          child: Text(
            'ページ情報の読み込みエラー',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        );
      }

      if (pages.length == 1) {
        // シングルページの場合
        return _buildSinglePageView(pages[0]);
      } else {
        // ダブルページの場合
        final leftPage = pages[0];
        final rightPage = pages[1];

        // 読み方向に応じてページの順序を決定
        final firstPage = _isRightToLeft ? rightPage : leftPage;
        final secondPage = _isRightToLeft ? leftPage : rightPage;

        return Container(
          color: Colors.black,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 余白なしでページを並べる
                _buildSinglePageView(firstPage),
                // 中央の境界線を削除し、ページをぴったりくっつける
                _buildSinglePageView(secondPage),
              ],
            ),
          ),
        );
      }
    } else {
      // 通常の単一ページ表示
      return _buildSinglePageView(layoutIndex);
    }
  }

  // 単一ページを表示するウィジェット
  Widget _buildSinglePageView(int pageIndex) {
    return FutureBuilder<Uint8List?>(
      future: _fileService.getZipImageData(widget.book.filePath, pageIndex),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          Logger.error(
            'ページ読み込みエラー: $pageIndex',
            tag: 'ReaderScreen',
            error: snapshot.error,
          );
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'ページ ${pageIndex + 1} の読み込みエラー',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        // 再読み込みを強制
                        _pageImages = List.filled(widget.book.totalPages, null);
                      });
                    },
                    child: const Text(
                      '再読み込み',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'ページ ${pageIndex + 1} のデータがありません',
                style: const TextStyle(fontSize: 16, color: Colors.orange),
              ),
            ),
          );
        }

        // 画像を表示（余白なしでぴったり表示）
        return Container(
          color: Colors.black,
          constraints:
              _layoutManager.useDoublePage
                  ? BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 2,
                  )
                  : null,
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            // 画像の境界線を削除
            gaplessPlayback: true,
            // キャッシュを有効化
            cacheWidth:
                _layoutManager.useDoublePage
                    ? (MediaQuery.of(context).size.width ~/ 2).toInt()
                    : null,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              Logger.error(
                'ページ画像表示エラー: $pageIndex',
                tag: 'ReaderScreen',
                error: error,
                stackTrace: stackTrace,
              );
              return Center(
                child: Text(
                  'ページ ${pageIndex + 1} の表示エラー',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // キーボードイベントを処理するメソッド
  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    // デバッグ情報を出力（詳細モードの場合）
    _keyboardManager.debugKeyEvent(event);

    // キーイベントを処理してアクションを取得
    final action = _keyboardManager.processKeyEvent(event);

    // アクションに応じた処理を実行
    switch (action) {
      case NavigationAction.nextPage:
        _goToNextPage();
        return KeyEventResult.handled;

      case NavigationAction.previousPage:
        _goToPreviousPage();
        return KeyEventResult.handled;

      case NavigationAction.nextSinglePage:
        _goToNextSinglePage();
        return KeyEventResult.handled;

      case NavigationAction.previousSinglePage:
        _goToPreviousSinglePage();
        return KeyEventResult.handled;

      case NavigationAction.debug:
        _debugPageController();
        return KeyEventResult.handled;

      case NavigationAction.none:
        return KeyEventResult.ignored;
    }
  }

  // ページコントローラーの状態をデバッグ出力
  void _debugPageController() {
    Logger.debug('--- PageController デバッグ情報 ---', tag: 'ReaderScreen');
    Logger.debug('現在のページ: $_currentPage', tag: 'ReaderScreen');
    Logger.debug(
      'PageController.page: ${_pageController.page}',
      tag: 'ReaderScreen',
    );
    Logger.debug(
      'PageController.position.pixels: ${_pageController.position.pixels}',
      tag: 'ReaderScreen',
    );
    Logger.debug(
      'PageController.position.maxScrollExtent: ${_pageController.position.maxScrollExtent}',
      tag: 'ReaderScreen',
    );
    Logger.debug(
      'PageController.position.viewportDimension: ${_pageController.position.viewportDimension}',
      tag: 'ReaderScreen',
    );
    Logger.debug(
      'PageController.position.haveDimensions: ${_pageController.position.haveDimensions}',
      tag: 'ReaderScreen',
    );
    Logger.debug('ページレイアウト: ${_layoutManager.pageLayout}', tag: 'ReaderScreen');
    Logger.debug('見開き表示: ${_layoutManager.useDoublePage}', tag: 'ReaderScreen');
    Logger.debug(
      '読み方向: ${_isRightToLeft ? "右から左" : "左から右"}',
      tag: 'ReaderScreen',
    );
    Logger.debug('--------------------------------', tag: 'ReaderScreen');
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
                itemCount:
                    _layoutManager.useDoublePage
                        ? _layoutManager.pageLayout.length
                        : widget.book.totalPages,
                itemBuilder: (context, index) {
                  if (widget.book.fileType == 'zip' ||
                      widget.book.fileType == 'cbz') {
                    return _buildZipPageView(index);
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
                            print('読み方向切り替えボタンが押されました');
                            print(
                              '現在の読み方向: ${_isRightToLeft ? "右から左" : "左から右"}',
                            );

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
                          // 左側のボタン
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
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

                          // 右側のボタン
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
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
