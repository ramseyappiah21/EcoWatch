import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_mappers.dart';
import '../../models/enums.dart';
import '../../models/user.dart';
import '../../repositories/interfaces/auth_repository.dart';
import '../../services/security/token_service.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required ApiClient apiClient,
    required TokenService tokenService,
  })  : _apiClient = apiClient,
        _tokenService = tokenService;

  final ApiClient _apiClient;
  final TokenService _tokenService;
  User? _currentUser;
  final _controller = StreamController<User?>.broadcast();

  @override
  Future<Result<User>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authLogin,
        body: {'email': email.trim(), 'password': password},
      );

      if (!response.isSuccess || response.data == null) {
        final error = response.data?['error'] as String?;
        return Failure(AuthException(error ?? 'Invalid credentials'));
      }

      final token = response.data!['token'] as String;
      final userJson = response.data!['user'] as Map<String, dynamic>;
      await _tokenService.storeAuthToken(token);

      _currentUser = User(
        id: userJson['id'] as String,
        displayName: userJson['displayName'] as String,
        email: userJson['email'] as String?,
        role: parseUserRole(userJson['role'] as String),
        lastLoginAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      _controller.add(_currentUser);
      return Success(_currentUser!);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  @override
  Future<Result<User>> signInAnonymously() async {
    _currentUser = const User(
      id: 'anon_user',
      displayName: 'Anonymous Citizen',
      role: UserRole.anonymous,
    );
    _controller.add(_currentUser);
    return Success(_currentUser!);
  }

  @override
  Future<Result<void>> signOut() async {
    await _tokenService.clearAuthToken();
    _currentUser = null;
    _controller.add(null);
    return const Success(null);
  }

  @override
  Future<Result<User?>> getCurrentUser() async => Success(_currentUser);

  @override
  Stream<User?> watchAuthState() => _controller.stream;
}
