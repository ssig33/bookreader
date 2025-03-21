import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/file_service.dart';
import 'reader_image_loader.dart';

/// ページレイアウト（単一ページと見開きページ）の管理を担当するクラス
class ReaderPageLayout {
  final Book book;
  final FileService _fileService = FileService();
  final ReaderImageLoader imageLoader;

  bool useDoublePage = false;
  List<int> pageLayout = []; // シングルページまたはダブルページのレイアウト

  ReaderPageLayout({required this.book, required this.imageLoader});

  /// 画像のアスペクト比を分析して見開きレイアウトを決定
  Future<void> determinePageLayout(BuildContext context) async {
    final totalPages = book.totalPages;
    pageLayout = List.generate(totalPages, (index) => index);

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
        final aspect = await imageLoader.getImageAspectRatio(i);
        aspectRatios.add(aspect);
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
          useDoublePage = true;

          // 見開きページレイアウトを作成
          createDoublePageLayout(totalPages);
        }
      }
    }
  }

  /// 見開きページレイアウトを作成
  void createDoublePageLayout(int totalPages) {
    pageLayout = [];

    // 最初のページは単独表示
    pageLayout.add(0);

    // 残りのページを2ページずつグループ化
    // 右から左への読み方向の場合は、偶数ページが左、奇数ページが右になるように組み合わせる
    for (int i = 1; i < totalPages; i += 2) {
      if (i + 1 < totalPages) {
        // 2ページを組み合わせる
        // 右から左の場合は順序を入れ替える必要はない（表示時に対応）
        pageLayout.add((i << 16) | (i + 1));
      } else {
        // 最後の1ページが余る場合は単独表示
        pageLayout.add(i);
      }
    }
  }

  /// ZIPファイルのページを表示するウィジェットを構築
  Widget buildZipPageView(
    int layoutIndex,
    bool isRightToLeft,
    BuildContext context,
  ) {
    if (imageLoader.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (useDoublePage) {
      // 見開きページの場合
      final pageData = pageLayout[layoutIndex];

      if (pageData < 65536) {
        // シングルページの場合
        return imageLoader.buildSinglePageView(
          pageData,
          useDoublePage,
          context,
        );
      } else {
        // ダブルページの場合
        final leftPage = pageData >> 16;
        final rightPage = pageData & 0xFFFF;

        // 読み方向に応じてページの順序を決定
        final firstPage = isRightToLeft ? rightPage : leftPage;
        final secondPage = isRightToLeft ? leftPage : rightPage;

        return Container(
          color: Colors.black,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 余白なしでページを並べる
                imageLoader.buildSinglePageView(
                  firstPage,
                  useDoublePage,
                  context,
                ),
                // 中央の境界線を削除し、ページをぴったりくっつける
                imageLoader.buildSinglePageView(
                  secondPage,
                  useDoublePage,
                  context,
                ),
              ],
            ),
          ),
        );
      }
    } else {
      // 通常の単一ページ表示
      return imageLoader.buildSinglePageView(
        layoutIndex,
        useDoublePage,
        context,
      );
    }
  }
}
