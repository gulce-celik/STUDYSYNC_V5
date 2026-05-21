import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../session/auth_session.dart';

class ApiClient {
  ApiClient._internal() { //private constructor is used to create a singleton instance.
    dio = Dio( // Dio is a HTTP client for Dart.
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        contentType: 'application/json',
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper( // InterceptorsWrapper is a class that is used to add interceptors to the Dio instance.
        onRequest: (options, handler) {
          final t = AuthSession.instance.accessToken; // t is the access token.
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t'; // Authorization header is used to add the access token to the request.
          }
          handler.next(options); //what is handler in dio ? it is used to pass the request to the next interceptor.
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio dio; // after the constructor is called, the dio instance is created.
}
