import 'dart:math' as math;

import '../../models/enums.dart';
import '../../models/media.dart';
import '../../models/report.dart';

/// PRD §8 severity scoring: additive 0–6 scale.
///
/// SeverityScore = ImageIncluded ? +2
///               + NearbyReports ? +3
///               + RecentReport ? +1
class SeverityEngine {
  SeverityEngine({
    this.nearbyRadiusMeters = 1000,
    this.recentReportWindow = const Duration(hours: 24),
  });

  final double nearbyRadiusMeters;
  final Duration recentReportWindow;

  int calculateScore(Report report, {List<Report> existingReports = const []}) {
    var score = 0;

    if (report.media.isNotEmpty) score += 2;

    final hasNearby = existingReports.any(
      (other) =>
          other.id != report.id &&
          _distanceMeters(report.location, other.location) <=
              nearbyRadiusMeters,
    );
    if (hasNearby) score += 3;

    final isRecent =
        DateTime.now().difference(report.createdAt) <= recentReportWindow;
    if (isRecent) score += 1;

    return score.clamp(0, 6);
  }

  SeverityLevel calculate(
    Report report, {
    List<Report> existingReports = const [],
  }) =>
      SeverityLevel.fromScore(
        calculateScore(report, existingReports: existingReports),
      );

  Map<String, int> explain(
    Report report, {
    List<Report> existingReports = const [],
  }) {
    final hasImage = report.media.isNotEmpty;
    final hasNearby = existingReports.any(
      (other) =>
          other.id != report.id &&
          _distanceMeters(report.location, other.location) <=
              nearbyRadiusMeters,
    );
    final isRecent =
        DateTime.now().difference(report.createdAt) <= recentReportWindow;

    return {
      'imageIncluded': hasImage ? 2 : 0,
      'nearbyReports': hasNearby ? 3 : 0,
      'recentReport': isRecent ? 1 : 0,
      'total': calculateScore(report, existingReports: existingReports),
    };
  }

  double _distanceMeters(GeoLocation a, GeoLocation b) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            sinLng *
            sinLng;
    return earthRadius * 2 * math.asin(math.sqrt(h));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}
