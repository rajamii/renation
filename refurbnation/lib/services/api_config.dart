import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _url = 'http://localhost:8000/api';
  // static const String _url = 'https://refurbnation.onrender.com/api';

  static String get baseUrl {
    if (kIsWeb) {
      return _url; // Use production URL for web
    }
    return _url;
  }
}
