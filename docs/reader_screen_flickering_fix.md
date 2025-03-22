# 見開き表示時のちらつき問題の修正

## 問題の概要
見開き表示モードでページを切り替える際に、画面がちらつく問題が発生していました。特に2ページ遷移する際に顕著でした。

## 原因分析
1. **アニメーション時間が長すぎる**: 
   - 画像切り替え時のアニメーション（AnimatedSwitcher）が200ミリ秒
   - ページ遷移アニメーションが300ミリ秒

2. **アニメーションカーブの問題**:
   - `Curves.easeInOut`は始点と終点の両方で減速するため、視覚的にちらつきを感じやすい

## 実装した修正
1. **見開きモード時のアニメーション削除** (`reader_image_loader.dart`):
   ```dart
   child: useDoublePage
     // 見開きモードではアニメーションを使用しない
     ? Image.memory(
         snapshot.data!,
         key: ValueKey<int>(pageIndex),
         fit: BoxFit.contain,
         gaplessPlayback: true,
       )
     // 通常モードではアニメーションを維持
     : AnimatedSwitcher(
         duration: const Duration(milliseconds: 200),
         child: Image.memory(
           snapshot.data!,
           key: ValueKey<int>(pageIndex),
           fit: BoxFit.contain,
           gaplessPlayback: true,
         ),
       ),
   ```

2. **見開きモード時のページ遷移アニメーション削除** (`reader_navigation.dart`):
   - 見開きモード時はアニメーションを使用せず、即座にページ遷移
   ```dart
   // 見開きモードではアニメーションを使用せず、即座にページ遷移
   pageController.jumpToPage(targetPage);
   ```
   
   - 通常モードではアニメーションを維持
   ```dart
   // 単一ページ表示の場合はアニメーションを維持
   pageController.animateToPage(
     targetPage,
     duration: const Duration(milliseconds: 200),
     curve: Curves.easeOut,
   );
   ```

## 期待される効果
- 見開きモードでのページ切り替え時のちらつきが軽減される
- ページ遷移がより滑らかに感じられる
- 既存の機能や動作は維持したまま、視覚的な体験のみを改善

## 今後の改善案
さらなる改善が必要な場合は、以下の方法も検討できます：

1. **見開きページの同期読み込み**:
   - 見開きモードでは、2つのページを同時に読み込んで同時に表示する仕組みを追加

2. **プリロードの強化**:
   - 見開きモード時に、次の遷移先の両方のページを優先的にプリロードする