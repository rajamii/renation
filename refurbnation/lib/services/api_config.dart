import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _localUrl = 'http://localhost:8000/api';
  static const String _prodUrl = 'https://refurbnation.onrender.com/api';

  static String get baseUrl {
    if (kIsWeb) {
      return _localUrl;
    }
    return _prodUrl;
  }
}
