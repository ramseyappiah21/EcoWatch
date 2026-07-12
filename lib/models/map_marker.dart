import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'report.dart';

/// Map marker representing a report or point of interest.
class MapMarker extends Equatable {
  const MapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.severity,
    this.reportId,
    this.title,
    this.isCluster = false,
    this.clusterCount = 1,
  });

  final String id;
  final double latitude;
  final double longitude;
  final IncidentCategory category;
  final SeverityLevel severity;
  final String? reportId;
  final String? title;
  final bool isCluster;
  final int clusterCount;

  factory MapMarker.fromReport(Report report) => MapMarker(
        id: 'marker_${report.id}',
        latitude: report.location.latitude,
        longitude: report.location.longitude,
        category: report.category,
        severity: report.severity,
        reportId: report.id,
        title: report.title ?? report.category.label,
      );

  @override
  List<Object?> get props => [id, latitude, longitude];
}

/// Cluster of nearby markers for map performance.
class MarkerCluster extends Equatable {
  const MarkerCluster({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.markers,
    required this.dominantSeverity,
  });

  final String id;
  final double latitude;
  final double longitude;
  final List<MapMarker> markers;
  final SeverityLevel dominantSeverity;

  int get count => markers.length;

  MapMarker toClusterMarker() => MapMarker(
        id: id,
        latitude: latitude,
        longitude: longitude,
        category: markers.first.category,
        severity: dominantSeverity,
        title: '$count reports',
        isCluster: true,
        clusterCount: count,
      );

  @override
  List<Object?> get props => [id, markers.length];
}
