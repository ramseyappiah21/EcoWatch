import 'package:flutter/foundation.dart';

/// Application-wide constants for EcoWatch (Tarkwa environmental monitoring).
class AppConstants {
  AppConstants._();

  static const String appName = 'EcoWatch Tarkwa';
  static const String appVersion = '1.0.0';
  static const String regionName = 'Tarkwa-Nsuaem Municipal Assembly';

  /// Default map center: Tarkwa, Ghana
  static const double defaultLatitude = 5.3018;
  static const double defaultLongitude = -1.9931;
  static const double defaultMapZoom = 12.0;

  /// Tracking token format: EW-XXXX-XXXX
  static const String trackingTokenPrefix = 'EW';

  /// Offline sync keys
  static const String pendingReportsKey = 'pending_reports';
  static const String cachedReportsKey = 'cached_reports';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String darkModeKey = 'dark_mode';
  static const String languageCodeKey = 'language_code';
  static const String authTokenKey = 'auth_token';
  static const String trackingTokensKey = 'tracking_tokens';
  static const String reportDraftKey = 'report_draft';

  /// USSD short code — Africa's Talking sandbox channel
  static const String ussdShortCode = '*384*63693#';

  /// Override with: flutter build apk --dart-define=API_BASE_URL=https://xxx/v1
  static const String _envApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _envAdminPortalUrl = String.fromEnvironment(
    'ADMIN_PORTAL_URL',
    defaultValue: '',
  );

  /// LAN fallback when not running as same-origin web (native / local debug).
  static const String _lanApiBaseUrl = 'http://172.20.10.3:3000/v1';
  static const String _lanAdminPortalUrl = 'http://172.20.10.3:3000/admin';

  /// On Flutter web, use the page origin so HTTPS tunnels work for GPS + API.
  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return '$origin/v1';
      }
    }
    return _lanApiBaseUrl;
  }

  /// Set true to use in-memory mocks without a backend.
  static const bool useMockApi = false;

  /// Web admin portal for super admins and category officers.
  static String get adminPortalUrl {
    if (_envAdminPortalUrl.isNotEmpty) return _envAdminPortalUrl;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return '$origin/admin';
      }
    }
    return _lanAdminPortalUrl;
  }
}
