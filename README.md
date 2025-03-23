# BookReader

マンガや電子書籍を複数のプラットフォームで読むためのFlutterアプリケーション

![image](https://github.com/user-attachments/assets/e871c38c-b32d-4439-a688-f6b27cd4aa1c)


## 概要

BookReaderは、ZIP/CBZ/PDFファイルを管理し、快適に閲覧するためのクロスプラットフォームアプリケーションです。シンプルなインターフェースと高速な表示機能を備え、マンガや電子書籍を効率的に管理・閲覧できます。

## 対応プラットフォーム

- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ macOS
- ✅ Linux

※ PDFサポートはAndroidとiOSのみ対応しています。

## 主要機能

### ファイル管理

- **複数形式対応**: ZIP/CBZ/PDFファイルをサポート
- **簡単インポート**:
  - ファイルダイアログからの選択
  - ドラッグ＆ドロップによる追加
  - インテントによる外部アプリからの登録
- **整理機能**:
  - タグ付け
  - 名前変更
  - タグによる絞り込み検索

### 閲覧機能

- **高速表示**: 効率的な画像読み込みとキャッシュ
- **見開き表示**: 画像と画面のアスペクト比に基づく自動調整
- **柔軟なナビゲーション**:
  - 左右スワイプによるページめくり
  - 方向設定（右から左、左から右）
  - キーボードショートカット（j/k）
  - タッチ操作

### 操作性

- **カスタマイズ可能**: ファイルごとにページめくり方向を設定可能
- **直感的UI**: シンプルで使いやすいインターフェース
- **高速起動**: 効率的なキャッシュシステム

## インストール

### リリースビルドからインストール

1. [Releases](https://github.com/yourusername/bookreader/releases)ページから最新バージョンをダウンロード
2. お使いのプラットフォームに合わせたインストーラーを実行

### ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/bookreader.git

# 依存関係をインストール
cd bookreader
flutter pub get

# デバイスにインストール
flutter run
```

## 開発

### 必要環境

- Flutter SDK 3.7.2以上
- Dart SDK 3.0.0以上
- Android Studio / VS Code（推奨）

### プロジェクト構造

- `lib/models/`: データモデル
- `lib/screens/`: UI画面
- `lib/services/`: ビジネスロジックとデータ処理
- `lib/widgets/`: 再利用可能なUIコンポーネント

## ライセンス

このプロジェクトは[WTFPL](http://www.wtfpl.net/)（Do What The Fuck You Want To Public License）の下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。
