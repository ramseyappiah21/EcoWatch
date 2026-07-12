import 'package:equatable/equatable.dart';

import 'enums.dart';

/// In-app notification for report updates and system alerts.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.reportId,
    this.isRead = false,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final String? reportId;
  final bool isRead;
  final String? actionRoute;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'reportId': reportId,
        'isRead': isRead,
        'actionRoute': actionRoute,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: NotificationType.values.byName(json['type'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        reportId: json['reportId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        actionRoute: json['actionRoute'] as String?,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        reportId: reportId,
        isRead: isRead ?? this.isRead,
        actionRoute: actionRoute,
      );

  @override
  List<Object?> get props => [id, isRead];
}

enum NotificationType {
  reportUpdate,
  reportVerified,
  reportResolved,
  systemAlert,
  syncComplete,
}
