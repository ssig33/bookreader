import 'package:flutter/material.dart';
import '../models/book.dart';
import '../utils/logger.dart';
import '../utils/page_layout_manager.dart';

/// リーダーのページナビゲーションを管理するクラス
class ReaderNavigationManager {
  /// 表示する本
  final Book book;

  /// ページレイアウトマネージャー
  final PageLayoutManager layoutManager;

  /// ページコントローラー
  final PageController pageController;

  /// 現在のページ
  int currentPage;

  /// コンストラクタ
  ReaderNavigationManager({
    required this.book,
    required this.layoutManager,
    required this.pageController,
    required this.currentPage,
  });

  /// 前のページへ移動
  void goToPreviousPage() {
    if (currentPage > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 次のページへ移動
  void goToNextPage() {
    pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 見開き表示でも1ページだけ戻る（Shift+K/l用）
  void goToPreviousSinglePage() {
    navigateToRelativePage(-1);
  }

  /// 見開き表示でも1ページだけ進む（Shift+J/h用）
  void goToNextSinglePage() {
    navigateToRelativePage(1);
  }

  /// 相対的なページ移動を行う（見開き表示でも1ページだけ移動）
  void navigateToRelativePage(int direction) {
    try {
      Logger.debug('相対的なページ移動: 方向=$direction', tag: 'ReaderNavigation');
      Logger.debug('現在のページ: $currentPage', tag: 'ReaderNavigation');

      if (layoutManager.useDoublePage) {
        _navigateInDoublePageMode(direction);
      } else {
        _navigateInSinglePageMode(direction);
      }
    } catch (e) {
      Logger.error('ページ移動中にエラーが発生しました', tag: 'ReaderNavigation', error: e);
    }
  }

  /// 見開きモードでのページ移動
  void _navigateInDoublePageMode(int direction) {
    // 見開き表示の場合
    final currentLayoutIndex = currentPage;

    if (currentLayoutIndex >= layoutManager.pageLayout.length) {
      Logger.error(
        'レイアウトインデックスが範囲外です: $currentPage / ${layoutManager.pageLayout.length}',
        tag: 'ReaderNavigation',
      );
      return;
    }

    // 現在表示中の実際のページ番号を取得
    final currentPages = layoutManager.getPagesForLayout(currentLayoutIndex);
    if (currentPages.isEmpty) {
      Logger.error('現在のページ情報を取得できませんでした', tag: 'ReaderNavigation');
      return;
    }

    Logger.debug('現在のページ構成: $currentPages', tag: 'ReaderNavigation');

    // 移動先のページ構成を計算
    final targetPages = _calculateTargetPages(currentPages, direction);

    if (targetPages.isEmpty) {
      Logger.warning('移動先のページがありません', tag: 'ReaderNavigation');
      return;
    }

    Logger.debug('目標ページ構成: $targetPages', tag: 'ReaderNavigation');

    // 目標ページ構成に対応するレイアウトインデックスを探す
    int targetIndex = layoutManager.findLayoutIndexForPages(targetPages);

    // 既存のレイアウトに見つからない場合は、新しいレイアウトを作成
    if (targetIndex == -1) {
      Logger.debug(
        '既存のレイアウトに見つかりませんでした: $targetPages',
        tag: 'ReaderNavigation',
      );

      if (targetPages.length == 1) {
        // 単一ページの場合
        final targetPage = targetPages[0];
        Logger.debug('単一ページを直接表示します: $targetPage', tag: 'ReaderNavigation');

        // ページに直接ジャンプ
        pageController.jumpToPage(targetPage);
        Logger.debug('ページ移動完了', tag: 'ReaderNavigation');
        return;
      } else if (targetPages.length == 2) {
        // ダブルページの場合
        Logger.debug(
          'ダブルページを直接表示します: ${targetPages[0]}と${targetPages[1]}',
          tag: 'ReaderNavigation',
        );

        // 新しいレイアウトを追加
        targetIndex = layoutManager.addCustomLayout(targetPages);
        if (targetIndex == -1) {
          Logger.error('新しいレイアウトの作成に失敗しました', tag: 'ReaderNavigation');
          return;
        }

        Logger.debug(
          '新しいレイアウトを作成しました: インデックス $targetIndex',
          tag: 'ReaderNavigation',
        );
      } else {
        Logger.error('適切なレイアウトが見つかりませんでした', tag: 'ReaderNavigation');
        return;
      }
    }

    // 見つかったインデックスに移動
    Logger.debug(
      'pageController.jumpToPage($targetIndex) を呼び出します',
      tag: 'ReaderNavigation',
    );
    pageController.jumpToPage(targetIndex);
    Logger.debug('ページ移動完了', tag: 'ReaderNavigation');
  }

  /// 単一ページモードでのページ移動
  void _navigateInSinglePageMode(int direction) {
    // 通常の単一ページ表示の場合は単純に移動
    final targetPage = currentPage + direction;
    Logger.debug('目標ページ: $targetPage', tag: 'ReaderNavigation');

    if (targetPage >= 0 && targetPage < book.totalPages) {
      Logger.debug(
        'pageController.jumpToPage($targetPage) を呼び出します',
        tag: 'ReaderNavigation',
      );
      pageController.jumpToPage(targetPage);
      Logger.debug('ページ移動完了', tag: 'ReaderNavigation');
    } else {
      Logger.warning('目標ページが範囲外です: $targetPage', tag: 'ReaderNavigation');
    }
  }

  /// 移動先のページ構成を計算
  List<int> _calculateTargetPages(List<int> currentPages, int direction) {
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

    return targetPages;
  }

  /// ページコントローラーの状態をデバッグ出力
  void debugPageController() {
    Logger.debug('--- PageController デバッグ情報 ---', tag: 'ReaderNavigation');
    Logger.debug('現在のページ: $currentPage', tag: 'ReaderNavigation');
    Logger.debug(
      'PageController.page: ${pageController.page}',
      tag: 'ReaderNavigation',
    );
    Logger.debug(
      'PageController.position.pixels: ${pageController.position.pixels}',
      tag: 'ReaderNavigation',
    );
    Logger.debug(
      'PageController.position.maxScrollExtent: ${pageController.position.maxScrollExtent}',
      tag: 'ReaderNavigation',
    );
    Logger.debug(
      'PageController.position.viewportDimension: ${pageController.position.viewportDimension}',
      tag: 'ReaderNavigation',
    );
    Logger.debug(
      'PageController.position.haveDimensions: ${pageController.position.haveDimensions}',
      tag: 'ReaderNavigation',
    );
    Logger.debug(
      'ページレイアウト: ${layoutManager.pageLayout}',
      tag: 'ReaderNavigation',
    );
    Logger.debug(
      '見開き表示: ${layoutManager.useDoublePage}',
      tag: 'ReaderNavigation',
    );
    Logger.debug('--------------------------------', tag: 'ReaderNavigation');
  }
}
