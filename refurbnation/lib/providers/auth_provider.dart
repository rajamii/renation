import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  String? _userRole;

  bool get isAuthenticated => _isAuthenticated;

  // Hitting the CustomTokenObtainPairView mapped to /auth/login/
  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        await storage.write(key: 'access_token', value: response.data['access']);
        await storage.write(key: 'refresh_token', value: response.data['refresh']);
        
        // Your custom view returns 'role' in the token payload/response
        _userRole = response.data['role'] ?? 'USER'; 
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print("Login Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    await storage.deleteAll();
    _isAuthenticated = false;
    notifyListeners();
  }
}