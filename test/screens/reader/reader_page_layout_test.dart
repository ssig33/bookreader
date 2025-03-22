import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book/models/book.dart';
import 'package:book/screens/reader/reader_image_loader.dart';
import 'package:book/screens/reader/reader_page_layout.dart';

// ReaderImageLoaderのモック
class MockReaderImageLoader extends ReaderImageLoader {
  MockReaderImageLoader({required super.book});

  bool _isLoading = false;
  final Map<int, double> _aspectRatios = {};

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) {
    _isLoading = value;
  }

  void setAspectRatio(int pageIndex, double aspectRatio) {
    _aspectRatios[pageIndex] = aspectRatio;
  }

  @override
  Future<double?> getImageAspectRatio(int pageIndex) async {
    return _aspectRatios[pageIndex];
  }

  @override
  Widget buildSinglePageView(
    int pageIndex,
    bool useDoublePage,
    BuildContext context,
  ) {
    return Container(
      width: useDoublePage ? 100 : 200,
      height: 300,
      color: Colors.grey,
      child: Center(child: Text('Page ${pageIndex + 1}')),
    );
  }
}

void main() {
  late Book testBook;
  late MockReaderImageLoader mockImageLoader;
  late ReaderPageLayout pageLayout;

  setUp(() {
    // テスト用のBookオブジェクトを作成
    testBook = Book(
      id: 'test-id',
      title: 'Test Book',
      filePath: '/path/to/test.zip',
      fileType: 'zip',
      totalPages: 10,
      addedAt: DateTime.now(),
    );

    // モックのReaderImageLoaderを作成
    mockImageLoader = MockReaderImageLoader(book: testBook);

    // テスト対象のReaderPageLayoutを作成
    pageLayout = ReaderPageLayout(book: testBook, imageLoader: mockImageLoader);
  });

  group('ReaderPageLayout', () {
    testWidgets('初期化時にはシングルページモードである', (WidgetTester tester) async {
      expect(pageLayout.useDoublePage, false);

      // 初期化直後はシングルページモード
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      await pageLayout.determineDoublePage(
        tester.element(find.byType(Container)),
      );

      // 初期状態では見開きモードは無効
      expect(pageLayout.useDoublePage, false);
    });

    testWidgets('determineDoublePage - 縦長の画像では見開きモードになる', (
      WidgetTester tester,
    ) async {
      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000, // 横長の画面
              height: 600,
              child: Container(),
            ),
          ),
        ),
      );

      // 縦長の画像のアスペクト比を設定（幅/高さ < 0.8）
      for (int i = 0; i < 10; i++) {
        mockImageLoader.setAspectRatio(i, 0.6); // 縦長の画像
      }

      // テスト対象のメソッドを実行
      await pageLayout.determineDoublePage(
        tester.element(find.byType(Container)),
      );

      // 見開きモードが有効になっていることを確認
      expect(pageLayout.useDoublePage, true);
    });

    testWidgets('determineDoublePage - 横長の画像では見開きモードにならない', (
      WidgetTester tester,
    ) async {
      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000, // 横長の画面
              height: 600,
              child: Container(),
            ),
          ),
        ),
      );

      // 横長の画像のアスペクト比を設定（幅/高さ >= 0.8）
      for (int i = 0; i < 10; i++) {
        mockImageLoader.setAspectRatio(i, 1.2); // 横長の画像
      }

      // テスト対象のメソッドを実行
      await pageLayout.determineDoublePage(
        tester.element(find.byType(Container)),
      );

      // 見開きモードが無効のままであることを確認
      expect(pageLayout.useDoublePage, false);
    });

    testWidgets('buildZipPageView - シングルページモードでの表示', (
      WidgetTester tester,
    ) async {
      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return pageLayout.buildZipPageView(2, false, context);
              },
            ),
          ),
        ),
      );

      // シングルページモードでの表示を確認
      expect(
        find.text('Page 3'),
        findsOneWidget,
      ); // 0-indexedなので、pageIndex 2は3ページ目
    });

    testWidgets('buildZipPageView - 見開きページモードでの表示', (
      WidgetTester tester,
    ) async {
      // 見開きモードを有効にする
      pageLayout.useDoublePage = true;

      // 縦長の画像のアスペクト比を設定
      mockImageLoader.setAspectRatio(1, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(2, 0.6); // 縦長の画像

      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // ページ1を表示（見開きでページ2も表示される）
                return pageLayout.buildZipPageView(1, false, context);
              },
            ),
          ),
        ),
      );

      // FutureBuilderの完了を待つ
      await tester.pumpAndSettle();

      // 見開きページモードでの表示を確認（左から右への読み方向）
      expect(find.text('Page 2'), findsOneWidget); // 左ページ
      expect(find.text('Page 3'), findsOneWidget); // 右ページ

      // 右から左への読み方向でテスト
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return pageLayout.buildZipPageView(1, true, context);
              },
            ),
          ),
        ),
      );

      // FutureBuilderの完了を待つ
      await tester.pumpAndSettle();

      // 見開きページモードでの表示を確認（右から左への読み方向）
      expect(find.text('Page 2'), findsOneWidget); // 右ページ
      expect(find.text('Page 3'), findsOneWidget); // 左ページ
    });

    testWidgets('buildZipPageView - 最初のページは単独表示', (WidgetTester tester) async {
      // 見開きモードを有効にする
      pageLayout.useDoublePage = true;

      // 縦長の画像のアスペクト比を設定
      mockImageLoader.setAspectRatio(0, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(1, 0.6); // 縦長の画像

      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // 最初のページを表示
                return pageLayout.buildZipPageView(0, false, context);
              },
            ),
          ),
        ),
      );

      // FutureBuilderの完了を待つ
      await tester.pumpAndSettle();

      // 最初のページは単独表示されることを確認
      expect(find.text('Page 1'), findsOneWidget); // 最初のページ
      expect(find.text('Page 2'), findsNothing); // 次のページは表示されない
    });

    testWidgets('buildZipPageView - 横長のページは単独表示', (WidgetTester tester) async {
      // 見開きモードを有効にする
      pageLayout.useDoublePage = true;

      // 横長の画像のアスペクト比を設定
      mockImageLoader.setAspectRatio(1, 1.2); // 横長の画像
      mockImageLoader.setAspectRatio(2, 0.6); // 縦長の画像

      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // 横長のページを表示
                return pageLayout.buildZipPageView(1, false, context);
              },
            ),
          ),
        ),
      );

      // FutureBuilderの完了を待つ
      await tester.pumpAndSettle();

      // 横長のページは単独表示されることを確認
      expect(find.text('Page 2'), findsOneWidget); // 現在のページ
      expect(find.text('Page 3'), findsNothing); // 次のページは表示されない
    });

    testWidgets('buildZipPageView - ローディング中の表示', (WidgetTester tester) async {
      // ローディング中に設定
      mockImageLoader.isLoading = true;

      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return pageLayout.buildZipPageView(0, false, context);
              },
            ),
          ),
        ),
      );

      // ローディングインジケータが表示されていることを確認
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('getNextPageIndex - 見開きモードでの次のページ', (
      WidgetTester tester,
    ) async {
      // 見開きモードを有効にする
      pageLayout.useDoublePage = true;

      // 縦長の画像のアスペクト比を設定
      mockImageLoader.setAspectRatio(1, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(2, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(3, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(4, 0.6); // 縦長の画像

      // 次のページインデックスを取得
      final nextPage = await pageLayout.getNextPageIndex(1);

      // 見開きページの場合は2ページ進むことを確認
      expect(nextPage, 3);
    });

    testWidgets('getPreviousPageIndex - 見開きモードでの前のページ', (
      WidgetTester tester,
    ) async {
      // 見開きモードを有効にする
      pageLayout.useDoublePage = true;

      // 縦長の画像のアスペクト比を設定
      mockImageLoader.setAspectRatio(1, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(2, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(3, 0.6); // 縦長の画像
      mockImageLoader.setAspectRatio(4, 0.6); // 縦長の画像

      // 前のページインデックスを取得
      final prevPage = await pageLayout.getPreviousPageIndex(3);

      // 見開きページの場合は2ページ戻ることを確認
      expect(prevPage, 1);
    });
  });
}
