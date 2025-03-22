import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import 'reader_page_layout.dart';

/// ページナビゲーション機能を担当するクラス
class ReaderNavigation {
  final Book book;
  final PageController pageController;
  final bool useDoublePage;
  final ReaderPageLayout pageLayout;
  final BookService _bookService = BookService();

  ReaderNavigation({
    required this.book,
    required this.pageController,
    required this.useDoublePage,
    required this.pageLayout,
  });

  /// 特定のページに直接ジャンプする
  void jumpToPage(int pageNumber, bool isRightToLeft) {
    if (pageNumber < 0 || pageNumber >= book.totalPages) {
      // 範囲外のページ番号の場合は何もしない
      return;
    }

    // 直接ページ番号にジャンプ
    pageController.jumpToPage(pageNumber);

    // 最後に読んだページを更新
    updateLastReadPage(pageNumber);
  }

  /// 前のページに移動
  void goToPreviousPage() {
    if (pageController.page != null && pageController.page! > 0) {
      final currentPage = pageController.page!.round();

      if (useDoublePage) {
        // 見開きモードの場合、現在のページが見開き表示かどうかを確認
        _checkAndNavigate(currentPage, -1);
      } else {
        // 通常の単一ページ表示の場合は単純に移動
        pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// 次のページに移動
  void goToNextPage() {
    if (pageController.page != null) {
      final currentPage = pageController.page!.round();

      if (useDoublePage) {
        // 見開きモードの場合、現在のページが見開き表示かどうかを確認
        _checkAndNavigate(currentPage, 1);
      } else {
        // 通常の単一ページ表示の場合は単純に移動
        pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// 見開き表示かどうかを確認して適切に移動
  Future<void> _checkAndNavigate(int currentPage, int direction) async {
    final nextPage = currentPage + 1;

    // 現在のページと次のページが両方とも縦長かどうかを確認
    if (nextPage < book.totalPages &&
        await pageLayout.canShowDoublePage(currentPage, nextPage)) {
      // 見開き表示の場合は2ページ分移動
      final targetPage = currentPage + (direction * 2);

      if (targetPage >= 0 && targetPage < book.totalPages) {
        pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // 単一ページ表示の場合は1ページ分移動
      final targetPage = currentPage + direction;

      if (targetPage >= 0 && targetPage < book.totalPages) {
        pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// 最後に読んだページを更新
  Future<void> updateLastReadPage(int page) async {
    if (page != book.lastReadPage) {
      await _bookService.updateLastReadPage(book.id, page);
    }
  }

  /// 相対的なページ移動を行う（見開き表示でも1ページだけ移動）
  void navigateToRelativePage(
    int direction,
    int currentPage,
    bool isRightToLeft,
  ) {
    try {
      // 単純に1ページ分移動
      final targetPage = currentPage + direction;

      if (targetPage >= 0 && targetPage < book.totalPages) {
        pageController.jumpToPage(targetPage);
      }
    } catch (e) {
      // エラー処理
    }
  }
}
