// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book/screens/home_screen.dart';

// サービスの初期化をモック化するためのテスト用のMyAppウィジェット
class TestableMyApp extends StatelessWidget {
  const TestableMyApp({super.key});

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

void main() {
  testWidgets('アプリが正常に起動し、ホーム画面が表示される', (WidgetTester tester) async {
    // テスト用のアプリウィジェットをビルド
    await tester.pumpWidget(const TestableMyApp());

    // ホーム画面のタイトルが表示されていることを確認
    expect(find.text('ブックリーダー'), findsOneWidget);

    // 追加ボタンが表示されていることを確認（FloatingActionButtonとして）
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 初期状態では「ファイルがありません」というメッセージが表示されていることを確認
    expect(find.text('ファイルがありません'), findsOneWidget);
  });
}
