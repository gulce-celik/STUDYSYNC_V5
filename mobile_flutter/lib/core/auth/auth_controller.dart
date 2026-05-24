import 'package:flutter/material.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/notifications/data/notifications_controller.dart';
import '../session/auth_session.dart';
import '../trust/responsibility_ledger.dart';

class AuthController extends ChangeNotifier {
  bool _isLoggedIn = false; // _ is used to make the variable private.

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdminSession => AuthSession.instance.isAdmin;

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
    // Reset per-session ledger counters when the active user changes,
    // so the daily limit is per-user, not per-device.
    final uid = AuthSession.instance.userId;
    if (uid != null) ResponsibilityLedger.instance.resetForUser(uid);
    AuthSession.instance.isAdmin = false;
    if (!_isLoggedIn) {
      _isLoggedIn = true;
    }
    notifyListeners();
    if (!AuthSession.instance.isAdmin) {
      NotificationsController.instance.refresh();
    }
  }

  /// Staff console — allowlisted `@yeditepe.edu.tr` (see [AdminAllowlist]).
  /// Pass [accessToken] from [AuthApi.login] (or API bridge) for live campus data.
  void establishAdminSession({
    required String email,
    required String displayName,
    String? accessToken,
    String? refreshToken,
  }) {
    final session = AuthSession.instance;
    session.clear();
    session.isAdmin = true;
    session.userEmail = email;
    session.userName = displayName;
    session.userId = 'admin-${email.hashCode}';
    session.accessToken = accessToken;
    session.refreshToken = refreshToken;
    _isLoggedIn = true;
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
    session.userKvkkAccepted = user['kvkkAccepted'] == true;
  }

  void logout() {
    AuthSession.instance.clear();
    NotificationsController.instance.clear();
    _isLoggedIn = false;
    notifyListeners();
  }
}
