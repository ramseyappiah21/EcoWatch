import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../core/network/api_client.dart';
import '../../models/enums.dart';
import '../../models/notification.dart';
import '../../models/report.dart';
import '../../repositories/interfaces/notification_repository.dart';
import '../../repositories/interfaces/report_repository.dart';
import '../../services/offline/local_report_datasource.dart';

/// Citizen in-app alerts from announcements and report status history.
class CitizenNotificationRepository implements NotificationRepository {
  CitizenNotificationRepository({
    required SharedPreferences prefs,
    required ApiClient client,
    required LocalReportDataSource localReports,
    required ReportRepository reportRepository,
  })  : _prefs = prefs,
        _client = client,
        _localReports = localReports,
        _reportRepository = reportRepository;

  final SharedPreferences _prefs;
  final ApiClient _client;
  final LocalReportDataSource _localReports;
  final ReportRepository _reportRepository;

  static const _readIdsKey = 'citizen_notification_read_ids';

  Set<String> _readIds() {
    final raw = _prefs.getString(_readIdsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveReadIds(Set<String> ids) async {
    await _prefs.setString(_readIdsKey, jsonEncode(ids.toList()));
  }

  NotificationType _typeForStatus(ReportStatus status) {
    switch (status) {
      case ReportStatus.verified:
        return NotificationType.reportVerified;
      case ReportStatus.resolved:
      case ReportStatus.completed:
      case ReportStatus.closed:
        return NotificationType.reportResolved;
      default:
        return NotificationType.reportUpdate;
    }
  }

  String _titleForStatus(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.underReview:
        return 'Report received';
      case ReportStatus.inProgress:
        return 'Investigation in progress';
      case ReportStatus.verified:
        return 'Report verified';
      case ReportStatus.resolved:
      case ReportStatus.completed:
        return 'Report resolved';
      case ReportStatus.closed:
        return 'Case closed';
      case ReportStatus.rejected:
        return 'Report update';
    }
  }

  String _bodyForStatus(Report report, StatusUpdate update) {
    final token = report.trackingToken;
    final message = (update.message ?? '').trim();
    if (message.isNotEmpty) {
      return '$token — $message';
    }
    switch (update.status) {
      case ReportStatus.submitted:
      case ReportStatus.underReview:
        return 'Your report $token was received by authorities.';
      case ReportStatus.inProgress:
        return 'Officers are investigating report $token.';
      case ReportStatus.verified:
        return 'Report $token has been verified.';
      case ReportStatus.resolved:
      case ReportStatus.completed:
        return 'Your report $token has been resolved.';
      case ReportStatus.closed:
        return 'Case $token has been closed.';
      case ReportStatus.rejected:
        return 'There was an update on report $token.';
    }
  }

  Future<List<AppNotification>> _fromAnnouncements(Set<String> readIds) async {
    try {
      final response =
          await _client.get<List<dynamic>>(ApiEndpoints.announcements);
      if (!response.isSuccess || response.data == null) return [];
      return response.data!.map((raw) {
        final json = raw as Map<String, dynamic>;
        final id = 'ann-${json['id']}';
        final publishedAt = json['publishedAt'] != null
            ? DateTime.parse(json['publishedAt'] as String)
            : DateTime.now();
        return AppNotification(
          id: id,
          title: json['title'] as String? ?? 'Announcement',
          body: json['body'] as String? ?? '',
          type: NotificationType.systemAlert,
          createdAt: publishedAt,
          isRead: readIds.contains(id),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AppNotification>> _fromReports(Set<String> readIds) async {
    await _reportRepository.refreshLocalReportsFromServer();
    final reports = await _localReports.getAllReports();
    final items = <AppNotification>[];

    for (final report in reports) {
      if (report.trackingToken.isEmpty) continue;
      final history = report.statusHistory;
      if (history.isEmpty) {
        final id = 'rpt-${report.id}-submitted';
        items.add(
          AppNotification(
            id: id,
            title: 'Report submitted',
            body:
                'Your report ${report.trackingToken} was submitted successfully.',
            type: NotificationType.reportUpdate,
            createdAt: report.createdAt,
            reportId: report.id,
            actionRoute: '/track',
            isRead: readIds.contains(id),
          ),
        );
        continue;
      }

      for (var i = 0; i < history.length; i++) {
        final update = history[i];
        final id =
            'rpt-${report.id}-${update.status.name}-${update.timestamp.toIso8601String()}-$i';
        items.add(
          AppNotification(
            id: id,
            title: _titleForStatus(update.status),
            body: _bodyForStatus(report, update),
            type: _typeForStatus(update.status),
            createdAt: update.timestamp,
            reportId: report.id,
            actionRoute: '/track',
            isRead: readIds.contains(id),
          ),
        );
      }
    }
    return items;
  }

  Future<List<AppNotification>> _buildAll() async {
    final readIds = _readIds();
    final announcements = await _fromAnnouncements(readIds);
    final reportUpdates = await _fromReports(readIds);
    final all = [...announcements, ...reportUpdates]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    try {
      final items = await _buildAll();
      return Success(List.unmodifiable(items));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(CacheException(e.toString()));
    }
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    final ids = _readIds()..add(notificationId);
    await _saveReadIds(ids);
    return const Success(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    final items = await _buildAll();
    final ids = _readIds()..addAll(items.map((n) => n.id));
    await _saveReadIds(ids);
    return const Success(null);
  }

  @override
  Stream<List<AppNotification>> watchNotifications() async* {
    yield await _buildAll();
  }
}
