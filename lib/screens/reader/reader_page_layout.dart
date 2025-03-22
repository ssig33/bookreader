import 'package:flutter/material.dart';
import '../../models/book.dart';
import 'reader_image_loader.dart';

/// ページレイアウト（単一ページと見開きページ）の管理を担当するクラス
class ReaderPageLayout {
  final Book book;
  final ReaderImageLoader imageLoader;

  bool useDoublePage = false;

  ReaderPageLayout({required this.book, required this.imageLoader});

  /// 画面のアスペクト比を確認して見開きモードが可能かどうかを判断
  Future<void> determinePageLayout(BuildContext context) async {
    // 画面のアスペクト比を取得
    final screenSize = MediaQuery.of(context).size;
    final screenAspect = screenSize.width / screenSize.height;

    // 横長の画面の場合のみ見開き表示を有効にする
    useDoublePage = screenAspect >= 1.2;
  }

  /// テスト用に見開きモードをリセット
  void resetDoublePageMode() {
    useDoublePage = false;
  }

  /// 現在のページと次のページが両方とも縦長かどうかを確認
  Future<bool> canShowDoublePage(int currentPage, int nextPage) async {
    // 次のページが存在しない場合は単一ページ表示
    if (nextPage >= book.totalPages) {
      return false;
    }

    // 現在のページと次のページのアスペクト比を取得
    final currentAspect = await imageLoader.getImageAspectRatio(currentPage);
    final nextAspect = await imageLoader.getImageAspectRatio(nextPage);

    // どちらかのアスペクト比が取得できない場合は単一ページ表示
    if (currentAspect == null || nextAspect == null) {
      return false;
    }

    // 両方のページが縦長（アスペクト比が0.8未満）の場合のみ見開き表示
    return currentAspect < 0.8 && nextAspect < 0.8;
  }

  /// ZIPファイルのページを表示するウィジェットを構築
  Widget buildZipPageView(
    int pageIndex,
    bool isRightToLeft,
    BuildContext context,
  ) {
    if (imageLoader.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 見開きモードが有効な場合は、現在のページと次のページが両方とも縦長かどうかを確認
    if (useDoublePage) {
      // 次のページのインデックスを計算
      final nextPageIndex = pageIndex + 1;

      // 次のページが存在するかチェック
      if (nextPageIndex < book.totalPages) {
        // FutureBuilderを使用して非同期でアスペクト比をチェック
        return FutureBuilder<bool>(
          future: canShowDoublePage(pageIndex, nextPageIndex),
          builder: (context, snapshot) {
            // データがロード中の場合はローディングインジケータを表示
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 見開き表示が可能な場合
            if (snapshot.hasData && snapshot.data == true) {
              // 読み方向に応じてページの順序を決定
              final firstPage = isRightToLeft ? nextPageIndex : pageIndex;
              final secondPage = isRightToLeft ? pageIndex : nextPageIndex;

              return Container(
                color: Colors.black,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 余白なしでページを並べる
                      imageLoader.buildSinglePageView(
                        firstPage,
                        true, // 見開きモード
                        context,
                      ),
                      // 中央の境界線を削除し、ページをぴったりくっつける
                      imageLoader.buildSinglePageView(
                        secondPage,
                        true, // 見開きモード
                        context,
                      ),
                    ],
                  ),
                ),
              );
            }

            // 見開き表示ができない場合は単一ページ表示
            return imageLoader.buildSinglePageView(
              pageIndex,
              false, // 単一ページモード
              context,
            );
          },
        );
      }
    }

    // 見開きモードが無効または次のページが存在しない場合は単一ページ表示
    return imageLoader.buildSinglePageView(
      pageIndex,
      false, // 単一ページモード
      context,
    );
  }
}
