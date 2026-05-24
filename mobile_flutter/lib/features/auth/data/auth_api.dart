import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

enum PasswordResetStatus { submitted, notAvailable, invalidRequest, networkError }

class PasswordResetResult {
  const PasswordResetResult({required this.status, required this.message});

  final PasswordResetStatus status;
  final String message;
}

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

  /// [POST /auth/register-init] — İlk adım (email, pass, name).
  Future<void> registerInit({
    required String email,
    required String password,
    required String name,
    required String nickname,
  }) async {
    await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/auth/register-init',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'nickname': nickname,
        'kvkkAccepted': true, // DTO requires it to be not null and true
      },
    );
  }

  /// [POST /auth/verify-otp]
  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {
        'email': email,
        'otpCode': otpCode,
      },
    );
  }

  /// [POST /auth/register-complete] — gövde:
  /// `email`, `departmentId`, `year`, `selectedCourseCodes`, `kvkkAccepted`
  /// ve yanıtta login ile aynı token yapısı beklenir.
  Future<LoginResult> registerComplete({
    required String email,
    required String password,
    required String name,
    required String nickname,
    required String departmentId,
    required int year,
    required List<String> selectedCourseCodes,
    required bool kvkkAccepted,
  }) async {
    final response = await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/auth/register-complete',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'nickname': nickname,
        'departmentId': departmentId,
        'year': year,
        'selectedCourseCodes': selectedCourseCodes,
        'kvkkAccepted': kvkkAccepted,
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

  /// [POST /auth/forgot-password] — ready when backend adds it; otherwise 404/501.
  Future<PasswordResetResult> requestPasswordReset({required String email}) async {
    try {
      await ApiClient.instance.dio.post<void>(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return const PasswordResetResult(
        status: PasswordResetStatus.submitted,
        message:
            'If this email is registered, reset instructions will be sent when email delivery is enabled.',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 501 || status == 405) {
        return const PasswordResetResult(
          status: PasswordResetStatus.notAvailable,
          message:
              'Password reset is not enabled on the server yet. Ask the backend team or use your existing password.',
        );
      }
      if (status == 400) {
        return const PasswordResetResult(
          status: PasswordResetStatus.invalidRequest,
          message: 'Could not process this email address. Check the format and try again.',
        );
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const PasswordResetResult(
          status: PasswordResetStatus.networkError,
          message: 'Cannot reach the server. Start the backend on port 8080 and try again.',
        );
      }
      return PasswordResetResult(
        status: PasswordResetStatus.networkError,
        message: e.message ?? 'Password reset request failed.',
      );
    }
  }

  /// [PUT /auth/password] — Şifre değiştirme endpointi.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.instance.dio.put<void>(
      '/auth/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  /// [PUT /auth/me/courses] — Kullanıcının kayıtlı ders listesini kalıcı olarak günceller.
  Future<void> updateMyCourses(List<String> courses) async {
    await ApiClient.instance.dio.put<void>(
      '/auth/me/courses',
      data: {'courses': courses},
    );
  }
}
