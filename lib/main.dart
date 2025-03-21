import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/file_service.dart';
import 'services/book_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // アプリのファイル管理サービスを初期化
  await FileService().initialize();

  // 本サービスを初期化し、既存の本のページ数を更新
  final bookService = BookService();
  await bookService.initialize();
  await bookService.updateAllBooksPageCount();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
