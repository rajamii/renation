import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = kIsWeb
      ? 'http://localhost:8000/api'
      : 'http://10.0.2.2:8000/api';

  final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
  final storage = const FlutterSecureStorage();

  ApiClient() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Exclude auth routes from needing a token
          if (!options.path.contains('/auth/')) {
            String? accessToken = await storage.read(key: 'access_token');
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Token expired, attempt refresh
            bool refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the original request with the new token
              String? newAccessToken = await storage.read(key: 'access_token');
              e.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      String? refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      // Hitting your custom TokenRefreshView
      final response = await Dio().post(
        '$baseUrl/auth/refresh/',
        data: {'refresh': refreshToken},
      );

      await storage.write(key: 'access_token', value: response.data['access']);
      return true;
    } catch (e) {
      // Refresh failed (e.g., refresh token also expired). User must log in again.
      await storage.deleteAll();
      return false;
    }
  }
}
