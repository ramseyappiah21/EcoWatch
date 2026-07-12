import '../../core/constants/app_constants.dart';

/// HTTP client abstraction — implement with dio or http package later.
///
/// ```dart
/// class DioApiClient implements ApiClient {
///   DioApiClient(this._dio);
///   final Dio _dio;
///
///   @override
///   Future<ApiResponse<T>> get<T>(String path, {Map<String, String>? headers}) async {
///     final response = await _dio.get('$baseUrl$path', options: Options(headers: headers));
///     return ApiResponse(data: response.data, statusCode: response.statusCode ?? 200);
///   }
/// }
/// ```
abstract class ApiClient {
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  });

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
  });
}

class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    this.data,
    this.message,
  });

  final int statusCode;
  final T? data;
  final String? message;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// REST endpoint definitions — single source of truth for backend integration.
abstract class ApiEndpoints {
  static const String reports = '/reports';
  static String reportById(String id) => '/reports/$id';
  static String reportByToken(String token) => '/reports/track/$token';
  static const String analytics = '/analytics';
  static const String hotspots = '/maps/hotspots';
  static const String notifications = '/notifications';
  static const String authLogin = '/auth/login';
  static const String authLogout = '/auth/logout';
  static const String ussdWebhook = '/ussd/webhook';
  static const String emergencyContacts = '/public/emergency-contacts';
  static const String announcements = '/public/announcements';
  static const String syncBatch = '/sync/batch';

  static String get baseUrl => AppConstants.apiBaseUrl;
}

/// Mock API client returning fake responses for UI development.
class MockApiClient implements ApiClient {
  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return ApiResponse(statusCode: 200, data: null, message: 'Mock GET $path');
  }

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return ApiResponse(statusCode: 201, data: body as T?, message: 'Mock POST $path');
  }

  @override
  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return ApiResponse(statusCode: 200, data: body as T?);
  }

  @override
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return ApiResponse(statusCode: 204, data: null);
  }
}
