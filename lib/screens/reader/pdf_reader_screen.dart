import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../models/book.dart';

/// PDFを読むためのスクリーン
class PdfReaderScreen extends StatefulWidget {
  final Book book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  /// Page reading order; true to L-to-R that is commonly used by books like manga or such
  bool _isRightToLeftReadingOrder = false;

  /// Use the first page as cover page
  bool _needCoverPage = true;

  /// 見開きモードを使用するかどうか
  bool _useDoublePage = false;

  @override
  void initState() {
    super.initState();
    _checkPdfFile();
  }

  Future<void> _checkPdfFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // PDFファイルを確認
      final file = File(widget.book.filePath);
      if (!await file.exists()) {
        throw Exception('PDFファイルが見つかりません');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 画面のアスペクト比を取得
    final screenSize = MediaQuery.of(context).size;
    final screenAspect = screenSize.width / screenSize.height;

    // 横長の画面の場合のみ見開き表示を有効にする
    _useDoublePage = screenAspect >= 1.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          // 読み方向切り替えボタン
          IconButton(
            icon: Icon(
              _isRightToLeftReadingOrder
                  ? Icons.format_textdirection_r_to_l
                  : Icons.format_textdirection_l_to_r,
            ),
            onPressed: () {
              setState(() {
                _isRightToLeftReadingOrder = !_isRightToLeftReadingOrder;
              });
            },
            tooltip: _isRightToLeftReadingOrder ? '右→左' : '左→右',
          ),
          // 表紙ページ切り替えボタン
          IconButton(
            icon: Icon(_needCoverPage ? Icons.book : Icons.book_online),
            onPressed: () {
              setState(() {
                _needCoverPage = !_needCoverPage;
              });
            },
            tooltip: _needCoverPage ? '表紙ページあり' : '表紙ページなし',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'PDFの読み込みに失敗しました',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // PDFを表示
    if (_useDoublePage) {
      // 横長の画面の場合は見開きレイアウトを使用
      return PdfViewer.file(
        widget.book.filePath,
        params: PdfViewerParams(
          layoutPages: (pages, params) {
            // 画面サイズを取得
            final screenSize = MediaQuery.of(context).size;
            // 余白を考慮した実際の表示領域
            final viewportWidth = screenSize.width - (params.margin * 3);
            final viewportHeight = screenSize.height - (params.margin * 2);

            // 最大ページ幅を計算
            final maxPageWidth = pages.fold(
              0.0,
              (prev, page) => max(prev, page.width),
            );

            // 見開きページの合計幅（2ページ分）
            final totalSpreadWidth = maxPageWidth * 2;

            // スケーリング係数を計算（幅に基づく）
            double scaleFactor = viewportWidth / totalSpreadWidth;

            final pageLayouts = <Rect>[];
            final offset = _needCoverPage ? 1 : 0;
            double y = params.margin;

            // ページペアごとの最大高さを事前計算
            final pairMaxHeights = <double>[];
            for (int i = 0; i < pages.length; i += 2) {
              final page1 = pages[i];
              final page2 = (i + 1 < pages.length) ? pages[i + 1] : null;
              final maxHeight =
                  page2 != null
                      ? max(page1.height, page2.height)
                      : page1.height;
              pairMaxHeights.add(maxHeight);
            }

            // 全ページペアの合計高さを計算
            final totalContentHeight = pairMaxHeights.fold(
              0.0,
              (prev, height) => prev + height + params.margin,
            );

            // 高さに基づくスケーリング係数を計算
            final heightScaleFactor = viewportHeight / totalContentHeight;

            // 幅と高さの両方に基づいて、より小さいスケーリング係数を選択
            // これにより、コンテンツが画面に収まることを保証
            scaleFactor = min(scaleFactor, heightScaleFactor);

            // スケーリングされたページ幅
            final scaledMaxPageWidth = maxPageWidth * scaleFactor;

            for (int i = 0; i < pages.length; i++) {
              final page = pages[i];
              final pos = i + offset;
              final isLeft =
                  _isRightToLeftReadingOrder ? (pos & 1) == 1 : (pos & 1) == 0;

              final otherSide = (pos ^ 1) - offset;
              final h =
                  0 <= otherSide && otherSide < pages.length
                      ? max(page.height, pages[otherSide].height)
                      : page.height;

              // ページをスケーリング
              final scaledPageWidth = page.width * scaleFactor;
              final scaledPageHeight = page.height * scaleFactor;
              final scaledH = h * scaleFactor;

              pageLayouts.add(
                Rect.fromLTWH(
                  isLeft
                      ? scaledMaxPageWidth + params.margin - scaledPageWidth
                      : params.margin * 2 + scaledMaxPageWidth,
                  y + (scaledH - scaledPageHeight) / 2,
                  scaledPageWidth,
                  scaledPageHeight,
                ),
              );
              if (pos & 1 == 1 || i + 1 == pages.length) {
                y += scaledH + params.margin;
              }
            }

            return PdfPageLayout(
              pageLayouts: pageLayouts,
              documentSize: Size(
                (params.margin + scaledMaxPageWidth) * 2 + params.margin,
                y,
              ),
            );
          },
        ),
      );
    } else {
      // 縦長の画面の場合は通常のレイアウトを使用
      return PdfViewer.file(widget.book.filePath);
    }
  }
}
