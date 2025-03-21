# Reader Screen Flickering Issue - 分析と解決策

## 問題の概要

**要求**: reader_screenに注目してほしいんだけど、これちらつくんだよね。画像がスクロールで遷移したあとちらつくわけ。なんか想像できる？

画像のスクロール遷移後にちらつく問題が報告されています。ユーザーがページをスクロールして次のページに移動した後、画面が一瞬ちらつくという現象が発生しています。

## コード分析

関連するファイルを分析した結果、以下のコンポーネントが画像表示とページ遷移に関わっています：

1. **ReaderScreen** (`lib/screens/reader/reader_screen.dart`)
   - PageView.builderを使用してページ遷移を管理
   - ページ変更時にsetState()を呼び出して状態を更新

2. **ReaderImageLoader** (`lib/screens/reader/reader_image_loader.dart`)
   - FutureBuilderを使用して非同期で画像を読み込む
   - 各ページの表示時に_fileService.getZipImageData()を呼び出して画像データを取得

3. **ReaderPageLayout** (`lib/screens/reader/reader_page_layout.dart`)
   - 単一ページと見開きページのレイアウトを管理
   - 画面のアスペクト比と画像のアスペクト比に基づいてレイアウトを決定

4. **ReaderNavigation** (`lib/screens/reader/reader_navigation.dart`)
   - ページ間のナビゲーションを管理
   - previousPage/nextPage（アニメーション付き）とjumpToPage（即時）の両方の遷移方法を使用

5. **FileService** (`lib/services/file_service.dart`)
   - ZIPファイルから画像を抽出してキャッシュ
   - 画像パスのみをキャッシュし、実際の画像データは都度ディスクから読み込む

## 考えられる原因

1. **非同期画像読み込み**：
   - 現在の実装では、ページが表示されるたびに`FutureBuilder`を使って画像を非同期で読み込んでいます。
   - ページ遷移中に、画像が完全に読み込まれる前に一瞬`CircularProgressIndicator`が表示されることがちらつきの原因になっている可能性があります。

2. **キャッシュの最適化不足**：
   - `FileService`の`_zipImageCache`は画像データ自体ではなく、抽出された画像のパスのみをキャッシュしています。
   - ページが表示されるたびに、ディスクから画像ファイルを読み込む必要があり、これが遅延やちらつきを引き起こす可能性があります。

3. **ページ遷移のアニメーション**：
   - `PageView`ウィジェットは300msの`easeInOut`アニメーションを使用しています。
   - このアニメーション中に次のページの画像が完全に読み込まれていないと、ちらつきが発生する可能性があります。

4. **プリロードの欠如**：
   - 現在の実装では隣接するページをプリロードしていません。必要になった時点でのみ読み込むため、遷移中にちらつきが発生する可能性があります。

5. **jumpToPageの使用**：
   - `navigateToRelativePage`メソッドでは`jumpToPage`を使用しており、これはアニメーションなしで即座にページを切り替えます。
   - この即時切り替えが、特に画像が完全に読み込まれる前に行われると、ちらつきの原因になる可能性があります。

## 解決策の提案

1. **画像のプリロード実装**：
   - 現在表示しているページの前後のページをバックグラウンドで事前に読み込むことで、ページ遷移時のちらつきを減らせます。
   - `PageView`の`onPageChanged`イベントで、次の数ページを事前に読み込むロジックを追加できます。

   ```dart
   // ReaderScreen.dartのonPageChangedイベントに追加
   onPageChanged: (int page) {
     setState(() {
       _currentPage = page;
     });
     _navigation?.updateLastReadPage(page);
     
     // 次の数ページをプリロード
     _preloadAdjacentPages(page);
   },
   
   // プリロード用のメソッド
   void _preloadAdjacentPages(int currentPage) {
     // 現在のページの前後2ページをプリロード
     final pagesToPreload = [
       currentPage - 2,
       currentPage - 1,
       currentPage + 1,
       currentPage + 2,
     ];
     
     for (final page in pagesToPreload) {
       if (page >= 0 && page < widget.book.totalPages) {
         _imageLoader.preloadPage(page);
       }
     }
   }
   ```

