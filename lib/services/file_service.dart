import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  final Uuid _uuid = Uuid();
  late Directory _appFilesDir;
  bool _initialized = false;

  // シングルトンパターン
  factory FileService() {
    return _instance;
  }

  FileService._internal();

  /// サービスを初期化し、アプリのファイル保存ディレクトリを作成
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _appFilesDir = Directory(path.join(appDir.path, 'bookreader_files'));

      if (!await _appFilesDir.exists()) {
        await _appFilesDir.create(recursive: true);
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
}
