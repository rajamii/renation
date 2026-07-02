import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = kIsWeb
      ? 'http://localhost:8000/api'
      : 'https://refurbnation.onrender.com/api';

  final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
  final storage = const FlutterSecureStorage();

  ApiClient() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          bool isPublicRoute =
              options.path.contains('/auth/login/') ||
              options.path.contains('/auth/register/') ||
              options.path.contains('/auth/refresh/');

          if (!isPublicRoute) {
            String? accessToken = await storage.read(key: 'access_token');
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            bool refreshed = await _refreshToken();
            if (refreshed) {
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

      final response = await Dio().post(
        '$baseUrl/auth/refresh/',
        data: {'refresh': refreshToken},
      );

      await storage.write(key: 'access_token', value: response.data['access']);
      return true;
    } catch (e) {
      await storage.deleteAll();
      return false;
    }
  }
}
