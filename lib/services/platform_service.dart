import 'dart:io';
import 'package:flutter/foundation.dart';

/// プラットフォーム固有の機能を提供するサービス
class PlatformService {
  // シングルトンパターン
  static final PlatformService _instance = PlatformService._internal();

  factory PlatformService() {
    return _instance;
  }

  PlatformService._internal();

  /// 現在のプラットフォームがPDFをサポートしているかどうかを判断
  /// pdf_image_rendererライブラリはAndroidとiOSのみをサポート
  bool isPdfSupported() {
    if (kIsWeb) {
      return false; // Webはサポート外
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      return true; // AndroidとiOSはサポート
    }
    
    return false; // その他のプラットフォーム（Windows, macOS, Linux）はサポート外
  }

  /// 現在のプラットフォーム名を取得
  String getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Unknown';
    }
  }

  /// サポートされているプラットフォームのリストを取得
  List<String> getSupportedPlatforms() {
    return ['Android', 'iOS'];
  }

  /// サポートされていないプラットフォームのリストを取得
  List<String> getUnsupportedPlatforms() {
    return ['Windows', 'macOS', 'Linux', 'Web'];
  }
}