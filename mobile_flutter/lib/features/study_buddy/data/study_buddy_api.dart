import '../../../core/network/api_client.dart';

class StudyBuddyApi {
  Future<List<Map<String, dynamic>>> getSuggestions({
    required String courseCode,
    required String slotId,
  }) async {
    final response = await ApiClient.instance.dio.get(
      '/study-buddies/suggestions',
      queryParameters: {'courseCode': courseCode, 'slotId': slotId},
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// POST /study-buddies/reports — reporter from JWT; returns `{ success, message, report? }`.
  Future<Map<String, dynamic>> submitReport({
    required String reportedUserId,
    required String reason,
    String comment = '',
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/study-buddies/reports',
      data: {
        'reportedUserId': reportedUserId,
        'reason': reason,
        if (comment.isNotEmpty) 'comment': comment,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
