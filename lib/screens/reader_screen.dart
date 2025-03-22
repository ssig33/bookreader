import 'package:flutter/material.dart';
import '../models/book.dart';
import 'reader/reader_screen.dart' as reader;
import 'reader/pdf_reader_screen.dart';

/// 本を読むためのスクリーン
/// このファイルは後方互換性のために残されています。
/// 実際の実装は lib/screens/reader/reader_screen.dart と
/// lib/screens/reader/pdf_reader_screen.dart に移動されました。
class ReaderScreen extends StatelessWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // ファイルタイプに応じて適切なリーダーを使用
    if (book.fileType == 'pdf') {
      // PDFファイルの場合はPDFリーダーを使用
      return PdfReaderScreen(book: book);
    } else {
      // ZIPやCBZファイルの場合は従来のリーダーを使用
      return reader.ReaderScreen(book: book);
    }
  }
}
