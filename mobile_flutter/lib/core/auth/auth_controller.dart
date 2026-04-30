import 'package:flutter/material.dart';
import '../../features/auth/data/auth_api.dart';
import '../session/auth_session.dart';

class AuthController extends ChangeNotifier {
  bool _isLoggedIn = false; // _ is used to make the variable private.

  bool get isLoggedIn => _isLoggedIn; // getter is used to get the value of the variable.

  /// Backend [POST /auth/login] başarılı yanıtından sonra çağrılır; token [ApiClient] ile gider.
  void establishSession({ // 
    required String accessToken,
    String? refreshToken,
    Map<String, dynamic>? user, //user object is coming from the backend.
  }) {
    final session = AuthSession.instance;
    session.accessToken = accessToken;
    session.refreshToken = refreshToken;
    _updateSessionFromMap(user);
    if (!_isLoggedIn) {
      _isLoggedIn = true;
    }
    notifyListeners();
  }

  /// Mevcut oturum verilerini backend'den günceller (skor vb.).
  Future<void> refreshProfile() async {
    try {
      final user = await AuthApi().getMe();
      _updateSessionFromMap(user);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
    }
  }

  void _updateSessionFromMap(Map<String, dynamic>? user) {
    if (user == null) return;
    final session = AuthSession.instance;
    session.userId = user['id']?.toString();
    session.userName = user['name']?.toString();
    session.userNickname = user['nickname']?.toString();
    session.userEmail = user['email']?.toString();
    session.userDepartment = user['department']?.toString();
    final yearVal = user['year'];
    session.userYear = yearVal is num ? yearVal.toInt() : int.tryParse(yearVal?.toString() ?? '');
    final scoreVal = user['responsibilityScore'];
    session.userScore = scoreVal is num ? scoreVal.toInt() : int.tryParse(scoreVal?.toString() ?? '');
    final courses = user['enrolledCourses'];
    if (courses is List) {
      session.enrolledCourseCodes = courses.map((e) => e.toString()).toList();
    }
  }

  void logout() {
    AuthSession.instance.clear();
    if (_isLoggedIn) {
      _isLoggedIn = false;
      notifyListeners();
    }
  }
}
