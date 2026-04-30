import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class LoginResult {
  LoginResult({
    required this.accessToken,
    this.refreshToken,
    this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;
}

class AuthApi {
  /// [POST /auth/login] — gövde: `email`, `password` (backend iskeletiyle aynı).
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.instance.dio.post<Map<String, dynamic>>( // API call to login
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final m = response.data ?? {};
    final token = m['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid login response: missing accessToken',
      );
    }
    return LoginResult(
      accessToken: token,
      refreshToken: m['refreshToken']?.toString(),
      user: m['user'] is Map<String, dynamic> ? m['user'] as Map<String, dynamic> : null,
    );
  }

  /// [POST /auth/register] — gövde:
  /// `email`, `password`, `name`, `nickname`, `departmentId`, `year`, `selectedCourseCodes`
  /// ve yanıtta login ile aynı token yapısı beklenir.
  Future<LoginResult> register({
    required String email,
    required String password,
    required String name,
    required String nickname,
    required String departmentId,
    required int year,
    required List<String> selectedCourseCodes,
  }) async {
    final response = await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'nickname': nickname,
        'departmentId': departmentId,
        'year': year,
        'selectedCourseCodes': selectedCourseCodes,
      },
    );
    final m = response.data ?? {};
    final token = m['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid register response: missing accessToken',
      );
    }
    return LoginResult(
      accessToken: token,
      refreshToken: m['refreshToken']?.toString(),
      user: m['user'] is Map<String, dynamic> ? m['user'] as Map<String, dynamic> : null,
    );
  }

  /// [GET /auth/me] — Mevcut kullanıcının en güncel verilerini (skor vb.) çeker.
  Future<Map<String, dynamic>> getMe() async {
    final response = await ApiClient.instance.dio.get<Map<String, dynamic>>('/auth/me');
    return response.data ?? {};
  }
}
