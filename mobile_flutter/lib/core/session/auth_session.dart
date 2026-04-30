/// Oturum belirteçleri — [ApiClient] Authorization başlığı buradan okunur.
class AuthSession {
  AuthSession._(); //private constructor
  static final AuthSession instance = AuthSession._(); //singleton instance

  String? accessToken;//access token is the token that is used to access the resources.
  String? refreshToken;//refresh token is the token that is used to refresh the access token.
  String? userId;
  String? userName;
  String? userNickname;
  String? userEmail;
  String? userDepartment;
  int? userYear;
  int? userScore;
  List<String> enrolledCourseCodes = [];

  void clear() {
    accessToken = null;
    refreshToken = null;
    userId = null;
    userName = null;
    userNickname = null;
    userEmail = null;
    userDepartment = null;
    userYear = null;
    userScore = null;
    enrolledCourseCodes = [];
  }
}
