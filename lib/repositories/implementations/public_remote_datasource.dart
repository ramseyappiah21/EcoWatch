import '../../core/network/api_client.dart';
import '../../models/emergency_contact.dart';

class PublicRemoteDataSource {
  PublicRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<EmergencyContact>> fetchEmergencyContacts() async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.emergencyContacts,
    );
    if (!response.isSuccess || response.data == null) return [];
    return response.data!
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
