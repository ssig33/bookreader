import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'; // For decodeImageFromList

class FileService {
  static final FileService _instance = FileService._internal();
  final Uuid _uuid = Uuid();
  late Directory _appFilesDir;
  late Directory _cacheDir;
  bool _initialized = false;

  // キャッシュ管理用のマップ
  final Map<String, List<String>> _zipImageCache = {};

  // シングルトンパターン
  factory FileService() {
    return _instance;
  }

  FileService._internal();

  /// サービスを初期化し、アプリのファイル保存ディレクトリとキャッシュディレクトリを作成
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _appFilesDir = Directory(path.join(appDir.path, 'bookreader_files'));
      _cacheDir = Directory(path.join(appDir.path, 'bookreader_cache'));

      if (!await _appFilesDir.exists()) {
        await _appFilesDir.create(recursive: true);
      }

      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize FileService: $e');
    }
  }

  /// ファイルをアプリの管理領域にコピー
  Future<String> copyFileToAppStorage(String sourcePath) async {
    if (!_initialized) await initialize();

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist: $sourcePath');
    }

    // ファイル名とUUIDを組み合わせて一意のファイル名を作成
    final extension = path.extension(sourcePath);
    final fileName = path.basenameWithoutExtension(sourcePath);
    final uniqueId = _uuid.v4().substring(0, 8);
    final newFileName = '${fileName}_$uniqueId$extension';

    final destinationPath = path.join(_appFilesDir.path, newFileName);
    final destinationFile = File(destinationPath);

    try {
      await sourceFile.copy(destinationPath);
      return destinationPath;
    } catch (e) {
      throw Exception('Failed to copy file: $e');
    }
  }

  /// ファイルを削除
  Future<void> deleteFile(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        throw Exception('Failed to delete file: $e');
      }
    }
  }

  /// ファイルが存在するか確認
  Future<bool> fileExists(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    return await file.exists();
  }

  /// アプリの管理領域のパスを取得
  Future<String> getAppStoragePath() async {
    if (!_initialized) await initialize();
    return _appFilesDir.path;
  }

  /// ファイルサイズを取得（バイト単位）
  Future<int> getFileSize(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    return await file.length();
  }

  /// 人間が読みやすいファイルサイズ形式を取得（KB, MB, GB）
  Future<String> getHumanReadableFileSize(String filePath) async {
    final bytes = await getFileSize(filePath);

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
      return '$gb GB';
    }
  }

  /// アプリの管理領域内のすべてのファイルを取得
  Future<List<FileSystemEntity>> getAllFiles() async {
    if (!_initialized) await initialize();

    final files = await _appFilesDir.list().toList();
    return files.where((entity) => entity is File).toList();
  }

  /// アプリの管理領域内のファイルの合計サイズを取得
  Future<int> getTotalStorageUsed() async {
    if (!_initialized) await initialize();

    final files = await getAllFiles();
    int totalSize = 0;

    for (var entity in files) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  /// 人間が読みやすい合計ストレージ使用量を取得
  Future<String> getHumanReadableTotalStorageUsed() async {
    final bytes = await getTotalStorageUsed();

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
      return '$gb GB';
    }
  }

  /// PDFファイルのページ数を取得
  Future<int> getPdfPageCount(String filePath) async {
    // PDF機能は現在実装されていません
    return 0;
  }

  /// ZIPファイル内の画像ファイル数を取得（ページ数として扱う）
  Future<int> getZipPageCount(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    try {
      // ZIPファイルをバイトとして読み込む
      final bytes = await file.readAsBytes();

      // ZIPアーカイブを解凍
      final archive = ZipDecoder().decodeBytes(bytes);

      // 画像ファイルのみをカウント
      final imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
      ];
      int imageCount = 0;

      for (final file in archive) {
        if (!file.isFile) continue;

        final extension = path.extension(file.name).toLowerCase();
        if (imageExtensions.contains(extension)) {
          imageCount++;
        }
      }

      return imageCount;
    } catch (e) {
      print('ZIPページ数取得エラー: $e');
      return 0; // エラーの場合は0を返す
    }
  }

  /// ファイルタイプに応じたページ数を取得
  Future<int> getPageCount(String filePath, String fileType) async {
    if (fileType == 'zip' || fileType == 'cbz') {
      return await getZipPageCount(filePath);
    } else {
      throw Exception('Unsupported file type: $fileType');
    }
  }

  /// ZIPファイルから画像を抽出してキャッシュする
  Future<List<String>> extractAndCacheZipImages(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    // すでにキャッシュがある場合はそれを返す
    if (_zipImageCache.containsKey(filePath)) {
      return _zipImageCache[filePath]!;
    }

    try {
      // ZIPファイルをバイトとして読み込む
      final bytes = await file.readAsBytes();

      // ZIPアーカイブを解凍
      final archive = ZipDecoder().decodeBytes(bytes);

      // 画像ファイルのみを抽出
      final imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
      ];
      final List<ArchiveFile> imageFiles = [];

      for (final file in archive) {
        if (!file.isFile) continue;

        final extension = path.extension(file.name).toLowerCase();
        if (imageExtensions.contains(extension)) {
          imageFiles.add(file);
        }
      }

      // ファイル名でソート（自然順ソート）
      imageFiles.sort((a, b) => _naturalCompare(a.name, b.name));

      // 画像をキャッシュディレクトリに保存
      final String bookId = path.basenameWithoutExtension(filePath);
      final String cacheDirPath = path.join(_cacheDir.path, bookId);
      final cacheDir = Directory(cacheDirPath);

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      } else {
        // 既存のキャッシュをクリア
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }

      // 画像ファイルをキャッシュに保存
      final List<String> imagePaths = [];
      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final imageData = imageFile.content as List<int>;
        final imagePath = path.join(
          cacheDirPath,
          '${i.toString().padLeft(5, '0')}.dat',
        );

        await File(imagePath).writeAsBytes(imageData);
        imagePaths.add(imagePath);
      }

      // キャッシュマップに保存
      _zipImageCache[filePath] = imagePaths;

      return imagePaths;
    } catch (e) {
      print('ZIP画像抽出エラー: $e');
      return [];
    }
  }

  /// キャッシュされたZIP画像を取得
  Future<Uint8List?> getZipImageData(String filePath, int pageIndex) async {
    if (!_initialized) await initialize();

    try {
      // まだキャッシュされていない場合は抽出
      if (!_zipImageCache.containsKey(filePath)) {
        await extractAndCacheZipImages(filePath);
      }

      // キャッシュから画像パスを取得
      final imagePaths = _zipImageCache[filePath];
      if (imagePaths == null || pageIndex >= imagePaths.length) {
        return null;
      }

      // 画像データを読み込む
      final imageFile = File(imagePaths[pageIndex]);
      if (await imageFile.exists()) {
        return await imageFile.readAsBytes();
      }

      return null;
    } catch (e) {
      print('ZIP画像取得エラー: $e');
      return null;
    }
  }

  /// 画像のアスペクト比を取得
  Future<double?> getImageAspectRatio(Uint8List imageData) async {
    try {
      final decodedImage = await decodeImageFromList(imageData);
      return decodedImage.width / decodedImage.height;
    } catch (e) {
      print('画像アスペクト比取得エラー: $e');
      return null;
    }
  }

  /// ファイルをバイト配列として読み込む
  Future<Uint8List> getFileBytes(String filePath) async {
    if (!_initialized) await initialize();

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    try {
      return await file.readAsBytes();
    } catch (e) {
      throw Exception('Failed to read file bytes: $e');
    }
  }

  /// キャッシュをクリア
  Future<void> clearCache() async {
    if (!_initialized) await initialize();

    try {
      _zipImageCache.clear();

      if (await _cacheDir.exists()) {
        final entities = await _cacheDir.list().toList();
        for (var entity in entities) {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('キャッシュクリアエラー: $e');
    }
  }

  /// 特定の本のキャッシュをクリア
  Future<void> clearBookCache(String filePath) async {
    if (!_initialized) await initialize();

    try {
      _zipImageCache.remove(filePath);

      final String bookId = path.basenameWithoutExtension(filePath);
      final String cacheDirPath = path.join(_cacheDir.path, bookId);
      final cacheDir = Directory(cacheDirPath);

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('本キャッシュクリアエラー: $e');
    }
  }

  /// 自然順ソート（数字を考慮したソート）
  int _naturalCompare(String a, String b) {
    final aChunks = _splitByDigits(a);
    final bChunks = _splitByDigits(b);

    final minLength = math.min(aChunks.length, bChunks.length);

    for (var i = 0; i < minLength; i++) {
      final aChunk = aChunks[i];
      final bChunk = bChunks[i];

      // 両方数値の場合は数値として比較
      if (int.tryParse(aChunk) != null && int.tryParse(bChunk) != null) {
        final aNum = int.parse(aChunk);
        final bNum = int.parse(bChunk);
        final comp = aNum.compareTo(bNum);
        if (comp != 0) return comp;
      } else {
        // それ以外は文字列として比較
        final comp = aChunk.compareTo(bChunk);
        if (comp != 0) return comp;
      }
    }

    // 長さが異なる場合は短い方を優先
    return aChunks.length.compareTo(bChunks.length);
  }

  /// 文字列を数字と非数字に分割
  List<String> _splitByDigits(String input) {
    final result = <String>[];
    String currentChunk = '';
    bool isDigit = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final charIsDigit = int.tryParse(char) != null;

      if (i == 0) {
        currentChunk = char;
        isDigit = charIsDigit;
      } else if (charIsDigit == isDigit) {
        currentChunk += char;
      } else {
        result.add(currentChunk);
        currentChunk = char;
        isDigit = charIsDigit;
      }
    }

    if (currentChunk.isNotEmpty) {
      result.add(currentChunk);
    }

    return result;
  }
}
