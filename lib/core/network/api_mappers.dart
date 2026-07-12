import '../../models/enums.dart';
import '../../models/pollution_types.dart';

/// Converts API snake_case values to Dart enum names.
String snakeToCamel(String value) {
  final parts = value.split('_');
  if (parts.length == 1) return value;
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
}

IncidentCategory parseIncidentCategory(String raw) =>
    normalizeMainCategory(raw);

ReportStatus parseReportStatus(String raw) =>
    ReportStatus.values.byName(snakeToCamel(raw));

SeverityLevel parseSeverityLevel(String raw) =>
    SeverityLevel.values.byName(snakeToCamel(raw));

ReportSource parseReportSource(String raw) =>
    ReportSource.values.byName(snakeToCamel(raw));

UserRole parseUserRole(String raw) => UserRole.values.byName(snakeToCamel(raw));

HotspotPriority parseHotspotPriority(String raw) =>
    HotspotPriority.values.byName(snakeToCamel(raw));

SyncStatus parseSyncStatus(String raw) =>
    SyncStatus.values.byName(snakeToCamel(raw));

/// Normalizes a report JSON payload from the REST API for [Report.fromJson].
Map<String, dynamic> normalizeReportJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  if (normalized['category'] is String) {
    normalized['category'] = normalizeMainCategory(normalized['category'] as String).name;
  }
  if (normalized['status'] is String) {
    normalized['status'] = snakeToCamel(normalized['status'] as String);
  }
  if (normalized['severity'] is String) {
    normalized['severity'] = snakeToCamel(normalized['severity'] as String);
  }
  if (normalized['source'] is String) {
    normalized['source'] = snakeToCamel(normalized['source'] as String);
  }
  if (normalized['syncStatus'] is String) {
    normalized['syncStatus'] = snakeToCamel(normalized['syncStatus'] as String);
  }
  if (normalized['aiSuggestedCategory'] is String) {
    normalized['aiSuggestedCategory'] =
        normalized['aiSuggestedCategory'] as String;
  }
  if (normalized['createdAt'] is String) {
    normalized['createdAt'] = DateTime.parse(normalized['createdAt'] as String)
        .toIso8601String();
  }
  if (normalized['updatedAt'] is String) {
    normalized['updatedAt'] = DateTime.parse(normalized['updatedAt'] as String)
        .toIso8601String();
  }
  final media = normalized['media'];
  if (media is List) {
    normalized['media'] = media.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      if (m['type'] == null && m['media_type'] != null) {
        m['type'] = m['media_type'];
      }
      if (m['id'] != null) m['id'] = m['id'].toString();
      m['localPath'] ??= '';
      m['remoteUrl'] ??= m['storage_url'] ?? m['storageUrl'];
      return m;
    }).toList();
  }
  final history = normalized['statusHistory'];
  if (history is List) {
    normalized['statusHistory'] = history.map((item) {
      final h = Map<String, dynamic>.from(item as Map);
      if (h['timestamp'] == null && h['created_at'] != null) {
        h['timestamp'] = h['created_at'];
      }
      if (h['status'] is String) {
        h['status'] = snakeToCamel(h['status'] as String);
      }
      return h;
    }).toList();
  }
  return normalized;
}
