import 'package:equatable/equatable.dart';

/// Base exception for domain and infrastructure errors.
sealed class AppException extends Equatable implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'Network connection failed']);
}

final class CacheException extends AppException {
  const CacheException([super.message = 'Local storage operation failed']);
}

final class AuthException extends AppException {
  const AuthException([super.message = 'Authentication failed']);
}

final class PermissionException extends AppException {
  const PermissionException([super.message = 'Required permission denied']);
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found']);
}

final class SyncException extends AppException {
  const SyncException([super.message = 'Synchronization failed']);
}

final class AiException extends AppException {
  const AiException([super.message = 'AI prediction failed']);
}
