import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/file_service.dart';
import 'logger.dart';

/// ページレイアウトを管理するクラス
///
/// 画像のアスペクト比に基づいて、単一ページ表示または見開きページ表示を決定し、
/// ページレイアウトを計算する責任を持ちます。
class PageLayoutManager {
  /// ファイルサービス
  final FileService _fileService;

  /// 本のファイルパス
  final String _filePath;

  /// 総ページ数
  final int _totalPages;

  /// 見開きページ表示を使用するかどうか
  bool _useDoublePage = false;

  /// ページレイアウト情報
  ///
  /// 各要素は以下のいずれかの形式：
  /// - 単一ページの場合: ページ番号そのもの（0〜65535の値）
  /// - 見開きページの場合: (左ページ << 16) | 右ページ（ビット演算で2つのページ番号を格納）
  List<int> _pageLayout = [];

  /// コンストラクタ
  PageLayoutManager(this._fileService, this._filePath, this._totalPages);

  /// 見開きページ表示を使用するかどうか
  bool get useDoublePage => _useDoublePage;

  /// ページレイアウト情報
  List<int> get pageLayout => _pageLayout;

  /// ページレイアウトの長さ（表示上のページ数）
  int get pageCount => _useDoublePage ? _pageLayout.length : _totalPages;

  /// 画像のアスペクト比を分析して見開きレイアウトを決定
  Future<void> determinePageLayout(BuildContext context) async {
    Logger.debug('ページレイアウトの決定を開始', tag: 'PageLayoutManager');

    // 初期状態ではすべてのページを単一ページとして扱う
    _pageLayout = List.generate(_totalPages, (index) => index);
    _useDoublePage = false;

    // 画面のアスペクト比を取得
    final screenSize = MediaQuery.of(context).size;
    final screenAspect = screenSize.width / screenSize.height;
    Logger.debug('画面のアスペクト比: $screenAspect', tag: 'PageLayoutManager');

    // 見開き表示が可能かどうかを判断（横長の画面の場合のみ）
    if (screenAspect >= 1.2) {
      Logger.debug('横長の画面を検出: 見開き表示の可能性を検討', tag: 'PageLayoutManager');

      // 画像のアスペクト比を分析
      final aspectRatios = await _analyzeImageAspectRatios();

      // アスペクト比の平均を計算
      final avgAspect = _calculateAverageAspectRatio(aspectRatios);

      // 平均アスペクト比が縦長（0.8未満）の場合、見開き表示を有効にする
      if (avgAspect != null && avgAspect < 0.8) {
        Logger.debug('縦長の画像を検出: 見開き表示を有効化', tag: 'PageLayoutManager');
        _useDoublePage = true;
        _createDoublePageLayout();
      } else {
        Logger.debug('見開き表示の条件を満たさず: 単一ページ表示を使用', tag: 'PageLayoutManager');
      }
    } else {
      Logger.debug('縦長の画面: 単一ページ表示を使用', tag: 'PageLayoutManager');
    }
  }

  /// 最初の数ページの画像アスペクト比を分析
  Future<List<double?>> _analyzeImageAspectRatios() async {
    // 最初の10ページ（または全ページ）のアスペクト比を取得
    final pagesToCheck = _totalPages > 10 ? 10 : _totalPages;
    List<double?> aspectRatios = [];

    for (int i = 0; i < pagesToCheck; i++) {
      try {
        final imageData = await _fileService.getZipImageData(_filePath, i);
        if (imageData != null) {
          final aspect = await _fileService.getImageAspectRatio(imageData);
          aspectRatios.add(aspect);
          Logger.debug('ページ $i のアスペクト比: $aspect', tag: 'PageLayoutManager');
        }
      } catch (e) {
        Logger.error('ページ $i のアスペクト比取得エラー', tag: 'PageLayoutManager', error: e);
      }
    }

    return aspectRatios;
  }

  /// アスペクト比の平均を計算
  double? _calculateAverageAspectRatio(List<double?> aspectRatios) {
    double avgAspect = 0;
    int validCount = 0;

    for (final aspect in aspectRatios) {
      if (aspect != null) {
        avgAspect += aspect;
        validCount++;
      }
    }

    if (validCount > 0) {
      avgAspect /= validCount;
      Logger.debug(
        '平均アスペクト比: $avgAspect (有効サンプル: $validCount)',
        tag: 'PageLayoutManager',
      );
      return avgAspect;
    }

    Logger.warning('有効なアスペクト比がありません', tag: 'PageLayoutManager');
    return null;
  }

