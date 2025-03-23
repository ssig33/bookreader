import 'dart:typed_data';
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

  ReaderImageLoader({required this.book});

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

    try {
      // PDFファイルを開く
      _pdfRenderer = PdfImageRenderer(path: book.filePath);
      await _pdfRenderer!.open();

      isLoading = false;
    } catch (e) {
      isLoading = false;
    }
  }

  /// PDFページを画像として取得
  Future<Uint8List?> getPdfImageData(int pageIndex) async {
    if (_pdfRenderer == null) {
      await loadPdfImages();
      if (_pdfRenderer == null) return null;
    }

    try {
      // ページを開く
      await _pdfRenderer!.openPage(pageIndex: pageIndex);

      // ページサイズを取得
      final pageSize = await _pdfRenderer!.getPageSize(pageIndex: pageIndex);

      // ページをレンダリング
      final image = await _pdfRenderer!.renderPage(
        pageIndex: pageIndex,
        x: 0,
        y: 0,
        width: pageSize.width.toInt(),
        height: pageSize.height.toInt(),
        scale: 1.0,
        background: Colors.white,
      );

      // ページを閉じる
      await _pdfRenderer!.closePage(pageIndex: pageIndex);

      return image;
    } catch (e) {
      return null;
    }
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
