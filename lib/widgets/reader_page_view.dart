import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/file_service.dart';
import '../utils/logger.dart';
import '../utils/page_layout_manager.dart';

/// リーダー画面のページビューを管理するウィジェット
class ReaderPageView extends StatelessWidget {
  /// 表示する本
  final Book book;

  /// ファイルサービス
  final FileService fileService;

  /// ページレイアウトマネージャー
  final PageLayoutManager layoutManager;

  /// 読み方向（右から左かどうか）
  final bool isRightToLeft;

  /// ローディング中かどうか
  final bool isLoading;

  /// ページ画像のキャッシュ
  final List<Uint8List?> pageImages;

  /// 再読み込み時のコールバック
  final VoidCallback onReload;

  /// コンストラクタ
  const ReaderPageView({
    Key? key,
    required this.book,
    required this.fileService,
    required this.layoutManager,
    required this.isRightToLeft,
    required this.isLoading,
    required this.pageImages,
    required this.onReload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: PageController(initialPage: book.lastReadPage),
      reverse: isRightToLeft, // 右から左への読み方向に対応
      onPageChanged: (int page) {
        // ページ変更時のコールバックは親ウィジェットで処理
      },
      itemCount:
          layoutManager.useDoublePage
              ? layoutManager.pageLayout.length
              : book.totalPages,
      itemBuilder: (context, index) {
        if (book.fileType == 'zip' || book.fileType == 'cbz') {
          return buildZipPageView(context, index);
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
    );
  }

  /// ZIPファイルのページを表示するウィジェットを構築
  Widget buildZipPageView(BuildContext context, int layoutIndex) {
    if (isLoading) {
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

    if (layoutManager.useDoublePage) {
      // 見開きページの場合
      final pages = layoutManager.getPagesForLayout(layoutIndex);

      if (pages.isEmpty) {
        Logger.error('ページ情報を取得できませんでした: $layoutIndex', tag: 'ReaderPageView');
        return const Center(
          child: Text(
            'ページ情報の読み込みエラー',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        );
      }

      if (pages.length == 1) {
        // シングルページの場合
        return buildSinglePageView(context, pages[0]);
      } else {
        // ダブルページの場合
        final leftPage = pages[0];
        final rightPage = pages[1];

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
                buildSinglePageView(context, firstPage),
                // 中央の境界線を削除し、ページをぴったりくっつける
                buildSinglePageView(context, secondPage),
              ],
            ),
          ),
        );
      }
    } else {
      // 通常の単一ページ表示
      return buildSinglePageView(context, layoutIndex);
    }
  }

  /// 単一ページを表示するウィジェット
  Widget buildSinglePageView(BuildContext context, int pageIndex) {
    return FutureBuilder<Uint8List?>(
      future: fileService.getZipImageData(book.filePath, pageIndex),
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
            tag: 'ReaderPageView',
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
                    onPressed: onReload,
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
              layoutManager.useDoublePage
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
                layoutManager.useDoublePage
                    ? (MediaQuery.of(context).size.width ~/ 2).toInt()
                    : null,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              Logger.error(
                'ページ画像表示エラー: $pageIndex',
                tag: 'ReaderPageView',
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
}
