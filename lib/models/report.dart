import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'media.dart';
import 'pollution_types.dart';

/// Environmental incident report submitted by citizens or field officers.
class Report extends Equatable {
  const Report({
    required this.id,
    required this.trackingToken,
    required this.category,
    required this.description,
    required this.location,
    required this.status,
    required this.severity,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.source = ReportSource.app,
    this.title,
    this.media = const [],
    this.isAnonymous = true,
    this.reporterId,
    this.aiDetectedSubtype,
    this.aiConfidence,
    this.statusHistory = const [],
    this.notes,
    this.estimatedAreaSqMeters,
    this.waterBodyNearby = false,
    this.communityName,
  });

  final String id;
  final String trackingToken;
  final IncidentCategory category;
  final String? title;
  final String description;
  final GeoLocation location;
  final ReportStatus status;
  final SeverityLevel severity;
  final List<MediaAttachment> media;
  final bool isAnonymous;
  final String? reporterId;
  final SpecificPollutionType? aiDetectedSubtype;
  final double? aiConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final ReportSource source;
  final List<StatusUpdate> statusHistory;
  final String? notes;
  final double? estimatedAreaSqMeters;
  final bool waterBodyNearby;
  final String? communityName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackingToken': trackingToken,
        'category': category.name,
        'title': title,
        'description': description,
        'location': location.toJson(),
        'status': status.name,
        'severity': severity.name,
        'media': media.map((m) => m.toJson()).toList(),
        'isAnonymous': isAnonymous,
        'reporterId': reporterId,
        'aiSuggestedCategory': aiDetectedSubtype?.name,
        'aiConfidence': aiConfidence,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': syncStatus.name,
        'source': source.name,
        'statusHistory': statusHistory.map((s) => s.toJson()).toList(),
        'notes': notes,
        'estimatedAreaSqMeters': estimatedAreaSqMeters,
        'waterBodyNearby': waterBodyNearby,
        'communityName': communityName,
      };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        trackingToken: json['trackingToken'] as String,
        category: normalizeMainCategory(json['category'] as String),
        title: json['title'] as String?,
        description: json['description'] as String,
        location: GeoLocation.fromJson(json['location'] as Map<String, dynamic>),
        status: ReportStatus.values.byName(json['status'] as String),
        severity: SeverityLevel.values.byName(json['severity'] as String),
        media: (json['media'] as List<dynamic>? ?? [])
            .map((e) => MediaAttachment.tryFromJson(e as Map<String, dynamic>))
            .whereType<MediaAttachment>()
            .toList(),
        isAnonymous: json['isAnonymous'] as bool? ?? true,
        reporterId: json['reporterId'] as String?,
        aiDetectedSubtype: SpecificPollutionType.tryParse(
          json['aiSuggestedCategory'] as String?,
        ),
        aiConfidence: (json['aiConfidence'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        syncStatus: SyncStatus.values.byName(json['syncStatus'] as String),
        source: json['source'] != null
            ? ReportSource.values.byName(json['source'] as String)
            : ReportSource.app,
        statusHistory: (json['statusHistory'] as List<dynamic>? ?? [])
            .map((e) => StatusUpdate.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String?,
        estimatedAreaSqMeters:
            (json['estimatedAreaSqMeters'] as num?)?.toDouble(),
        waterBodyNearby: json['waterBodyNearby'] as bool? ?? false,
        communityName: json['communityName'] as String?,
      );

  Report copyWith({
    String? trackingToken,
    ReportStatus? status,
    SeverityLevel? severity,
    SyncStatus? syncStatus,
    List<MediaAttachment>? media,
    List<StatusUpdate>? statusHistory,
    DateTime? updatedAt,
    DateTime? createdAt,
    IncidentCategory? category,
    String? description,
    ReportSource? source,
    SpecificPollutionType? aiDetectedSubtype,
    String? communityName,
    GeoLocation? location,
  }) =>
      Report(
        id: id,
        trackingToken: trackingToken ?? this.trackingToken,
        category: category ?? this.category,
        title: title,
        description: description ?? this.description,
        location: location ?? this.location,
        status: status ?? this.status,
        severity: severity ?? this.severity,
        media: media ?? this.media,
        isAnonymous: isAnonymous,
        reporterId: reporterId,
        aiDetectedSubtype: aiDetectedSubtype ?? this.aiDetectedSubtype,
        aiConfidence: aiConfidence,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        source: source ?? this.source,
        statusHistory: statusHistory ?? this.statusHistory,
        notes: notes,
        estimatedAreaSqMeters: estimatedAreaSqMeters,
        waterBodyNearby: waterBodyNearby,
        communityName: communityName ?? this.communityName,
      );

  @override
  List<Object?> get props => [id, trackingToken, status, syncStatus];
}

/// Status change audit entry for report tracking.
class StatusUpdate extends Equatable {
  const StatusUpdate({
    required this.status,
    required this.timestamp,
    this.message,
    this.updatedBy,
  });

  final ReportStatus status;
  final DateTime timestamp;
  final String? message;
  final String? updatedBy;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        'updatedBy': updatedBy,
      };

  factory StatusUpdate.fromJson(Map<String, dynamic> json) => StatusUpdate(
        status: ReportStatus.values.byName(json['status'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        message: json['message'] as String?,
        updatedBy: json['updatedBy'] as String?,
      );

  @override
  List<Object?> get props => [status, timestamp];
}
