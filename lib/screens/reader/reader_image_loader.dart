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

  /// 単一ページを表示するウィジェット
  Widget buildSinglePageView(
    int pageIndex,
    bool useDoublePage,
    BuildContext context,
  ) {
    return FutureBuilder<Uint8List?>(
      future: _fileService.getZipImageData(book.filePath, pageIndex),
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
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            // 画像の境界線を削除
            gaplessPlayback: true,
          ),
        );
      },
    );
  }

  /// 画像のアスペクト比を取得
  Future<double?> getImageAspectRatio(int pageIndex) async {
    final imageData = await _fileService.getZipImageData(
      book.filePath,
      pageIndex,
    );
    if (imageData != null) {
      return await _fileService.getImageAspectRatio(imageData);
    }
    return null;
  }
}
