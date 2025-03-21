import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../models/book.dart';
import '../../services/file_service.dart';

/// PDFの読み込みと処理を担当するクラス
class ReaderPdfLoader {
  final FileService _fileService = FileService();
  final Book book;

  // PDFドキュメント
  PdfDocument? _pdfDocument;

  // PDFコントローラー
  final PdfViewerController _pdfViewerController = PdfViewerController();

  // レンダリング品質
  double _zoomLevel = 1.0; // デフォルトは1.0

  bool isLoading = true;

  ReaderPdfLoader({required this.book});

  /// PDFファイルを読み込む
  Future<void> loadPdf() async {
    isLoading = true;

    try {
      // PDFファイルを読み込む
      final fileExists = await _fileService.fileExists(book.filePath);
      if (!fileExists) {
        throw Exception('PDFファイルが見つかりません: ${book.filePath}');
      }

      // PDFドキュメントを開く（ページ数やアスペクト比の取得用）
      final bytes = await _fileService.getFileBytes(book.filePath);
      _pdfDocument = PdfDocument(inputBytes: bytes);

      isLoading = false;
    } catch (e) {
      print('PDF読み込みエラー: $e');
      isLoading = false;
    }
  }

  /// PDFドキュメントを閉じる
  void dispose() {
    _pdfDocument?.dispose();
    _pdfDocument = null;
  }

  /// ズームレベルを設定
  void setZoomLevel(double zoomLevel) {
    if (zoomLevel >= 0.5 && zoomLevel <= 3.0) {
      _zoomLevel = zoomLevel;
      _pdfViewerController.zoomLevel = _zoomLevel;
    }
  }

  /// ズームレベルを取得
  double getZoomLevel() {
    return _zoomLevel;
  }

  /// PDFコントローラーを取得
  PdfViewerController getPdfViewerController() {
    return _pdfViewerController;
  }

  /// 特定のページに移動
  void jumpToPage(int pageIndex) {
    _pdfViewerController.jumpToPage(pageIndex + 1); // PDFViewerは1ベースのインデックス
  }

  /// ページをプリロードする
  Future<void> preloadPage(int pageIndex) async {
    // PDFビューワーでは特に何もしない（SfPdfViewerが自動的にページをキャッシュする）
    // ただし、アスペクト比の取得のためにPDFドキュメントが読み込まれていることを確認
    if (_pdfDocument == null) {
      await loadPdf();
    }
  }

  /// 単一ページを表示するウィジェット
  Widget buildSinglePageView(
    int pageIndex,
    bool useDoublePage,
    BuildContext context,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // PDFビューワーウィジェットを作成
    return Container(
      color: Colors.black,
      constraints:
          useDoublePage
              ? BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2)
              : null,
      child: SfPdfViewer.file(
        File(book.filePath),
        controller: _pdfViewerController,
        initialZoomLevel: _zoomLevel,
        pageSpacing: 0, // ページ間の余白を削除
        canShowScrollHead: false, // スクロールヘッドを非表示
        canShowScrollStatus: false, // スクロールステータスを非表示
        canShowPaginationDialog: false, // ページネーションダイアログを非表示
        enableDoubleTapZooming: true, // ダブルタップでズーム
        initialPageNumber: pageIndex + 1, // 1ベースのページ番号
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          // ドキュメントが読み込まれたときの処理
          print('PDFドキュメントが読み込まれました: ${details.document.pages.count} ページ');
        },
        onPageChanged: (PdfPageChangedDetails details) {
          // ページが変更されたときの処理
          print('PDFページが変更されました: ${details.newPageNumber} ページ');
        },
      ),
    );
  }

  /// 見開きページを表示するウィジェット
  Widget buildDoublePageView(
    int leftPageIndex,
    int rightPageIndex,
    bool isRightToLeft,
    BuildContext context,
  ) {
    // 読み方向に応じてページの順序を決定
    final firstPageIndex = isRightToLeft ? rightPageIndex : leftPageIndex;
    final secondPageIndex = isRightToLeft ? leftPageIndex : rightPageIndex;

    return Container(
      color: Colors.black,
      child: Row(
        children: [
          // 左ページ
          Expanded(child: buildSinglePageView(firstPageIndex, true, context)),
          // 右ページ
          Expanded(child: buildSinglePageView(secondPageIndex, true, context)),
        ],
      ),
    );
  }

  /// 画像のアスペクト比を取得
  Future<double?> getPageAspectRatio(int pageIndex) async {
    if (_pdfDocument == null) {
      await loadPdf();
    }

    if (_pdfDocument == null || pageIndex < 0 || pageIndex >= book.totalPages) {
      return null;
    }

    try {
      // PDFページを取得（0ベースのインデックス）
      final page = _pdfDocument!.pages[pageIndex];

      // ページサイズを取得
      final pageSize = page.size;
      return pageSize.width / pageSize.height;
    } catch (e) {
      print('PDFページアスペクト比取得エラー: $e');
      return null;
    }
  }
}
