import 'package:flutter/foundation.dart';

/// アプリケーション全体で使用するロガークラス
class Logger {
  /// ロギングが有効かどうか
  static bool _enabled = true;

  /// デバッグモードでのみログを出力するかどうか
  static bool _debugOnly = true;

  /// ロガーの設定を行う
  static void configure({bool enabled = true, bool debugOnly = true}) {
    _enabled = enabled;
    _debugOnly = debugOnly;
  }

  /// 情報ログを出力する
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// デバッグログを出力する
  static void debug(String message, {String? tag}) {
    _log('DEBUG', message, tag: tag);
  }

  /// 警告ログを出力する
  static void warning(String message, {String? tag}) {
    _log('WARNING', message, tag: tag);
  }

  /// エラーログを出力する
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', message, tag: tag);
    if (error != null) {
      _log('ERROR', 'Error details: $error', tag: tag);
    }
    if (stackTrace != null) {
      _log('ERROR', 'Stack trace: $stackTrace', tag: tag);
    }
  }

  /// ログを出力する内部メソッド
  static void _log(String level, String message, {String? tag}) {
    if (!_enabled) return;
    if (_debugOnly && !kDebugMode) return;

    final timestamp = DateTime.now().toString().substring(0, 19);
    final tagStr = tag != null ? '[$tag]' : '';
    print('$timestamp [$level]$tagStr $message');
  }
}
