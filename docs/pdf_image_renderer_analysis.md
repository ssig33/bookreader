# pdf_image_renderer Library Analysis - 実装ノート

## Core Functionality Map

- **Primary Purpose**: Convert PDF pages to bitmap images
- **Implementation**: Uses native renderers on each platform
- **Platform Support**:
  - ✅ Android
  - ✅ iOS
  - ❌ Windows
  - ❌ macOS
  - ❌ Linux
  - ❌ Web

## 実装ステータス

- **実装日**: 2025年3月23日
- **実装者**: Roo
- **実装状況**:
  - ✅ PDFファイルのページ数取得
  - ✅ PDFページの画像への変換
  - ✅ プラットフォーム検出によるUI制限（Android/iOSのみPDF追加可能）
  - ✅ リーダー画面でのPDF表示

## プラットフォーム対応

このライブラリはAndroidとiOSのみをサポートしています。アプリケーションでは、プラットフォーム検出を行い、サポートされているプラットフォームでのみPDFファイルの追加を許可しています。

- **サポート済み**: Android, iOS
- **サポート外**: Windows, macOS, Linux, Web

サポートされていないプラットフォームでPDFファイルを追加しようとすると、エラーメッセージが表示されます。

## API Structure

```dart
// Main class that handles PDF rendering
class PdfImageRenderer {
  // Constructor requires a file path
  PdfImageRenderer({required String path});
  
  // Core lifecycle methods
  Future<void> open({String? password});
  Future<void> close();
  
  // Page handling
  Future<int> getPageCount();
  Future<void> openPage({required int pageIndex});
  Future<void> closePage({required int pageIndex});
  
  // Size information
  Future<Size> getPageSize({required int pageIndex});
  
  // The primary rendering method
  Future<Uint8List?> renderPage({
    required int pageIndex,
    required int x,
    required int y,
    required int width,
    required int height,
    required double scale,
    required Color background,
  });
}
```

## Execution Flow

1. **Initialization**: Create instance with PDF file path
2. **Document Opening**: Call `open()` (optionally with password)
3. **Page Management**:
   - Get total pages with `getPageCount()`
   - Open specific page with `openPage(pageIndex: n)`
   - Get page dimensions with `getPageSize(pageIndex: n)`
4. **Rendering**: Convert page to image with `renderPage()`
5. **Cleanup**: Close page with `closePage()`, then document with `close()`

## Implementation Details

- Uses platform channels to communicate with native code
- Android: Uses Android's PdfRenderer API
- iOS: Uses CGPDFDocument from Core Graphics
- Returns images as raw Uint8List (bytes) that can be used with Flutter's Image widget

## Usage Pattern Analysis

```dart
// Typical usage pattern
final pdf = PdfImageRenderer(path: '/path/to/file.pdf');

// Initialize
await pdf.open();
final pageCount = await pdf.getPageCount();

// Process each page
for (int i = 0; i < pageCount; i++) {
  // Open page
  await pdf.openPage(pageIndex: i);
  
  // Get dimensions
  final size = await pdf.getPageSize(pageIndex: i);
  
  // Render to image
  final image = await pdf.renderPage(
    pageIndex: i,
    x: 0,
    y: 0,
    width: size.width.toInt(),
    height: size.height.toInt(),
    scale: 1.0,
    background: Colors.white,
  );
  
  // Close page when done
  await pdf.closePage(pageIndex: i);
  
  // Use image data (Uint8List)
  if (image != null) {
    // Process image bytes
    // Example: save to file, display in UI, etc.
  }
}

// Close document when completely done
pdf.close();
```

## Performance Considerations

- **Memory Management**: 
  - Each page should be closed after rendering to free memory
  - The entire document should be closed when no longer needed
  
- **Rendering Options**:
  - `scale` parameter affects quality and memory usage
  - Higher scale = better quality but more memory
  - Lower scale = lower quality but less memory
  
- **Concurrency**:
  - Operations are asynchronous but should be handled sequentially for a single document
  - Multiple documents can be processed in parallel

## Error Handling Patterns

```dart
try {
  final pdf = PdfImageRenderer(path: filePath);
  await pdf.open();
  // Additional operations
} catch (e) {
  // Handle errors:
  // - File not found
  // - Invalid PDF format
  // - Password protected (when no password provided)
  // - Insufficient permissions
} finally {
  // Ensure resources are released
  pdf.close();
}
```

## Platform-Specific Limitations

- **Android**:
  - Requires minSdkVersion 21 (Android 5.0) or higher
  - Uses Android's PdfRenderer API (added in API level 21)
  
- **iOS**:
  - Uses Core Graphics for rendering
  - Password protection supported in iOS 15+ only
  
- **Desktop/Web**:
  - Not supported due to lack of native PDF rendering implementation

## Integration with Flutter Widgets

```dart
// Display rendered PDF page in Flutter UI
Widget build(BuildContext context) {
  return image != null 
    ? Image.memory(image!) 
    : CircularProgressIndicator();
}
```

## Comparison with Alternative Libraries

| Feature | pdf_image_renderer | flutter_pdfview | syncfusion_flutter_pdfviewer |
|---------|-------------------|-----------------|------------------------------|
| Native rendering | ✅ | ✅ | ✅ |
| Platform support | Android, iOS | Android, iOS, Web | All platforms |
| Memory efficiency | High (page by page) | Medium | Medium |
| Customization | High (raw images) | Low | Medium |
| UI components | None (just images) | Built-in viewer | Built-in viewer |
| License | Open source | Open source | Commercial |

## Internal Data Flow

1. Dart code calls methods on PdfImageRenderer
2. Method channel invokes native code (Java/Kotlin on Android, Swift/Objective-C on iOS)
3. Native code uses platform PDF APIs to render pages
4. Rendered bitmap is converted to byte array
5. Byte array is passed back through method channel to Dart
6. Dart code receives Uint8List that can be used with Flutter's Image widget

## Memory Model

- PDF document is loaded in native memory
- Individual pages are loaded only when needed
- Rendered images are transferred to Dart memory as Uint8List
- Explicit resource management required (open/close)