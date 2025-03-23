import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';
import '../../models/book.dart';
import '../../services/file_service.dart';

/// 画像の読み込みと処理を担当するクラス
class ReaderImageLoader {
  final FileService _fileService = FileService();
  final Book book;

  // メモリ内画像キャッシュ
  bool isLoading = true;

  // メモリ内画像キャッシュ
  final Map<int, Uint8List> _imageCache = {};
  final int _maxCacheSize = 10; // キャッシュするページ数
  final List<int> _cacheOrder = []; // LRUキャッシュの順序を管理
  // PDFレンダラー
  PdfImageRenderer? _pdfRenderer;

  // PDFレンダラーへのアクセスを制御するセマフォ
  bool _isPdfRendererBusy = false;

  ReaderImageLoader({required this.book});

  /// PDFレンダラーへのアクセスを同期化するためのヘルパーメソッド
  Future<T> _withPdfRenderer<T>(Future<T> Function() action) async {
    // 他の操作が進行中の場合は待機
    while (_isPdfRendererBusy) {
      debugPrint('PDF renderer is busy, waiting...');
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // ロックを取得
    _isPdfRendererBusy = true;
    debugPrint('Acquired PDF renderer lock');

    try {
      // アクションを実行
      return await action();
    } finally {
      // ロックを解放
      _isPdfRendererBusy = false;
      debugPrint('Released PDF renderer lock');
    }
  }

  /// ファイルタイプに応じて画像を読み込む
  Future<void> loadImages() async {
    if (book.fileType == 'zip' || book.fileType == 'cbz') {
      await loadZipImages();
    } else if (book.fileType == 'pdf') {
      await loadPdfImages();
    }
  }

  /// ZIPファイルから画像を読み込む
  /// ZIPファイルから画像を読み込む
  Future<void> loadZipImages() async {
    isLoading = true;

    try {
      // ZIPファイルから画像を抽出してキャッシュ
      final imagePaths = await _fileService.extractAndCacheZipImages(
        book.filePath,
      );

      if (imagePaths.isEmpty) {
        isLoading = false;
        return;
      }

      // 画像データを読み込む

      isLoading = false;
    } catch (e) {
      isLoading = false;
    }
  }

  /// PDFファイルから画像を読み込む
  Future<void> loadPdfImages() async {
    isLoading = true;
    debugPrint('Loading PDF file: ${book.filePath}');

    try {
      // PDFファイルを開く
      try {
        _pdfRenderer = PdfImageRenderer(path: book.filePath);
        debugPrint('PDF renderer created for file: ${book.filePath}');
      } catch (e) {
        debugPrint('ERROR: Failed to create PDF renderer: $e');
        isLoading = false;
        return;
      }

      try {
        await _pdfRenderer!.open();
        debugPrint('Successfully opened PDF file: ${book.filePath}');

        // ページ数を確認してログに出力
        try {
          final pageCount = await _pdfRenderer!.getPageCount();
          debugPrint(
            'PDF page count: $pageCount (book.totalPages: ${book.totalPages})',
          );

          // ページ数が異なる場合は警告
          if (pageCount != book.totalPages) {
            debugPrint(
              'WARNING: PDF page count ($pageCount) differs from book.totalPages (${book.totalPages})',
            );
          }
        } catch (e) {
          debugPrint('ERROR: Failed to get PDF page count: $e');
        }
      } catch (e) {
        debugPrint('ERROR: Failed to open PDF file: $e');
        // PDFレンダラーをクリア
        _pdfRenderer = null;
      }

      isLoading = false;
    } catch (e) {
      debugPrint('UNEXPECTED ERROR in PDF loading: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      isLoading = false;
    }
  }

  /// PDFページを画像として取得
  Future<Uint8List?> getPdfImageData(int pageIndex) async {
    if (_pdfRenderer == null) {
      debugPrint(
        'PDF Renderer is null for page $pageIndex, attempting to initialize',
      );
      try {
        await loadPdfImages();
      } catch (e) {
        debugPrint('Failed to initialize PDF renderer: $e');
      }

      if (_pdfRenderer == null) {
        debugPrint('PDF Renderer initialization failed for page $pageIndex');
        return null;
      }
    }

    // キャッシュにある場合はそれを返す（ロックを取得せずに高速に返す）
    if (_imageCache.containsKey(pageIndex)) {
      debugPrint('Using cached image for page $pageIndex');
      // キャッシュ順序を更新
      _cacheOrder.remove(pageIndex);
      _cacheOrder.add(pageIndex);
      return _imageCache[pageIndex];
    }

    // PDFレンダラーへのアクセスを同期化
    return await _withPdfRenderer<Uint8List?>(() async {
      bool pageOpened = false;
      dynamic pageSize;

      try {
        // ステップ1: ページを開く
        debugPrint('Opening PDF page $pageIndex');
        try {
          await _pdfRenderer!.openPage(pageIndex: pageIndex);
          pageOpened = true;
          debugPrint('Successfully opened PDF page $pageIndex');
        } catch (e) {
          debugPrint('ERROR: Failed to open PDF page $pageIndex: $e');
          return null;
        }

        // ステップ2: ページサイズを取得
        try {
          pageSize = await _pdfRenderer!.getPageSize(pageIndex: pageIndex);
          if (pageSize != null) {
            debugPrint(
              'Got page size for page $pageIndex: ${pageSize.width}x${pageSize.height}',
            );
          } else {
            debugPrint('ERROR: Page size is null for page $pageIndex');
            return null;
          }
        } catch (e) {
          debugPrint('ERROR: Failed to get page size for page $pageIndex: $e');
          return null;
        }

        // ステップ3: ページをレンダリング
        try {
          final image = await _pdfRenderer!.renderPage(
            pageIndex: pageIndex,
            x: 0,
            y: 0,
            width: pageSize.width.toInt(),
            height: pageSize.height.toInt(),
            scale: 1.0,
            background: Colors.white,
          );

          if (image != null) {
            debugPrint(
              'Successfully rendered PDF page $pageIndex (image size: ${image.length} bytes)',
            );

            // 画像をキャッシュに追加
            if (_cacheOrder.length >= _maxCacheSize && _cacheOrder.isNotEmpty) {
              final oldestPage = _cacheOrder.removeAt(0);
              _imageCache.remove(oldestPage);
              debugPrint('Removed page $oldestPage from cache (cache full)');
            }

            _imageCache[pageIndex] = image;
            _cacheOrder.add(pageIndex);
            debugPrint('Added page $pageIndex to cache');
          } else {
            debugPrint('WARNING: Rendered image is null for page $pageIndex');
          }
          return image;
        } catch (e) {
          debugPrint('ERROR: Failed to render PDF page $pageIndex: $e');
          return null;
        }
      } catch (e) {
        // 予期せぬエラーの場合
        debugPrint('UNEXPECTED ERROR in PDF rendering for page $pageIndex: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
        return null;
      } finally {
        // 例外が発生しても確実にページを閉じる
        if (pageOpened) {
          try {
            debugPrint('Closing PDF page $pageIndex');
            await _pdfRenderer!.closePage(pageIndex: pageIndex);
            debugPrint('Successfully closed PDF page $pageIndex');
          } catch (e) {
            debugPrint('ERROR: Failed to close PDF page $pageIndex: $e');
          }
        }
      }
    });
  }

  /// 画像をプリロードしてメモリキャッシュに保存
  Future<void> preloadPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= book.totalPages) {
      return; // 範囲外のページはスキップ
    }

    if (_imageCache.containsKey(pageIndex)) {
      // すでにキャッシュにある場合は、キャッシュ順序を更新
      _cacheOrder.remove(pageIndex);
      _cacheOrder.add(pageIndex);
      return;
    }

    try {
      Uint8List? imageData;

      if (book.fileType == 'zip' || book.fileType == 'cbz') {
        imageData = await _fileService.getZipImageData(
          book.filePath,
          pageIndex,
        );
      } else if (book.fileType == 'pdf') {
        imageData = await getPdfImageData(pageIndex);
      }

      if (imageData != null) {
        // キャッシュが最大サイズに達した場合、最も古いエントリを削除
        if (_cacheOrder.length >= _maxCacheSize && _cacheOrder.isNotEmpty) {
          final oldestPage = _cacheOrder.removeAt(0);
          _imageCache.remove(oldestPage);
        }

        // 新しい画像をキャッシュに追加
        _imageCache[pageIndex] = imageData;
        _cacheOrder.add(pageIndex);
      }
    } catch (e) {
      // エラー処理
    }
  }

  /// キャッシュから画像を取得（なければディスクから読み込む）
  Future<Uint8List?> getImageData(int pageIndex) async {
    // キャッシュにある場合はそれを返す
    if (_imageCache.containsKey(pageIndex)) {
      // キャッシュ順序を更新
      _cacheOrder.remove(pageIndex);
      _cacheOrder.add(pageIndex);
      return _imageCache[pageIndex];
    }

    // キャッシュにない場合はファイルタイプに応じて読み込む
    Uint8List? imageData;

    if (book.fileType == 'zip' || book.fileType == 'cbz') {
      imageData = await _fileService.getZipImageData(book.filePath, pageIndex);
    } else if (book.fileType == 'pdf') {
      imageData = await getPdfImageData(pageIndex);
    }

    if (imageData != null) {
      // キャッシュが最大サイズに達した場合、最も古いエントリを削除
      if (_cacheOrder.length >= _maxCacheSize && _cacheOrder.isNotEmpty) {
        final oldestPage = _cacheOrder.removeAt(0);
        _imageCache.remove(oldestPage);
      }

      // 新しい画像をキャッシュに追加
      _imageCache[pageIndex] = imageData;
      _cacheOrder.add(pageIndex);
    }

    return imageData;
  }

  /// 単一ページを表示するウィジェット
  Widget buildSinglePageView(
    int pageIndex,
    bool useDoublePage,
    BuildContext context,
  ) {
    return FutureBuilder<Uint8List?>(
      // メモリキャッシュから画像を取得（なければディスクから読み込む）
      future: getImageData(pageIndex),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'ページ ${pageIndex + 1} の読み込みエラー',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          );
        }

        // 画像を表示（余白なしでぴったり表示）
        return Container(
          color: Colors.black,
          constraints:
              useDoublePage
                  ? BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 2,
                  )
                  : null,
          child:
              useDoublePage
                  // 見開きモードではアニメーションを使用しない
                  ? Image.memory(
                    snapshot.data!,
                    key: ValueKey<int>(pageIndex),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  )
                  // 通常モードではアニメーションを維持
                  : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Image.memory(
                      snapshot.data!,
                      key: ValueKey<int>(pageIndex),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
        );
      },
    );
  }

  /// 画像のアスペクト比を取得
  Future<double?> getImageAspectRatio(int pageIndex) async {
    // メモリキャッシュから画像を取得（なければディスクから読み込む）
    final imageData = await getImageData(pageIndex);
    if (imageData != null) {
      return await _fileService.getImageAspectRatio(imageData);
    }
    return null;
  }
}
