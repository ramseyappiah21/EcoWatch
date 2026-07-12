import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';

/// Generates privacy-safe tracking tokens without device identifiers.
class TokenService {
  TokenService({Uuid? uuid, FlutterSecureStorage? secureStorage})
      : _uuid = uuid ?? const Uuid(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final Uuid _uuid;
  final FlutterSecureStorage _secureStorage;

  /// Format: EW-XXXX-XXXX (human-readable for USSD/SMS)
  String generateTrackingToken() {
    final raw = _uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return '${AppConstants.trackingTokenPrefix}-${raw.substring(0, 4)}-${raw.substring(4, 8)}';
  }

  Future<void> storeAuthToken(String token) async {
    await _secureStorage.write(key: AppConstants.authTokenKey, value: token);
  }

  Future<String?> getAuthToken() =>
      _secureStorage.read(key: AppConstants.authTokenKey);

  Future<void> clearAuthToken() =>
      _secureStorage.delete(key: AppConstants.authTokenKey);

  Future<void> storeTrackingToken(String token) async {
    final existing = await _secureStorage.read(key: 'token_$token');
    if (existing == null) {
      await _secureStorage.write(key: 'token_$token', value: DateTime.now().toIso8601String());
    }
  }
}
