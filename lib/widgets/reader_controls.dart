import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../utils/logger.dart';

/// リーダー画面のコントロールを管理するウィジェット
class ReaderControls extends StatelessWidget {
  /// 表示する本
  final Book book;

  /// 現在のページ
  final int currentPage;

  /// 読み方向（右から左かどうか）
  final bool isRightToLeft;

  /// コントロールが表示されているかどうか
  final bool showControls;

  /// 戻るボタンのコールバック
  final VoidCallback onBack;

  /// 読み方向切り替えのコールバック
  final Future<void> Function() onToggleReadingDirection;

  /// 前のページへ移動するコールバック
  final VoidCallback onPreviousPage;

  /// 次のページへ移動するコールバック
  final VoidCallback onNextPage;

  /// コンストラクタ
  const ReaderControls({
    Key? key,
    required this.book,
    required this.currentPage,
    required this.isRightToLeft,
    required this.showControls,
    required this.onBack,
    required this.onToggleReadingDirection,
    required this.onPreviousPage,
    required this.onNextPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showControls) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 上部コントロール
        _buildTopControls(context),

        // 下部コントロール
        _buildBottomControls(context),
      ],
    );
  }

  /// 上部コントロールを構築
  Widget _buildTopControls(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 8,
          right: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
              tooltip: '戻る',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.totalPages > 0)
                    Text(
                      'ページ: ${currentPage + 1} / ${book.totalPages}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              icon: Icon(
                isRightToLeft
                    ? Icons.format_textdirection_r_to_l
                    : Icons.format_textdirection_l_to_r,
                color: Colors.white,
              ),
              label: Text(
                isRightToLeft ? '右→左' : '左→右',
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                Logger.debug('読み方向切り替えボタンが押されました', tag: 'ReaderControls');
                await onToggleReadingDirection();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 下部コントロールを構築
  Widget _buildBottomControls(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ページめくり方向の説明
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isRightToLeft ? '← 右から左へめくる →' : '← 左から右へめくる →',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左側のボタン
              _buildNavigationButton(
                icon: Icons.keyboard_arrow_left,
                onPressed: isRightToLeft ? onNextPage : onPreviousPage,
                tooltip: isRightToLeft ? '次のページ' : '前のページ',
              ),

              // ページ番号表示
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  book.totalPages > 0
                      ? 'ページ ${currentPage + 1} / ${book.totalPages}'
                      : 'ページ ${currentPage + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),

              // 右側のボタン
              _buildNavigationButton(
                icon: Icons.keyboard_arrow_right,
                onPressed: isRightToLeft ? onPreviousPage : onNextPage,
                tooltip: isRightToLeft ? '前のページ' : '次のページ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ナビゲーションボタンを構築
  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 32),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
