import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/file_service.dart';

/// ZIP画像の読み込みと処理を担当するクラス
class ReaderImageLoader {
  final FileService _fileService = FileService();
  final Book book;

  // ページ画像のキャッシュ
  List<Uint8List?> _pageImages = [];
  bool isLoading = true;

  // メモリ内画像キャッシュ
  final Map<int, Uint8List> _imageCache = {};
  final int _maxCacheSize = 10; // キャッシュするページ数
  final List<int> _cacheOrder = []; // LRUキャッシュの順序を管理

  ReaderImageLoader({required this.book});

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
      _pageImages = List.filled(imagePaths.length, null);

      isLoading = false;
    } catch (e) {
      print('ZIP画像読み込みエラー: $e');
      isLoading = false;
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
      final imageData = await _fileService.getZipImageData(
        book.filePath,
        pageIndex,
      );

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
      print('ページプリロードエラー: $e');
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

    // キャッシュにない場合はディスクから読み込む
    final imageData = await _fileService.getZipImageData(
      book.filePath,
      pageIndex,
    );

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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Image.memory(
              snapshot.data!,
              key: ValueKey<int>(pageIndex), // キーを指定して異なる画像と認識させる
              fit: BoxFit.contain,
              // 画像の境界線を削除
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