2. **メモリ内画像キャッシュの強化**：
   - 現在は画像のパスのみをキャッシュしていますが、実際の画像データ（`Uint8List`）をメモリにキャッシュすることで、ディスクからの読み込み時間を削減できます。
   - LRU（Least Recently Used）キャッシュを実装して、メモリ使用量を管理しながら頻繁にアクセスされる画像をメモリに保持できます。

   ```dart
   // ReaderImageLoader.dartに追加
   // メモリ内画像キャッシュ
   final Map<int, Uint8List> _imageCache = {};
   final int _maxCacheSize = 10; // キャッシュするページ数
   final List<int> _cacheOrder = []; // LRUキャッシュの順序を管理
   
   // 画像をプリロードしてキャッシュに保存
   Future<void> preloadPage(int pageIndex) async {
     if (_imageCache.containsKey(pageIndex)) {
       // すでにキャッシュにある場合は、キャッシュ順序を更新
       _cacheOrder.remove(pageIndex);
       _cacheOrder.add(pageIndex);
       return;
     }
     
     final imageData = await _fileService.getZipImageData(
       book.filePath,
       pageIndex,
     );
     
     if (imageData != null) {
       // キャッシュが最大サイズに達した場合、最も古いエントリを削除
       if (_cacheOrder.length >= _maxCacheSize && _cacheOrder.isNotEmpty) {
         final oldestPage = _cacheOrder.removeAt(0);
         _imageCache.remove(oldestPage);
       }
       
       // 新しい画像をキャッシュに追加
       _imageCache[pageIndex] = imageData;
       _cacheOrder.add(pageIndex);
     }
   }
   
   // キャッシュから画像を取得（なければディスクから読み込む）
   Future<Uint8List?> getImageData(int pageIndex) async {
     // キャッシュにある場合はそれを返す
     if (_imageCache.containsKey(pageIndex)) {
       // キャッシュ順序を更新
       _cacheOrder.remove(pageIndex);
       _cacheOrder.add(pageIndex);
       return _imageCache[pageIndex];
     }
     
     // キャッシュにない場合はディスクから読み込む
     return await _fileService.getZipImageData(book.filePath, pageIndex);
   }
   ```

3. **gaplessPlaybackの確認**：
   - `Image.memory`ウィジェットには既に`gaplessPlayback: true`が設定されていますが、これが正しく機能しているか確認してください。

4. **PageViewの最適化**：
   - `PageView.builder`の代わりに、カスタムのページ遷移アニメーションを実装することで、画像の読み込みとアニメーションをより細かく制御できます。
   - または、`PageView`の`viewportFraction`プロパティを調整して、次のページを部分的に表示することで、ユーザーに次のページが読み込まれていることを視覚的に示すことができます。

   ```dart
   // ReaderScreen.dartのPageView.builderを修正
   PageView.builder(
     controller: _pageController,
     reverse: _isRightToLeft,
     viewportFraction: 0.99, // わずかに次のページを表示
     onPageChanged: (int page) {
       setState(() {
         _currentPage = page;
       });
       _navigation?.updateLastReadPage(page);
       _preloadAdjacentPages(page);
     },
     // ...残りのコード
   ),
   ```

5. **setState呼び出しの最適化**：
   - `onPageChanged`内の`setState`呼び出しを最適化して、必要な部分のみを更新するようにします。

6. **画像表示の最適化**：
   - 現在の画像が消える前に次の画像が読み込まれるように、オーバーレイ表示やクロスフェード効果を実装することを検討してください。
   - `AnimatedSwitcher`や`FadeTransition`を使用して、画像間のスムーズな遷移を実現できます。

   ```dart
   // ReaderImageLoader.dartのbuildSinglePageViewメソッドを修正
   Widget buildSinglePageView(
     int pageIndex,
     bool useDoublePage,
     BuildContext context,
   ) {
     return FutureBuilder<Uint8List?>(
       // getImageDataを使用してキャッシュから画像を取得
       future: getImageData(pageIndex),
       builder: (context, snapshot) {
         // ...既存のコード
         
         // 画像を表示（AnimatedSwitcherでスムーズな遷移を実現）
         return Container(
           color: Colors.black,
           constraints: useDoublePage
               ? BoxConstraints(
                   maxWidth: MediaQuery.of(context).size.width / 2,
                 )
               : null,
           child: AnimatedSwitcher(
             duration: const Duration(milliseconds: 200),
             child: Image.memory(
               snapshot.data!,
               key: ValueKey<int>(pageIndex), // キーを指定して異なる画像と認識させる
               fit: BoxFit.contain,
               gaplessPlayback: true,
             ),
           ),
         );
       },
     );
   }
   ```

## 推奨される実装アプローチ

最も効果的な解決策は、画像のプリロードとメモリ内キャッシュの強化を組み合わせることです。これにより、ページ遷移時に画像が既にメモリに読み込まれている状態になり、ちらつきを大幅に減らすことができるでしょう。

実装の優先順位：

1. メモリ内画像キャッシュの実装
2. 隣接ページのプリロード機能の追加
3. AnimatedSwitcherを使用した画像遷移の最適化
4. PageViewの設定調整（必要に応じて）

これらの改善を実装することで、ページ遷移時のちらつきを大幅に軽減し、よりスムーズな読書体験を提供できるようになります。