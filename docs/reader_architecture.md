# リーダー画面アーキテクチャドキュメント

## 概要

リーダー画面（ReaderScreen）は、本アプリケーションの中核機能である電子書籍の閲覧機能を提供します。主にZIP/CBZ形式の漫画ファイルを表示するために設計されており、ユーザーフレンドリーなインターフェースと高度なページナビゲーション機能を備えています。

## 主要機能

1. **基本的な閲覧機能**
   - ZIPファイルからの画像抽出と表示
   - ページめくり（左右方向）
   - 最後に読んだページの記憶と復元

2. **高度なレイアウト機能**
   - 画像と画面のアスペクト比に基づく自動見開き表示
   - 読み方向の切り替え（左から右、右から左）
   - 見開き表示時の特殊なページナビゲーション

3. **ユーザーインタラクション**
   - タッチ/クリックによるページめくり
   - キーボードナビゲーション（j, k, h, l キー）
   - 画面タップによるコントロールの表示/非表示

## アーキテクチャ構成

### クラス構造

```
ReaderScreen (StatefulWidget)
└── _ReaderScreenState
    ├── サービス連携
    │   ├── BookService
    │   └── FileService
    ├── ユーティリティマネージャー
    │   ├── PageLayoutManager（ページレイアウト管理）
    │   └── KeyboardNavigationManager（キーボードナビゲーション管理）
    ├── 状態管理
    │   ├── ページ関連状態（_currentPage, _pageController, _isRightToLeft）
    │   └── UI関連状態（_showControls, _isLoading）
    ├── ページ処理ロジック
    │   ├── ZIPファイル処理（_loadZipImages）
    │   └── ページナビゲーション（_goToNextPage, _goToPreviousPage, _navigateToRelativePage）
    └── UI構築
        ├── メインビュー（PageView.builder）
        ├── ページ表示（_buildZipPageView, _buildSinglePageView）
        ├── コントロール表示
        └── キーボードイベント処理（_handleKeyEvent）

PageLayoutManager
├── 状態管理
│   ├── _useDoublePage（見開き表示フラグ）
│   └── _pageLayout（ページレイアウト情報）
└── メソッド
    ├── determinePageLayout（レイアウト決定）
    ├── getPagesForLayout（レイアウトからページ取得）
    ├── findLayoutIndexForPages（ページからレイアウト検索）
    └── addCustomLayout（カスタムレイアウト追加）

KeyboardNavigationManager
├── 状態管理
│   └── _keyMap（キーマッピング）
└── メソッド
    ├── processKeyEvent（キーイベント処理）
    └── debugKeyEvent（デバッグ出力）

Logger
└── メソッド
    ├── debug（デバッグログ出力）
    ├── info（情報ログ出力）
    ├── warning（警告ログ出力）
    └── error（エラーログ出力）
```

### データフロー

1. **初期化フロー**
   - `initState`: 初期設定、前回の読書位置の復元
   - `PageLayoutManager`の初期化
   - `_loadZipImages`: ZIPファイルから画像を抽出
   - `PageLayoutManager.determinePageLayout`: 画像のアスペクト比を分析し、見開き表示の可否を判断

2. **ページナビゲーションフロー**
   - ユーザーアクション（タップ、キー入力）
   - `KeyboardNavigationManager.processKeyEvent`: キーイベントの処理とアクション決定
   - ナビゲーションメソッド呼び出し
   - `_navigateToRelativePage`: ページ移動ロジックの実行
   - PageControllerによるページ切り替え
   - `onPageChanged`コールバックでの状態更新
   - `_updateLastReadPage`による読書位置の保存

3. **レンダリングフロー**
   - `build`メソッドでのUI構築
   - `PageView.builder`によるページの動的生成
   - `_buildZipPageView`: ページレイアウトに基づいたビュー構築
   - `_buildSinglePageView`: 単一ページのレンダリング
   - `FutureBuilder`による非同期画像読み込み

## 技術的詳細

### 見開きページ表示の実装

見開きページ表示は、PageLayoutManagerクラスによって管理され、以下のステップで実装されています：

1. 画面と画像のアスペクト比を分析
2. 横長の画面で縦長の画像（アスペクト比0.8未満）の場合に見開き表示を有効化
3. ページレイアウトの計算：
   - 最初のページは単独表示
   - 残りのページを2ページずつグループ化
   - ビット演算を使用して2つのページ番号を1つの整数に格納（(leftPage << 16) | rightPage）

### キーボードナビゲーション

キーボードナビゲーションは、KeyboardNavigationManagerクラスによって管理され、以下の機能を提供します：

- NavigationAction列挙型による宣言的なアクション定義
- キーマッピングによる柔軟なキー割り当て
- 以下のキーをサポート：
  - `j`: 次のページへ移動
  - `k`: 前のページへ移動
  - `Shift+J`/`h`: 見開き表示でも1ページだけ進む
  - `Shift+K`/`l`: 見開き表示でも1ページだけ戻る

### ロギングシステム

Loggerクラスを導入し、以下の機能を提供します：

- 異なるログレベル（debug, info, warning, error）
- タグによるログの分類
- デバッグモードでのみログを出力するオプション
- エラー詳細とスタックトレースの記録

### 読み方向の切り替え

読み方向（左から右、右から左）の切り替えは、以下の処理を行います：

1. BookServiceを通じてデータベースの設定を更新
2. ローカル状態（_isRightToLeft）の更新
3. PageControllerの再作成（reverse属性の変更）
4. UIの再構築

## 最適化ポイント

1. **画像読み込みの最適化**
   - 必要なページのみ読み込む遅延読み込み方式
   - FutureBuilderによる非同期処理

2. **メモリ管理**
   - 画像キャッシュの使用
   - 不要なリソースの適切な解放（dispose）

3. **パフォーマンス考慮点**
   - ページレイアウト計算の最適化（最初の10ページのみ分析）
   - ビット演算を使用した効率的なデータ格納

## 今後の改善点

1. **コードの分割**
   - 長いメソッドの分割
   - 責任の明確な分離

2. **デバッグ出力の整理**
   - ロギングシステムの導入
   - デバッグフラグによる制御

3. **ページレイアウト計算の最適化**
   - 専用クラスへの抽出
   - アルゴリズムの改善

4. **キーボードイベント処理の改善**
   - より宣言的な実装方法
   - カスタマイズ可能なキーマッピング

5. **エラー処理の強化**
   - ユーザーフレンドリーなエラーメッセージ
   - リカバリーメカニズムの改善