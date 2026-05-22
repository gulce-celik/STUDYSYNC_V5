import '../../../core/network/api_client.dart';

class LostFoundApi {
  Future<List<Map<String, dynamic>>> getLostItems() async {
    final response = await ApiClient.instance.dio.get('/lost-found');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> reportLostItem({
    required String workspaceId,
    required String description,
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/lost-found',
      data: {'workspaceId': workspaceId, 'description': description},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAsFound(String id) async {
    final response = await ApiClient.instance.dio.patch('/lost-found/$id/found');
    return response.data as Map<String, dynamic>;
  }
}
