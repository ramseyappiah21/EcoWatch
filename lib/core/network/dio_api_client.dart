import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../../services/security/token_service.dart';
import 'api_client.dart';

/// HTTP client backed by Dio with JWT auth and multipart upload support.
class DioApiClient implements ApiClient {
  DioApiClient({
    required TokenService tokenService,
    String? baseUrl,
    Dio? dio,
  })  : _tokenService = tokenService,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
                headers: {'Accept': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Cache auth lookup — secure storage on Safari is slow per-request.
          if (!_authLoaded) {
            _cachedAuthToken = await _tokenService.getAuthToken();
            _authLoaded = true;
          }
          final token = _cachedAuthToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final TokenService _tokenService;
  final Dio _dio;
  String? _cachedAuthToken;
  bool _authLoaded = false;

  Dio get dio => _dio;

  void clearAuthCache() {
    _cachedAuthToken = null;
    _authLoaded = false;
  }

  void setAuthCache(String? token) {
    _cachedAuthToken = token;
    _authLoaded = true;
  }

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParams,
      options: Options(headers: headers),
    );
    return ApiResponse(
      statusCode: response.statusCode ?? 200,
      data: response.data as T?,
    );
  }

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: body,
      options: Options(headers: headers),
    );
    return ApiResponse(
      statusCode: response.statusCode ?? 200,
      data: response.data as T?,
    );
  }

  @override
  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.put<dynamic>(
      path,
      data: body,
      options: Options(headers: headers),
    );
    return ApiResponse(
      statusCode: response.statusCode ?? 200,
      data: response.data as T?,
    );
  }

  @override
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _dio.delete<dynamic>(
      path,
      options: Options(headers: headers),
    );
    return ApiResponse(
      statusCode: response.statusCode ?? 200,
      data: response.data as T?,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    List<MultipartFile> files = const [],
  }) async {
    final formData = FormData();
    for (final entry in fields.entries) {
      formData.fields.add(MapEntry(entry.key, entry.value.toString()));
    }
    for (final file in files) {
      formData.files.add(MapEntry('media', file));
    }
    // Photos/videos need longer than the default 8s send timeout.
    final response = await _dio.post<dynamic>(
      path,
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    return ApiResponse(
      statusCode: response.statusCode ?? 201,
      data: response.data as Map<String, dynamic>?,
    );
  }
}
