import '../../../core/network/api_client.dart';

class LostFoundApi {
  Future<List<Map<String, dynamic>>> getLostItems() async {
    final response = await ApiClient.instance.dio.get('/lost-found');
    final data = response.data;
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> reportLostItem({
    required String workspaceId,
    required String description,
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/lost-found',
      data: {'workspaceId': workspaceId, 'description': description},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> markAsFound(String id) async {
    final response = await ApiClient.instance.dio.patch('/lost-found/$id/found');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
