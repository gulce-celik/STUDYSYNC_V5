import '../../../core/network/api_client.dart';
import '../data/home_mock_data.dart';

/// GET/POST `/group-invitations/*` — pending list, accept, decline.
class GroupInvitationsApi {
  Future<List<HomeGroupInvitation>> fetchPending() async {
    final response = await ApiClient.instance.dio.get<List<dynamic>>('/group-invitations/pending');
    final raw = response.data ?? [];
    return raw
        .map((e) => HomeGroupInvitation.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((inv) => inv.id.isNotEmpty)
        .toList();
  }

  Future<void> accept(String inviteId) async {
    await ApiClient.instance.dio.post<void>('/group-invitations/$inviteId/accept');
  }

  Future<void> decline(String inviteId) async {
    await ApiClient.instance.dio.post<void>('/group-invitations/$inviteId/decline');
  }
}
