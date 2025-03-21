import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/file_service.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final BookService _bookService = BookService();
  final FileService _fileService = FileService();
  bool _showControls = false;
  int _currentPage = 0;
  late PageController _pageController;
  // 本の読み方向を管理するローカル状態
  late bool _isRightToLeft;

  // ページ画像のキャッシュ
  List<Uint8List?> _pageImages = [];
  bool _isLoading = true;
  bool _useDoublePage = false;
  List<int> _pageLayout = []; // シングルページまたはダブルページのレイアウト

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _isRightToLeft = widget.book.isRightToLeft; // 初期値を設定
    _pageController = PageController(initialPage: _currentPage);
    print('初期化: 読み方向=${_isRightToLeft ? "右から左" : "左から右"}');

    // ZIPファイルの場合は画像を読み込む
    if (widget.book.fileType == 'zip' || widget.book.fileType == 'cbz') {
      _loadZipImages();
    }
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
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 画像データを読み込む
      _pageImages = List.filled(imagePaths.length, null);

      // 画像のアスペクト比を分析して見開きレイアウトを決定
      await _determinePageLayout();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('ZIP画像読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 画像のアスペクト比を分析して見開きレイアウトを決定
  Future<void> _determinePageLayout() async {
    final totalPages = widget.book.totalPages;
    _pageLayout = List.generate(totalPages, (index) => index);

    // 画面のアスペクト比を取得
    final screenSize = MediaQuery.of(context).size;
    final screenAspect = screenSize.width / screenSize.height;

    // 見開き表示が可能かどうかを判断
    if (screenAspect >= 1.2) {
      // 横長の画面の場合
      List<double?> aspectRatios = [];

      // 最初の10ページ（または全ページ）のアスペクト比を取得
      final pagesToCheck = totalPages > 10 ? 10 : totalPages;
      for (int i = 0; i < pagesToCheck; i++) {
        final imageData = await _fileService.getZipImageData(
          widget.book.filePath,
          i,
        );
        if (imageData != null) {
          final aspect = await _fileService.getImageAspectRatio(imageData);
          aspectRatios.add(aspect);
        }
      }

      // アスペクト比の平均を計算
      double avgAspect = 0;
      int validCount = 0;
      for (final aspect in aspectRatios) {
        if (aspect != null) {
          avgAspect += aspect;
          validCount++;
        }
      }

      if (validCount > 0) {
        avgAspect /= validCount;

        // 平均アスペクト比が縦長（0.8未満）の場合、見開き表示を有効にする
        if (avgAspect < 0.8) {
          _useDoublePage = true;

          // 見開きページレイアウトを作成
          _createDoublePageLayout(totalPages);
        }
      }
    }
  }

  // 見開きページレイアウトを作成
  void _createDoublePageLayout(int totalPages) {
    _pageLayout = [];

    // 最初のページは単独表示
    _pageLayout.add(0);

    // 残りのページを2ページずつグループ化
    for (int i = 1; i < totalPages; i += 2) {
      if (i + 1 < totalPages) {
        // 2ページを組み合わせる
        _pageLayout.add((i << 16) | (i + 1));
      } else {
        // 最後の1ページが余る場合は単独表示
        _pageLayout.add(i);
      }
    }
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

  // ZIPファイルのページを表示するウィジェットを構築
  Widget _buildZipPageView(int layoutIndex) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_useDoublePage) {
      // 見開きページの場合
      final pageData = _pageLayout[layoutIndex];

      if (pageData < 65536) {
        // シングルページの場合
        return _buildSinglePageView(pageData);
      } else {
        // ダブルページの場合
        final leftPage = pageData >> 16;
        final rightPage = pageData & 0xFFFF;

        return Row(
          children: [
            Expanded(child: _buildSinglePageView(leftPage)),
            Expanded(child: _buildSinglePageView(rightPage)),
          ],
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            color: Colors.white,
            child: Center(
              child: Text(
                'ページ ${pageIndex + 1} の読み込みエラー',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          );
        }

        // 画像を表示
        return Container(
          color: Colors.black,
          child: Center(
            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
          ),
        );
      },
    );
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
              itemCount:
                  _useDoublePage ? _pageLayout.length : widget.book.totalPages,
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