  /// 見開きページレイアウトを作成
  void _createDoublePageLayout() {
    Logger.debug('見開きページレイアウトの作成を開始', tag: 'PageLayoutManager');
    _pageLayout = [];

    // 最初のページは単独表示
    _pageLayout.add(0);
    Logger.debug('最初のページを単独表示に設定: 0', tag: 'PageLayoutManager');

    // 残りのページを2ページずつグループ化
    for (int i = 1; i < _totalPages; i += 2) {
      if (i + 1 < _totalPages) {
        // 2ページを組み合わせる
        final layoutData = (i << 16) | (i + 1);
        _pageLayout.add(layoutData);
        Logger.debug(
          '見開きページを追加: $i と ${i + 1} (データ: $layoutData)',
          tag: 'PageLayoutManager',
        );
      } else {
        // 最後の1ページが余る場合は単独表示
        _pageLayout.add(i);
        Logger.debug('最後のページを単独表示に設定: $i', tag: 'PageLayoutManager');
      }
    }

    Logger.debug(
      '見開きページレイアウト作成完了: ${_pageLayout.length}ページ',
      tag: 'PageLayoutManager',
    );
  }

  /// レイアウトインデックスから実際のページ番号を取得
  List<int> getPagesForLayout(int layoutIndex) {
    if (layoutIndex < 0 || layoutIndex >= _pageLayout.length) {
      Logger.error('無効なレイアウトインデックス: $layoutIndex', tag: 'PageLayoutManager');
      return [];
    }

    final pageData = _pageLayout[layoutIndex];
    List<int> pages = [];

    if (pageData < 65536) {
      // シングルページの場合
      pages.add(pageData);
      Logger.debug(
        'レイアウト $layoutIndex はシングルページ: $pageData',
        tag: 'PageLayoutManager',
      );
    } else {
      // ダブルページの場合
      final leftPage = pageData >> 16;
      final rightPage = pageData & 0xFFFF;
      pages.add(leftPage);
      pages.add(rightPage);
      Logger.debug(
        'レイアウト $layoutIndex はダブルページ: 左=$leftPage, 右=$rightPage',
        tag: 'PageLayoutManager',
      );
    }

    return pages;
  }

  /// 指定されたページ構成に対応するレイアウトインデックスを探す
  int findLayoutIndexForPages(List<int> targetPages) {
    if (targetPages.isEmpty) {
      Logger.error('ターゲットページが空です', tag: 'PageLayoutManager');
      return -1;
    }

    // 既存のレイアウトから探す
    for (int i = 0; i < _pageLayout.length; i++) {
      final layoutData = _pageLayout[i];
      final currentPages = getPagesForLayout(i);

      if (currentPages.length == targetPages.length) {
        bool match = true;
        for (int j = 0; j < currentPages.length; j++) {
          if (currentPages[j] != targetPages[j]) {
            match = false;
            break;
          }
        }

        if (match) {
          Logger.debug(
            'ターゲットページに一致するレイアウトを発見: インデックス $i',
            tag: 'PageLayoutManager',
          );
          return i;
        }
      }
    }

    Logger.debug(
      'ターゲットページに一致するレイアウトが見つかりません: $targetPages',
      tag: 'PageLayoutManager',
    );
    return -1;
  }

  /// 新しいページレイアウトを追加
  int addCustomLayout(List<int> pages) {
    if (pages.isEmpty || pages.length > 2) {
      Logger.error('無効なページ構成: $pages', tag: 'PageLayoutManager');
      return -1;
    }

    if (pages.length == 1) {
      // シングルページの場合
      _pageLayout.add(pages[0]);
      Logger.debug('新しいシングルページレイアウトを追加: ${pages[0]}', tag: 'PageLayoutManager');
    } else {
      // ダブルページの場合
      final layoutData = (pages[0] << 16) | pages[1];
      _pageLayout.add(layoutData);
      Logger.debug(
        '新しいダブルページレイアウトを追加: ${pages[0]}と${pages[1]} (データ: $layoutData)',
        tag: 'PageLayoutManager',
      );
    }

    return _pageLayout.length - 1;
  }
}
