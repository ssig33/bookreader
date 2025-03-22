import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// キーボード操作の処理を担当するクラス
class ReaderKeyboardHandler {
  final Function() goToPreviousPage;
  final Function() goToNextPage;
  final Function() goToPreviousSinglePage;
  final Function() goToNextSinglePage;
  final Function() debugPageController;

  ReaderKeyboardHandler({
    required this.goToPreviousPage,
    required this.goToNextPage,
    required this.goToPreviousSinglePage,
    required this.goToNextSinglePage,
    required this.debugPageController,
  });

  /// キーボードイベントを処理するメソッド
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    // キーイベントの処理

    if (event is KeyDownEvent) {
      // 直接キーコードで比較
      final keyId = event.logicalKey.keyId;
      if (keyId == 106 || keyId == 0x0000006A) {
        // j のキーコード
        if (HardwareKeyboard.instance.isShiftPressed) {
          // Shift+J: 見開きでも1ページだけ進む
          goToNextSinglePage();
        } else {
          // j: 常に次のページへ（読み方向に関係なく）
          goToNextPage();
        }
        return KeyEventResult.handled;
      } else if (keyId == 107 || keyId == 0x0000006B) {
        // k のキーコード
        if (HardwareKeyboard.instance.isShiftPressed) {
          // Shift+K: 見開きでも1ページだけ戻る
          goToPreviousSinglePage();
        } else {
          // k: 常に前のページへ（読み方向に関係なく）
          goToPreviousPage();
        }
        return KeyEventResult.handled;
      } else if (keyId == 104 || keyId == 0x00000068) {
        // h のキーコード
        // h: Shift+J と同等（見開きでも1ページだけ進む）
        goToNextSinglePage();
        return KeyEventResult.handled;
      } else if (keyId == 108 || keyId == 0x0000006C) {
        // l のキーコード
        // l: Shift+K と同等（見開きでも1ページだけ戻る）
        goToPreviousSinglePage();
        return KeyEventResult.handled;
      } else if (keyId == 116 || keyId == 0x00000074) {
        // t のキーコード (テスト用)
        debugPageController();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
