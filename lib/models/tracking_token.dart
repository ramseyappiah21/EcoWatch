import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'pollution_types.dart';
import 'report.dart';

/// Token issued to citizens for anonymous report tracking without login.
class TrackingToken extends Equatable {
  const TrackingToken({
    required this.token,
    required this.reportId,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
  });

  final String token;
  final String reportId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'token': token,
        'reportId': reportId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory TrackingToken.fromJson(Map<String, dynamic> json) => TrackingToken(
        token: json['token'] as String,
        reportId: json['reportId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        isActive: json['isActive'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [token, reportId];
}

/// DBSCAN hotspot for heatmap visualization (PRD §7).
class Hotspot extends Equatable {
  const Hotspot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.reportCount,
    required this.dominantCategory,
    required this.densityScore,
    required this.priority,
    this.radiusMeters = 1000,
    this.reports = const [],
  });

  final String id;
  final double latitude;
  final double longitude;
  final double intensity;
  final int reportCount;
  final IncidentCategory dominantCategory;
  final double densityScore;
  final HotspotPriority priority;
  final double radiusMeters;
  final List<Report> reports;

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'intensity': intensity,
        'reportCount': reportCount,
        'dominantCategory': dominantCategory.name,
        'densityScore': densityScore,
        'priority': priority.name,
        'radiusMeters': radiusMeters,
      };

  factory Hotspot.fromJson(Map<String, dynamic> json) => Hotspot(
        id: json['id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        intensity: (json['intensity'] as num).toDouble(),
        reportCount: json['reportCount'] as int,
        dominantCategory: normalizeMainCategory(json['dominantCategory'] as String),
        densityScore: (json['densityScore'] as num?)?.toDouble() ?? 0,
        priority: json['priority'] != null
            ? HotspotPriority.values.byName(json['priority'] as String)
            : HotspotPriority.low,
        radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 1000,
      );

  @override
  List<Object?> get props => [id, latitude, longitude, intensity];
}
