import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message, [dynamic error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('[RefurbNation ERROR]: $message | Details: $error');
      } else {
        debugPrint('[RefurbNation INFO]: $message');
      }
    }
  }
}
