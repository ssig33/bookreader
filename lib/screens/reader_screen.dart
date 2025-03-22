import 'package:flutter/material.dart';
import '../models/book.dart';
import 'reader/reader_screen.dart' as reader;

/// 本を読むためのスクリーン
/// このファイルは後方互換性のために残されています。
/// 実際の実装は lib/screens/reader/reader_screen.dart に移動されました。
class ReaderScreen extends StatelessWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // 新しい ReaderScreen を使用
    return reader.ReaderScreen(book: book);
  }
}
