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

  /// POST /study-buddies/listings — returns `{ success, message, listingId, updatedResponsibilityScore, createdAt }`.
  Future<Map<String, dynamic>> createListing({
    required String courseCode,
    required String purpose,
    required String preferredWeekday,
    required String preferredSlotId,
    required String note,
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/study-buddies/listings',
      data: {
        'courseCode': courseCode,
        'purpose': purpose,
        'preferredWeekday': preferredWeekday,
        'preferredSlotId': preferredSlotId,
        'note': note,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// GET /study-buddies/listings/me — returns active listings of current user.
  Future<List<Map<String, dynamic>>> getMyListings() async {
    final response = await ApiClient.instance.dio.get('/study-buddies/listings/me');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// POST /study-buddies/listings/{id}/complete — marks a listing as completed.
  Future<Map<String, dynamic>> completeListing(String id) async {
    final response = await ApiClient.instance.dio.post('/study-buddies/listings/$id/complete');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// POST /study-buddies/listings/{id}/cancel — cancels a listing.
  Future<Map<String, dynamic>> cancelListing(String id) async {
    final response = await ApiClient.instance.dio.post('/study-buddies/listings/$id/cancel');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
