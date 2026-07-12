import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity for offline sync decisions.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isOnline async {
    try {
      final result = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 1));
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      // Assume online if the check hangs (common on some mobile browsers).
      return true;
    }
  }

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(
        (results) => !results.contains(ConnectivityResult.none),
      );
}
