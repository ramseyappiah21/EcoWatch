import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../core/constants/app_constants.dart';
import '../l10n/app_localizations.dart';

import '../core/network/api_client.dart';

import '../core/network/dio_api_client.dart';

import '../models/emergency_contact.dart';
import '../repositories/implementations/analytics_repository_impl.dart';

import '../repositories/implementations/http_auth_repository.dart';

import '../repositories/implementations/http_report_remote_datasource.dart';

import '../repositories/implementations/citizen_notification_repository.dart';

import '../repositories/implementations/mock_auth_repository.dart';

import '../repositories/implementations/public_remote_datasource.dart';

import '../repositories/implementations/report_repository_impl.dart';

import '../repositories/interfaces/analytics_repository.dart';

import '../repositories/interfaces/auth_repository.dart';

import '../repositories/interfaces/map_repository.dart';

import '../repositories/interfaces/notification_repository.dart';

import '../repositories/interfaces/report_repository.dart';

import '../services/gis/map_service.dart';

import '../services/media/media_capture_service.dart';

import '../services/offline/connectivity_service.dart';

import '../services/offline/local_report_datasource.dart';

import '../services/offline/offline_sync_service.dart';

import '../services/security/rbac_service.dart';

import '../services/security/token_service.dart';

import '../services/severity/severity_engine.dart';



/// Dependency injection container using Riverpod.



final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {

  throw UnimplementedError('Override in ProviderScope');

});



final tokenServiceProvider = Provider<TokenService>((ref) => TokenService());



final apiClientProvider = Provider<ApiClient>((ref) {

  if (AppConstants.useMockApi) return MockApiClient();

  return DioApiClient(tokenService: ref.watch(tokenServiceProvider));

});



final dioApiClientProvider = Provider<DioApiClient?>((ref) {

  final client = ref.watch(apiClientProvider);

  return client is DioApiClient ? client : null;

});



final connectivityServiceProvider =

    Provider<ConnectivityService>((ref) => ConnectivityService());



final rbacServiceProvider = Provider<RbacService>((ref) => const RbacService());



final severityEngineProvider =

    Provider<SeverityEngine>((ref) => SeverityEngine());



final heatmapManagerProvider =

    Provider<HeatmapManager>((ref) => HeatmapManager());



final markerClusterManagerProvider =

    Provider<MarkerClusterManager>((ref) => MarkerClusterManager());



final localReportDataSourceProvider = Provider<LocalReportDataSource>((ref) {

  final prefs = ref.watch(sharedPreferencesProvider);

  return SharedPrefsReportDataSource(prefs);

});

/// Bumped after a report is saved so home can refresh recent reports.
final reportsListVersionProvider = StateProvider<int>((ref) => 0);



final localTokenDataSourceProvider = Provider<LocalTokenDataSource>((ref) {

  final prefs = ref.watch(sharedPreferencesProvider);

  return SharedPrefsTokenDataSource(prefs);

});



final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>((ref) {

  if (AppConstants.useMockApi) return MockReportRemoteDataSource();

  final dioClient = ref.watch(dioApiClientProvider);

  if (dioClient == null) return MockReportRemoteDataSource();

  return HttpReportRemoteDataSource(dioClient);

});



final reportRepositoryProvider = Provider<ReportRepository>((ref) {

  return ReportRepositoryImpl(

    local: ref.watch(localReportDataSourceProvider),

    remote: ref.watch(reportRemoteDataSourceProvider),

    connectivity: ref.watch(connectivityServiceProvider),

    tokenService: ref.watch(tokenServiceProvider),

    severityEngine: ref.watch(severityEngineProvider),

  );

});



final trackingTokenRepositoryProvider =

    Provider<TrackingTokenRepository>((ref) {

  return TrackingTokenRepositoryImpl(

    local: ref.watch(localTokenDataSourceProvider),

    tokenService: ref.watch(tokenServiceProvider),

  );

});



final authRepositoryProvider = Provider<AuthRepository>((ref) {

  if (AppConstants.useMockApi) return MockAuthRepository();

  return HttpAuthRepository(

    apiClient: ref.watch(apiClientProvider),

    tokenService: ref.watch(tokenServiceProvider),

  );

});



final userRepositoryProvider =

    Provider<UserRepository>((ref) => MockUserRepository());



final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return CitizenNotificationRepository(
    prefs: ref.watch(sharedPreferencesProvider),
    client: ref.watch(apiClientProvider),
    localReports: ref.watch(localReportDataSourceProvider),
    reportRepository: ref.watch(reportRepositoryProvider),
  );
});



final publicRemoteDataSourceProvider = Provider<PublicRemoteDataSource>((ref) {

  return PublicRemoteDataSource(ref.watch(apiClientProvider));

});



final emergencyContactsProvider =

    FutureProvider((ref) async {

  if (AppConstants.useMockApi) {

    return const [

      EmergencyContact(

        name: 'EPA Ghana',

        agency: 'Environmental Protection Agency',

        phone: '0302-664697',

      ),

    ];

  }

  return ref.watch(publicRemoteDataSourceProvider).fetchEmergencyContacts();

});



final mapRepositoryProvider = Provider<MapRepository>((ref) {

  return MapRepositoryImpl(ref.watch(heatmapManagerProvider));

});



final mapServiceProvider = Provider<MapService>((ref) {

  return GeolocatorMapService(ref.watch(markerClusterManagerProvider));

});



final mediaCaptureServiceProvider =
    Provider<MediaCaptureService>((ref) => MediaCaptureService());



final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {

  return AnalyticsRepositoryImpl(

    heatmapManager: ref.watch(heatmapManagerProvider),

    apiClient: AppConstants.useMockApi ? null : ref.watch(apiClientProvider),

  );

});



final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {

  return OfflineSyncService(

    reportRepository: ref.watch(reportRepositoryProvider),

    connectivity: ref.watch(connectivityServiceProvider),

  );

});



/// Session flag â€” intro must be completed before home on each cold start.
final introSessionCompleteProvider = Provider<ValueNotifier<bool>>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier(this._prefs) : super(_prefs.getBool(AppConstants.darkModeKey) ?? true);

  final SharedPreferences _prefs;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _prefs.setBool(AppConstants.darkModeKey, enabled);
  }
}

final darkModeProvider =
    StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier(ref.watch(sharedPreferencesProvider));
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier(this._prefs)
      : super(_prefs.getString(AppConstants.languageCodeKey) ?? 'en');

  final SharedPreferences _prefs;

  static const supported = AppLocalizations.languageNames;

  Future<void> setLanguage(String code) async {
    state = code;
    await _prefs.setString(AppConstants.languageCodeKey, code);
  }
}

final languageCodeProvider =
    StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier(ref.watch(sharedPreferencesProvider));
});

