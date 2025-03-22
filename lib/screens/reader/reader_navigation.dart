import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';

/// ページナビゲーション機能を担当するクラス
class ReaderNavigation {
  final Book book;
  final PageController pageController;
  final bool useDoublePage;
  final List<int> pageLayout;
  final BookService _bookService = BookService();

  ReaderNavigation({
    required this.book,
    required this.pageController,
    required this.useDoublePage,
    required this.pageLayout,
  });

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
  void navigateToRelativePage(
    int direction,
    int currentPage,
    bool isRightToLeft,
  ) {
    try {
      if (useDoublePage) {
        // 見開き表示の場合
        final currentLayoutIndex = currentPage;

        if (currentLayoutIndex >= pageLayout.length) {
          return;
        }

        final currentPageData = pageLayout[currentLayoutIndex];

        // 現在表示中の実際のページ番号を取得
        List<int> currentPages = [];
        if (currentPageData < 65536) {
          // シングルページの場合
          currentPages.add(currentPageData);
        } else {
          // ダブルページの場合
          final leftPage = currentPageData >> 16;
          final rightPage = currentPageData & 0xFFFF;
          currentPages.add(leftPage);
          currentPages.add(rightPage);
        }

        // 移動先のページ構成を計算
        List<int> targetPages = [];
        if (direction > 0) {
          // 次のページへ
          if (currentPages.length == 1) {
            // 現在シングルページの場合、次の2ページを表示
            int nextPage = currentPages[0] + 1;
            if (nextPage < book.totalPages) {
              // 次のページが存在する場合
              if (nextPage + 1 < book.totalPages) {
                // 次の2ページを表示
                targetPages.add(nextPage);
                targetPages.add(nextPage + 1);
              } else {
                // 最後のページの場合は単独表示
                targetPages.add(nextPage);
              }
            }
          } else {
            // 現在ダブルページの場合、右ページを左ページにして新しい右ページを表示
            int rightPage = currentPages[1];
            int newRightPage = rightPage + 1;
            if (newRightPage < book.totalPages) {
              // 次のページが存在する場合、右ページを左ページにして新しい右ページを表示
              targetPages.add(rightPage);
              targetPages.add(newRightPage);
            } else if (rightPage < book.totalPages) {
              // 最後のページの場合は単独表示
              targetPages.add(rightPage);
            }
          }
        } else {
          // 前のページへ
          if (currentPages.length == 1) {
            // 現在シングルページの場合、前の2ページを表示
            int prevPage = currentPages[0] - 1;
            if (prevPage >= 0) {
              // 前のページが存在する場合
              if (prevPage - 1 >= 0) {
                // 前の2ページを表示
                targetPages.add(prevPage - 1);
                targetPages.add(prevPage);
              } else {
                // 最初のページの場合は単独表示
                targetPages.add(prevPage);
              }
            }
          } else {
            // 現在ダブルページの場合、左ページを右ページにして新しい左ページを表示
            int leftPage = currentPages[0];
            int newLeftPage = leftPage - 1;
            if (newLeftPage >= 0) {
              targetPages.add(newLeftPage);
              targetPages.add(leftPage);
            } else if (leftPage >= 0) {
              // 最初のページの場合は単独表示
              targetPages.add(leftPage);
            }
          }
        }

        if (targetPages.isEmpty) {
          return;
        }

        // 目標ページ構成に対応するレイアウトインデックスを探す
        int targetIndex = -1;

        // まず既存のレイアウトから探す
        for (int i = 0; i < pageLayout.length; i++) {
          final layoutData = pageLayout[i];

          if (layoutData < 65536) {
            // シングルページの場合
            if (targetPages.length == 1 && layoutData == targetPages[0]) {
              targetIndex = i;
              break;
            }
          } else {
            // ダブルページの場合
            final leftPage = layoutData >> 16;
            final rightPage = layoutData & 0xFFFF;

            if (targetPages.length == 2 &&
                leftPage == targetPages[0] &&
                rightPage == targetPages[1]) {
              targetIndex = i;
              break;
            }
          }
        }

        // 既存のレイアウトに見つからない場合は、直接ページを表示する
        if (targetIndex == -1) {
          // 単一ページの場合
          if (targetPages.length == 1) {
            final targetPage = targetPages[0];

            // 単一ページを直接表示

            // ページに直接ジャンプ
            pageController.jumpToPage(targetPage);
            return;
          } else if (targetPages.length == 2) {
            // ダブルページの場合
            final targetLeftPage = targetPages[0];
            final targetRightPage = targetPages[1];

            // 新しいレイアウトデータを作成
            final newLayoutData = (targetLeftPage << 16) | targetRightPage;

            // レイアウトに追加
            pageLayout.add(newLayoutData);
            targetIndex = pageLayout.length - 1;

            // 新しいレイアウトを作成しました
          } else {
            return;
          }
        }

        // 見つかったインデックスに移動
        pageController.jumpToPage(targetIndex);
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
