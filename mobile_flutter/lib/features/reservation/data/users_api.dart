import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Result of GET /users/by-nickname/{nickname}.
class UserLookup {
  const UserLookup({required this.nickname, required this.name});

  final String nickname;
  final String name;

  factory UserLookup.fromJson(Map<String, dynamic> json) => UserLookup(
        nickname: json['nickname']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

class NicknameLookupException implements Exception {
  NicknameLookupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Validates group participant nicknames against registered users.
class UsersApi {
  Future<UserLookup> lookupNickname(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      throw NicknameLookupException('Nickname cannot be empty.');
    }
    try {
      final response = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/users/by-nickname/${Uri.encodeComponent(trimmed)}',
      );
      final data = response.data ?? {};
      return UserLookup.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map) {
          final msg = data['message']?.toString();
          if (msg != null && msg.isNotEmpty) {
            throw NicknameLookupException(msg);
          }
        }
        throw NicknameLookupException('User not found: $trimmed');
      }
      rethrow;
    }
  }
}
