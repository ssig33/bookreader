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
      expect(pageLayout.pageLayout, isA<List<int>>());

      // 初期化直後はpageLayoutは空のリスト
      // determinePageLayoutが呼ばれた後に初期化される
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      await pageLayout.determinePageLayout(
        tester.element(find.byType(Container)),
      );
      expect(pageLayout.pageLayout.length, 10); // totalPagesと同じ
    });

    testWidgets('determinePageLayout - 縦長の画像では見開きモードになる', (
      WidgetTester tester,
    ) async {
      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000, // 横長の画面
              height: 600,
            ),
          ),
        ),
      );

      // 縦長の画像のアスペクト比を設定（幅/高さ < 0.8）
      for (int i = 0; i < 10; i++) {
        mockImageLoader.setAspectRatio(i, 0.6); // 縦長の画像
      }

      // テスト対象のメソッドを実行
      await pageLayout.determinePageLayout(
        tester.element(find.byType(Container)),
      );

      // 見開きモードが有効になっていることを確認
      expect(pageLayout.useDoublePage, true);

      // ページレイアウトが正しく作成されていることを確認
      // 実際の実装では、10ページの場合、最初のページは単独で、残りの9ページが4組の見開きページになる
      // よって、合計で5レイアウトではなく、6レイアウトになる
      expect(pageLayout.pageLayout.length, 6); // 10ページが6レイアウトに
      expect(pageLayout.pageLayout[0], 0); // 最初のページは単独
      expect(pageLayout.pageLayout[1], (1 << 16) | 2); // 2ページ目と3ページ目が組み合わさっている
      expect(pageLayout.pageLayout[2], (3 << 16) | 4); // 4ページ目と5ページ目が組み合わさっている
    });

    testWidgets('determinePageLayout - 横長の画像では見開きモードにならない', (
      WidgetTester tester,
    ) async {
      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000, // 横長の画面
              height: 600,
            ),
          ),
        ),
      );

      // 横長の画像のアスペクト比を設定（幅/高さ >= 0.8）
      for (int i = 0; i < 10; i++) {
        mockImageLoader.setAspectRatio(i, 1.2); // 横長の画像
      }

      // テスト対象のメソッドを実行
      await pageLayout.determinePageLayout(
        tester.element(find.byType(Container)),
      );

      // 見開きモードが無効のままであることを確認
      expect(pageLayout.useDoublePage, false);

      // ページレイアウトが変更されていないことを確認
      expect(pageLayout.pageLayout.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(pageLayout.pageLayout[i], i);
      }
    });

    testWidgets('createDoublePageLayout - 正しいページレイアウトが作成される', (
      WidgetTester tester,
    ) async {
      // 奇数ページ数でテスト
      testBook = Book(
        id: 'test-id',
        title: 'Test Book',
        filePath: '/path/to/test.zip',
        fileType: 'zip',
        totalPages: 7,
        addedAt: DateTime.now(),
      );

      pageLayout = ReaderPageLayout(
        book: testBook,
        imageLoader: mockImageLoader,
      );

      // テスト対象のメソッドを実行
      pageLayout.createDoublePageLayout(7);

      // 正しいレイアウトが作成されていることを確認
      // 7ページの場合、最初のページは単独で、残りの6ページが3組の見開きページになる
      expect(pageLayout.pageLayout.length, 4); // 7ページが4レイアウトに
      expect(pageLayout.pageLayout[0], 0); // 最初のページは単独
      expect(pageLayout.pageLayout[1], (1 << 16) | 2); // 2ページ目と3ページ目
      expect(pageLayout.pageLayout[2], (3 << 16) | 4); // 4ページ目と5ページ目
      expect(pageLayout.pageLayout[3], (5 << 16) | 6); // 6ページ目と7ページ目

      // 偶数ページ数でテスト
      testBook = Book(
        id: 'test-id',
        title: 'Test Book',
        filePath: '/path/to/test.zip',
        fileType: 'zip',
        totalPages: 6,
        addedAt: DateTime.now(),
      );

      pageLayout = ReaderPageLayout(
        book: testBook,
        imageLoader: mockImageLoader,
      );

      // テスト対象のメソッドを実行
      pageLayout.createDoublePageLayout(6);

      // 正しいレイアウトが作成されていることを確認
      // 6ページの場合、最初のページは単独で、残りの5ページが2組の見開きページと1つの単独ページになる
      expect(pageLayout.pageLayout.length, 4); // 6ページが4レイアウトに
      expect(pageLayout.pageLayout[0], 0); // 最初のページは単独
      expect(pageLayout.pageLayout[1], (1 << 16) | 2); // 2ページ目と3ページ目
      expect(pageLayout.pageLayout[2], (3 << 16) | 4); // 4ページ目と5ページ目
      expect(pageLayout.pageLayout[3], 5); // 最後のページは単独
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
      pageLayout.createDoublePageLayout(testBook.totalPages);

      // テスト用のウィジェットをビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // 見開きページのレイアウトインデックス1は、ページ1と2の組み合わせ
                return pageLayout.buildZipPageView(1, false, context);
              },
            ),
          ),
        ),
      );

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

      // 見開きページモードでの表示を確認（右から左への読み方向）
      expect(find.text('Page 2'), findsOneWidget); // 右ページ
      expect(find.text('Page 3'), findsOneWidget); // 左ページ
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
  });
}
