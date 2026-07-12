import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../models/enums.dart';
import '../../models/notification.dart';
import '../../models/user.dart';
import '../../repositories/interfaces/auth_repository.dart';
import '../../repositories/interfaces/notification_repository.dart';

class MockAuthRepository implements AuthRepository {
  User? _currentUser;
  final _controller = StreamController<User?>.broadcast();

  @override
  Future<Result<User>> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (email.isEmpty || password.length < 4) {
      return const Failure(AuthException('Invalid credentials'));
    }

    final role = email.contains('superadmin')
        ? UserRole.superAdmin
        : email.contains('municipal')
            ? UserRole.municipalAdmin
            : email.contains('researcher')
                ? UserRole.researcher
                : email.contains('epa') ||
                        email.contains('wrc') ||
                        email.contains('nadmo') ||
                        email.contains('fire') ||
                        email.contains('forestry') ||
                        email.contains('waste') ||
                        email.contains('officer') ||
                        email.contains('pollution') ||
                        email.contains('mining') ||
                        email.contains('dumping') ||
                        email.contains('flooding')
                    ? UserRole.agencyAdmin
                    : UserRole.citizen;

    _currentUser = User(
      id: 'user_${email.hashCode}',
      displayName: email.split('@').first,
      role: role,
      email: email,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _controller.add(_currentUser);
    return Success(_currentUser!);
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
    _currentUser = null;
    _controller.add(null);
    return const Success(null);
  }

  @override
  Future<Result<User?>> getCurrentUser() async => Success(_currentUser);

  @override
  Stream<User?> watchAuthState() => _controller.stream;
}

class MockUserRepository implements UserRepository {
  @override
  Future<Result<User>> updateProfile(User user) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Success(user);
  }

  @override
  Future<Result<User>> updatePreferences(UserPreferences preferences) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Success(
      User(
        id: 'user_local',
        displayName: 'User',
        role: UserRole.citizen,
        preferences: preferences,
      ),
    );
  }
}

class MockNotificationRepository implements NotificationRepository {
  final _notifications = <AppNotification>[
    AppNotification(
      id: 'n1',
      title: 'Report Under Review',
      body: 'Your report EW-A1B2-C3D4 is being reviewed by field officers.',
      type: NotificationType.reportUpdate,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      reportId: 'rpt_001',
      actionRoute: '/track',
    ),
    AppNotification(
      id: 'n2',
      title: 'Report Verified',
      body: 'Report EW-E5F6-G7H8 has been verified. Action is planned.',
      type: NotificationType.reportVerified,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      reportId: 'rpt_002',
      isRead: true,
    ),
    AppNotification(
      id: 'n3',
      title: 'Sync Complete',
      body: '2 offline reports were uploaded successfully.',
      type: NotificationType.syncComplete,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Success(List.unmodifiable(_notifications));
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] =
          _notifications[index].copyWith(isRead: true);
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    return const Success(null);
  }

  @override
  Stream<List<AppNotification>> watchNotifications() async* {
    yield _notifications;
  }
}
