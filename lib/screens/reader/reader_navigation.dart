import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import 'reader_page_layout.dart';

/// ページナビゲーション機能を担当するクラス
class ReaderNavigation {
  final Book book;
  final PageController pageController;
  final ReaderPageLayout pageLayout;
  final BookService _bookService = BookService();

  ReaderNavigation({
    required this.book,
    required this.pageController,
    required this.pageLayout,
  });

  /// 特定のページに直接ジャンプする
  void jumpToPage(int pageNumber, bool isRightToLeft) {
    if (pageNumber < 0 || pageNumber >= book.totalPages) {
      // 範囲外のページ番号の場合は何もしない
      return;
    }

    // 見開きモードでない場合は直接ジャンプ
    if (!pageLayout.useDoublePage) {
      pageController.jumpToPage(pageNumber);
      updateLastReadPage(pageNumber);
      return;
    }

    // 最初のページ（表紙）の場合は直接ジャンプ
    if (pageNumber == 0) {
      pageController.jumpToPage(0);
      updateLastReadPage(0);
      return;
    }

    // 見開きモードの場合、ページ番号に対応するページインデックスを探す
    _findPageIndexAndJump(pageNumber);
  }

  /// ページ番号に対応するページインデックスを探してジャンプする
  Future<void> _findPageIndexAndJump(int pageNumber) async {
    // 現在のページから順に探索
    int currentIndex = pageController.page?.round() ?? 0;

    // 前方向に探索
    for (int i = currentIndex; i < book.totalPages; i++) {
      final currentAspect = await pageLayout.imageLoader.getImageAspectRatio(i);
      final nextAspect =
          i + 1 < book.totalPages
              ? await pageLayout.imageLoader.getImageAspectRatio(i + 1)
              : null;

      if (i == pageNumber) {
        // 目的のページに到達
        pageController.jumpToPage(i);
        updateLastReadPage(i);
        return;
      } else if (i < pageNumber &&
          currentAspect != null &&
          currentAspect < 0.8 &&
          nextAspect != null &&
          nextAspect < 0.8 &&
          i + 1 == pageNumber) {
        // 見開きページの右側が目的のページ
        pageController.jumpToPage(i);
        updateLastReadPage(i);
        return;
      }
    }

    // 後方向に探索
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (i == pageNumber) {
        // 目的のページに到達
        pageController.jumpToPage(i);
        updateLastReadPage(i);
        return;
      }
    }

    // 見つからない場合は直接ジャンプ
    pageController.jumpToPage(pageNumber);
    updateLastReadPage(pageNumber);
  }

  /// 前のページに移動
  void goToPreviousPage() {
    if (pageController.page != null && pageController.page! > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 次のページに移動
  void goToNextPage() {
    pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 最後に読んだページを更新
  Future<void> updateLastReadPage(int page) async {
    if (page != book.lastReadPage) {
      await _bookService.updateLastReadPage(book.id, page);
    }
  }

  /// 相対的なページ移動を行う（見開き表示でも1ページだけ移動）
  Future<void> navigateToRelativePage(
    int direction,
    int currentPage,
    bool isRightToLeft,
  ) async {
    try {
      if (pageLayout.useDoublePage) {
        // 見開きモードの場合
        if (direction > 0) {
          // 次のページへ
          int nextPage = await pageLayout.getNextPageIndex(currentPage);
          if (nextPage < book.totalPages) {
            pageController.jumpToPage(nextPage);
          }
        } else {
          // 前のページへ
          int prevPage = await pageLayout.getPreviousPageIndex(currentPage);
          if (prevPage >= 0) {
            pageController.jumpToPage(prevPage);
          }
        }
      } else {
        // 通常の単一ページ表示の場合は単純に移動
        final targetPage = currentPage + direction;
        if (targetPage >= 0 && targetPage < book.totalPages) {
          pageController.jumpToPage(targetPage);
        }
      }
    } catch (e) {
      // エラー処理
    }
  }
}
