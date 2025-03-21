import 'package:flutter/services.dart';
import 'logger.dart';

/// キーボードナビゲーションの動作を定義する列挙型
enum NavigationAction {
  /// 次のページへ移動
  nextPage,

  /// 前のページへ移動
  previousPage,

  /// 1ページだけ進む（見開き表示でも）
  nextSinglePage,

  /// 1ページだけ戻る（見開き表示でも）
  previousSinglePage,

  /// デバッグ情報を表示
  debug,

  /// 何もしない
  none,
}

/// キーボードナビゲーションを管理するクラス
///
/// キーボードイベントを処理し、適切なナビゲーションアクションを決定する責任を持ちます。
class KeyboardNavigationManager {
  /// キーマッピング（キーコードとアクション）
  final Map<int, NavigationAction> _keyMap = {
    // j キー: 次のページへ
    0x0000006A: NavigationAction.nextPage, // 106
    // k キー: 前のページへ
    0x0000006B: NavigationAction.previousPage, // 107
    // h キー: 1ページだけ進む
    0x00000068: NavigationAction.nextSinglePage, // 104
    // l キー: 1ページだけ戻る
    0x0000006C: NavigationAction.previousSinglePage, // 108
    // t キー: デバッグ情報
    0x00000074: NavigationAction.debug, // 116
  };

  /// キーイベントを処理し、対応するナビゲーションアクションを返す
  NavigationAction processKeyEvent(RawKeyEvent event) {
    // キーダウンイベントのみを処理
    if (event is! RawKeyDownEvent) {
      return NavigationAction.none;
    }

    // キーコードを取得
    final keyId = event.logicalKey.keyId;
    Logger.debug(
      'キーイベント検出: ${event.logicalKey.keyLabel}, コード: $keyId',
      tag: 'KeyboardNavigation',
    );

    // 基本的なキーマッピングをチェック
    if (_keyMap.containsKey(keyId)) {
      final action = _keyMap[keyId]!;

      // Shiftキーが押されている場合の特殊処理
      if (event.isShiftPressed) {
        if (keyId == 0x0000006A) {
          // j キー
          Logger.debug('Shift+J: 1ページだけ進みます', tag: 'KeyboardNavigation');
          return NavigationAction.nextSinglePage;
        } else if (keyId == 0x0000006B) {
          // k キー
          Logger.debug('Shift+K: 1ページだけ戻ります', tag: 'KeyboardNavigation');
          return NavigationAction.previousSinglePage;
        }
      }

      // 通常のアクション
      Logger.debug(
        'キー ${event.logicalKey.keyLabel}: アクション $action',
        tag: 'KeyboardNavigation',
      );
      return action;
    }

    // 対応するアクションがない場合
    return NavigationAction.none;
  }

  /// キーイベントをデバッグ出力
  void debugKeyEvent(RawKeyEvent event) {
    Logger.debug('--- キーイベントデバッグ情報 ---', tag: 'KeyboardNavigation');
    Logger.debug('イベントタイプ: ${event.runtimeType}', tag: 'KeyboardNavigation');
    Logger.debug(
      'キーラベル: ${event.logicalKey.keyLabel}',
      tag: 'KeyboardNavigation',
    );
    Logger.debug('キーコード: ${event.logicalKey.keyId}', tag: 'KeyboardNavigation');
    Logger.debug(
      'Shiftキー押下: ${event.isShiftPressed}',
      tag: 'KeyboardNavigation',
    );
    Logger.debug(
      'Ctrlキー押下: ${event.isControlPressed}',
      tag: 'KeyboardNavigation',
    );
    Logger.debug('Altキー押下: ${event.isAltPressed}', tag: 'KeyboardNavigation');
    Logger.debug('-----------------------------', tag: 'KeyboardNavigation');
  }
}
