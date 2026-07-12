import '../../core/errors/result.dart';
import '../../models/notification.dart';

abstract class NotificationRepository {
  Future<Result<List<AppNotification>>> getNotifications();

  Future<Result<void>> markAsRead(String notificationId);

  Future<Result<void>> markAllAsRead();

  Stream<List<AppNotification>> watchNotifications();
}
