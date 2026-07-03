import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class ApiClient {
  final Dio dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
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
          // Intercept expired keys instantly
          if (e.response?.statusCode == 401) {
            bool refreshed = await _refreshToken();
            if (refreshed) {
              String? newAccessToken = await storage.read(key: 'access_token');

              // Clone the request bundle with the verified key header map
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

  Future<Map<String, dynamic>> getRewardSummary() async {
    final response = await dio.get('/rewards/dashboard/');
    return response.data;
  }

  Future<Map<String, dynamic>> applyDiscount(
    String discountId,
    double cartTotal,
  ) async {
    final response = await dio.post(
      '/rewards/apply-discount/',
      data: {'discount_id': discountId, 'cart_total': cartTotal},
    );
    return response.data;
  }

  Future<bool> _refreshToken() async {
    try {
      String? refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      // Use an isolated secondary Dio container instance to avoid request chaining intercept loops
      final response = await Dio().post(
        '${ApiConfig.baseUrl}/auth/refresh/',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        // Save the newly rotated access token
        await storage.write(
          key: 'access_token',
          value: response.data['access'],
        );

        // Optionally save the new refresh token if provided
        if (response.data['refresh'] != null) {
          await storage.write(
            key: 'refresh_token',
            value: response.data['refresh'],
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      // Clear security instance keys to force state updates if verification completely fails
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
      return false;
    }
  }
}
