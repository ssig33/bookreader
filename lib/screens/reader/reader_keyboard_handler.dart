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
  KeyEventResult handleKeyEvent(FocusNode node, RawKeyEvent event) {
    // デバッグ: キーイベントの情報をログに出力
    print(
      'キーイベント: ${event.runtimeType}, キー: ${event.logicalKey.keyLabel}, コード: ${event.logicalKey.keyId}',
    );
    print('LogicalKeyboardKey.keyH のコード: ${LogicalKeyboardKey.keyH.keyId}');
    print('LogicalKeyboardKey.keyL のコード: ${LogicalKeyboardKey.keyL.keyId}');
    print('LogicalKeyboardKey.keyJ のコード: ${LogicalKeyboardKey.keyJ.keyId}');
    print('LogicalKeyboardKey.keyK のコード: ${LogicalKeyboardKey.keyK.keyId}');

    if (event is RawKeyDownEvent) {
      print(
        'キーダウンイベント検出: ${event.logicalKey.keyLabel}, コード: ${event.logicalKey.keyId}',
      );

      // 直接キーコードで比較
      final keyId = event.logicalKey.keyId;

      if (keyId == 106 || keyId == 0x0000006A) {
        // j のキーコード
        print('J キーが押されました');
        if (event.isShiftPressed) {
          // Shift+J: 見開きでも1ページだけ進む
          print('Shift+J: 1ページだけ進みます');
          goToNextSinglePage();
        } else {
          // j: 常に次のページへ（読み方向に関係なく）
          print('j: 次のページへ移動します');
          goToNextPage();
        }
        return KeyEventResult.handled;
      } else if (keyId == 107 || keyId == 0x0000006B) {
        // k のキーコード
        print('K キーが押されました');
        if (event.isShiftPressed) {
          // Shift+K: 見開きでも1ページだけ戻る
          print('Shift+K: 1ページだけ戻ります');
          goToPreviousSinglePage();
        } else {
          // k: 常に前のページへ（読み方向に関係なく）
          print('k: 前のページへ移動します');
          goToPreviousPage();
        }
        return KeyEventResult.handled;
      } else if (keyId == 104 || keyId == 0x00000068) {
        // h のキーコード
        print('H キーが押されました: 1ページだけ進みます');
        // h: Shift+J と同等（見開きでも1ページだけ進む）
        goToNextSinglePage();
        return KeyEventResult.handled;
      } else if (keyId == 108 || keyId == 0x0000006C) {
        // l のキーコード
        print('L キーが押されました: 1ページだけ戻ります');
        // l: Shift+K と同等（見開きでも1ページだけ戻る）
        goToPreviousSinglePage();
        return KeyEventResult.handled;
      } else if (keyId == 116 || keyId == 0x00000074) {
        // t のキーコード (テスト用)
        print('T キーが押されました: ページコントローラーの状態をテスト');
        debugPageController();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
