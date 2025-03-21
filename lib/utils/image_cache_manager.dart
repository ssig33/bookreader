import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'logger.dart';

/// 画像キャッシュを管理するクラス
///
/// LRU（Least Recently Used）アルゴリズムを使用して、
/// メモリ内の画像キャッシュを効率的に管理します。
class ImageCacheManager {
  /// キャッシュの最大サイズ（画像の数）
  final int _maxSize;

  /// キャッシュされた画像データ
  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();

  /// 現在のキャッシュサイズ（バイト単位）
  int _currentSizeInBytes = 0;

  /// キャッシュの最大サイズ（バイト単位、デフォルトは100MB）
  final int _maxSizeInBytes;

  /// キャッシュヒット数（統計用）
  int _hits = 0;

  /// キャッシュミス数（統計用）
  int _misses = 0;

  /// コンストラクタ
  ///
  /// [maxSize]: キャッシュする最大画像数
  /// [maxSizeInBytes]: キャッシュの最大サイズ（バイト単位）
  ImageCacheManager({
    int maxSize = 100,
    int maxSizeInBytes = 100 * 1024 * 1024, // デフォルト100MB
  }) : _maxSize = maxSize,
       _maxSizeInBytes = maxSizeInBytes;

  /// キャッシュに画像を追加
  ///
  /// [key]: キャッシュキー
  /// [data]: 画像データ
  void addToCache(String key, Uint8List data) {
    if (data.isEmpty) {
      Logger.warning('空の画像データはキャッシュしません: $key', tag: 'ImageCache');
      return;
    }

    // 既に同じキーが存在する場合は更新
    if (_cache.containsKey(key)) {
      _currentSizeInBytes -= _cache[key]!.length;
      _cache.remove(key);
    }

    // キャッシュサイズをチェックし、必要に応じて古いエントリを削除
    _ensureCapacity(data.length);

    // 新しいエントリを追加
    _cache[key] = data;
    _currentSizeInBytes += data.length;

    Logger.debug(
      'キャッシュに追加: $key (${_formatSize(data.length)}, 合計: ${_formatSize(_currentSizeInBytes)})',
      tag: 'ImageCache',
    );
  }

  /// キャッシュから画像を取得
  ///
  /// [key]: キャッシュキー
  ///
  /// 戻り値: キャッシュされた画像データ、存在しない場合はnull
  Uint8List? getFromCache(String key) {
    final data = _cache[key];

    if (data != null) {
      // キャッシュヒット：アクセスされたエントリを最新として扱う
      _cache.remove(key);
      _cache[key] = data;
      _hits++;
      Logger.debug('キャッシュヒット: $key', tag: 'ImageCache');
      return data;
    }

    _misses++;
    Logger.debug('キャッシュミス: $key', tag: 'ImageCache');
    return null;
  }

  /// キャッシュをクリア
  void clearCache() {
    _cache.clear();
    _currentSizeInBytes = 0;
    _hits = 0;
    _misses = 0;
    Logger.debug('キャッシュをクリアしました', tag: 'ImageCache');
  }

  /// キャッシュから特定のエントリを削除
  ///
  /// [key]: 削除するキャッシュキー
  void removeFromCache(String key) {
    if (_cache.containsKey(key)) {
      _currentSizeInBytes -= _cache[key]!.length;
      _cache.remove(key);
      Logger.debug('キャッシュから削除: $key', tag: 'ImageCache');
    }
  }

  /// キャッシュの統計情報を取得
  Map<String, dynamic> getStats() {
    final hitRate =
        _hits + _misses > 0
            ? (_hits / (_hits + _misses) * 100).toStringAsFixed(2)
            : '0';

    return {
      'entries': _cache.length,
      'maxEntries': _maxSize,
      'sizeInBytes': _currentSizeInBytes,
      'maxSizeInBytes': _maxSizeInBytes,
      'sizeFormatted': _formatSize(_currentSizeInBytes),
      'maxSizeFormatted': _formatSize(_maxSizeInBytes),
      'hits': _hits,
      'misses': _misses,
      'hitRate': '$hitRate%',
    };
  }

  /// キャッシュの統計情報をログに出力
  void logStats() {
    final stats = getStats();
    Logger.debug('--- 画像キャッシュ統計 ---', tag: 'ImageCache');
    Logger.debug(
      'エントリ数: ${stats['entries']}/${stats['maxEntries']}',
      tag: 'ImageCache',
    );
    Logger.debug(
      'サイズ: ${stats['sizeFormatted']}/${stats['maxSizeFormatted']}',
      tag: 'ImageCache',
    );
    Logger.debug(
      'ヒット率: ${stats['hitRate']} (${stats['hits']}ヒット/${stats['misses']}ミス)',
      tag: 'ImageCache',
    );
    Logger.debug('------------------------', tag: 'ImageCache');
  }

  /// 新しいエントリを追加するためのスペースを確保
  void _ensureCapacity(int newDataSize) {
    // エントリ数が最大値に達した場合、または新しいデータを追加するとサイズ制限を超える場合
    while ((_cache.length >= _maxSize ||
            _currentSizeInBytes + newDataSize > _maxSizeInBytes) &&
        _cache.isNotEmpty) {
      // 最も古いエントリ（LinkedHashMapの最初のエントリ）を削除
      final oldestKey = _cache.keys.first;
      final oldestSize = _cache[oldestKey]!.length;
      _cache.remove(oldestKey);
      _currentSizeInBytes -= oldestSize;

      Logger.debug(
        'キャッシュから古いエントリを削除: $oldestKey (${_formatSize(oldestSize)})',
        tag: 'ImageCache',
      );
    }
  }

  /// バイト数を人間が読みやすい形式に変換
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
