import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _defaultBaseUrl = 'http://127.0.0.1:8000';

  static String get baseUrl {
    if (kIsWeb) {
      return _defaultBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
        return _defaultBaseUrl;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return _defaultBaseUrl;
      default:
        return _defaultBaseUrl;
    }
  }
}