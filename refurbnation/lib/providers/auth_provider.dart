import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  String? userRole;

  // Profile state properties
  int? _userId;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _username = '';
  String _phoneNumber = '';
  String _referralCode = '';
  int _completedBookingsCount = 0;

  ThemeMode _themeMode = ThemeMode.dark;

  bool get isAuthenticated => _isAuthenticated;
  int? get userId => _userId;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get email => _email;
  String get username => _username;
  String get phoneNumber => _phoneNumber;
  String get referralCode => _referralCode;
  int get completedBookingsCount => _completedBookingsCount;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login/',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        String role = response.data['role'] ?? 'USER';

        if (role != 'USER') {
          AppLogger.log("Login Denied: Only Customers are allowed.");
          return false;
        }

        final String accessToken = response.data['access'];
        await storage.write(key: 'access_token', value: accessToken);
        await storage.write(
          key: 'refresh_token',
          value: response.data['refresh'],
        );

        userRole = role;
        _isAuthenticated = true;

        // Fetch profile data immediately after successful login
        await fetchUserProfile();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.log("Login Error", e);
      return false;
    }
  }

  // Fetch Profile details from your custom user backend
  Future<void> fetchUserProfile() async {
    try {
      String? accessToken = await storage.read(key: 'access_token');
      if (accessToken != null) {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);

        final rawUid = decodedToken['user_id'];
        if (rawUid != null) {
          if (rawUid is int) {
            _userId = rawUid;
          } else if (rawUid is String) {
            _userId = int.tryParse(rawUid);
          }
        }
      }

      final response = await _apiClient.dio.get('/auth/profile/');
      if (response.statusCode == 200) {
        _firstName = response.data['first_name'] ?? '';
        _lastName = response.data['last_name'] ?? '';
        _email = response.data['email'] ?? '';
        _username = response.data['username'] ?? '';
        _phoneNumber = response.data['phone_number'] ?? '';
        _referralCode = response.data['referral_code'] ?? '';
        _completedBookingsCount = response.data['completed_bookings'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log("Error fetching profile", e);
    }
  }

  Future<bool> updateUserProfile(String email, String phoneNumber) async {
    try {
      final response = await _apiClient.dio.patch(
        '/auth/profile/',
        data: {'email': email, 'phone_number': phoneNumber},
      );

      if (response.statusCode == 200) {
        _email = email;
        _phoneNumber = phoneNumber;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signup(
    String email,
    String password, {
    String? firstName,
    String? lastName,
    String? username,
    String? phoneNumber,
    String? referralCode,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register/',
        data: {
          'email': email,
          'password': password,
          if (firstName?.isNotEmpty ?? false) 'first_name': firstName,
          if (lastName?.isNotEmpty ?? false) 'last_name': lastName,
          if (username?.isNotEmpty ?? false) 'username': username,
          if (phoneNumber?.isNotEmpty ?? false) 'phone_number': phoneNumber,
          if (referralCode?.isNotEmpty ?? false) 'referral_code': referralCode,
        },
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      AppLogger.log("Signup Error", e);
      return false;
    }
  }

  Future<bool> checkAutoLogin() async {
    try {
      String? accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) return false;

      bool isExpired = JwtDecoder.isExpired(accessToken);
      if (isExpired) {
        String? refreshToken = await storage.read(key: 'refresh_token');
        if (refreshToken == null) return false;

        final response = await _apiClient.dio.post(
          '/auth/refresh/',
          data: {'refresh': refreshToken},
        );

        if (response.statusCode == 200) {
          await storage.write(
            key: 'access_token',
            value: response.data['access'],
          );
          if (response.data['refresh'] != null) {
            await storage.write(
              key: 'refresh_token',
              value: response.data['refresh'],
            );
          }
        } else {
          return false;
        }
      }

      _isAuthenticated = true;
      userRole = 'USER';
      await fetchUserProfile();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await storage.deleteAll();
    _isAuthenticated = false;
    userRole = null;
    _userId = null;
    _firstName = '';
    _lastName = '';
    _email = '';
    _referralCode = '';
    notifyListeners();
  }
}
