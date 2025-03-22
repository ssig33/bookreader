import 'package:flutter/material.dart';
import '../../models/book.dart';
import 'reader_image_loader.dart';

/// ページレイアウト（単一ページと見開きページ）の管理を担当するクラス
class ReaderPageLayout {
  final Book book;
  final ReaderImageLoader imageLoader;

  bool useDoublePage = false;

  ReaderPageLayout({required this.book, required this.imageLoader});

  /// 画像のアスペクト比を分析して見開きモードを決定
  Future<void> determineDoublePage(BuildContext context) async {
    final totalPages = book.totalPages;

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
        }
      }
    }
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

    // 見開きモードでない場合は単一ページ表示
    if (!useDoublePage) {
      return imageLoader.buildSinglePageView(pageIndex, useDoublePage, context);
    }

    // 最初のページ（表紙）は常に単独表示
    if (pageIndex == 0) {
      return imageLoader.buildSinglePageView(pageIndex, useDoublePage, context);
    }

    // FutureBuilderを使用して非同期処理を扱う
    return FutureBuilder<List<double?>>(
      future: Future.wait([
        imageLoader.getImageAspectRatio(pageIndex),
        pageIndex + 1 < book.totalPages
            ? imageLoader.getImageAspectRatio(pageIndex + 1)
            : Future.value(null),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return imageLoader.buildSinglePageView(
            pageIndex,
            useDoublePage,
            context,
          );
        }

        final currentPageAspect = snapshot.data![0];
        final nextPageAspect = snapshot.data![1];

        // 現在のページと次のページが両方とも縦長の場合は見開き表示
        if (currentPageAspect != null &&
            currentPageAspect < 0.8 &&
            nextPageAspect != null &&
            nextPageAspect < 0.8 &&
            pageIndex + 1 < book.totalPages) {
          // 読み方向に応じてページの順序を決定
          final firstPageIndex = isRightToLeft ? pageIndex + 1 : pageIndex;
          final secondPageIndex = isRightToLeft ? pageIndex : pageIndex + 1;

          return Container(
            color: Colors.black,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  imageLoader.buildSinglePageView(
                    firstPageIndex,
                    useDoublePage,
                    context,
                  ),
                  imageLoader.buildSinglePageView(
                    secondPageIndex,
                    useDoublePage,
                    context,
                  ),
                ],
              ),
            ),
          );
        }

        // 条件を満たさない場合は単一ページ表示
        return imageLoader.buildSinglePageView(
          pageIndex,
          useDoublePage,
          context,
        );
      },
    );
  }

  /// 次のページインデックスを取得
  Future<int> getNextPageIndex(int currentPageIndex) async {
    // 見開きモードでない場合は単純に次のページへ
    if (!useDoublePage) {
      return currentPageIndex + 1;
    }

    // 最初のページ（表紙）の場合は次のページへ
    if (currentPageIndex == 0) {
      return 1;
    }

    // 現在のページと次のページのアスペクト比を取得
    final currentPageAspect = await imageLoader.getImageAspectRatio(
      currentPageIndex,
    );
    final nextPageExists = currentPageIndex + 1 < book.totalPages;
    final nextPageAspect =
        nextPageExists
            ? await imageLoader.getImageAspectRatio(currentPageIndex + 1)
            : null;

    // 現在のページと次のページが両方とも縦長の場合は2ページ進む
    if (currentPageAspect != null &&
        currentPageAspect < 0.8 &&
        nextPageAspect != null &&
        nextPageAspect < 0.8) {
      return currentPageIndex + 2;
    }

    // それ以外の場合は1ページ進む
    return currentPageIndex + 1;
  }

  /// 前のページインデックスを取得
  Future<int> getPreviousPageIndex(int currentPageIndex) async {
    // 最初のページの場合は変更なし
    if (currentPageIndex <= 0) {
      return 0;
    }

    // 見開きモードでない場合は単純に前のページへ
    if (!useDoublePage) {
      return currentPageIndex - 1;
    }

    // 2ページ目の場合は最初のページへ
    if (currentPageIndex == 1) {
      return 0;
    }

    // 前のページと前々ページのアスペクト比を取得
    final previousPageAspect = await imageLoader.getImageAspectRatio(
      currentPageIndex - 1,
    );
    final prePreviousPageExists = currentPageIndex - 2 >= 0;
    final prePreviousPageAspect =
        prePreviousPageExists
            ? await imageLoader.getImageAspectRatio(currentPageIndex - 2)
            : null;

    // 前のページと前々ページが両方とも縦長の場合は2ページ戻る
    if (previousPageAspect != null &&
        previousPageAspect < 0.8 &&
        prePreviousPageAspect != null &&
        prePreviousPageAspect < 0.8) {
      return currentPageIndex - 2;
    }

    // それ以外の場合は1ページ戻る
    return currentPageIndex - 1;
  }
}
