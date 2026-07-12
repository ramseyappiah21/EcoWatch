import '../../core/constants/app_constants.dart';
import '../../models/media.dart';
import '../../models/report.dart';

/// Helpers for human-readable location labels vs raw coordinates.
abstract final class LocationLabel {
  static final _coordinatePattern = RegExp(
    r'^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$',
  );

  static bool isCoordinateLabel(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return _coordinatePattern.hasMatch(trimmed);
  }

  /// Best label for UI: community name, address, landmark — never raw coords.
  static String displayForReport(Report report, {String fallback = 'Tarkwa'}) {
    for (final candidate in [
      report.communityName,
      report.location.address,
      report.location.landmark,
    ]) {
      if (candidate != null &&
          candidate.trim().isNotEmpty &&
          !isCoordinateLabel(candidate)) {
        return candidate.trim();
      }
    }
    return fallback;
  }

  static String? sanitizeName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || isCoordinateLabel(trimmed)) return null;
    return trimmed;
  }

  static String? pickName(String? primary, String? secondary) {
    final a = sanitizeName(primary);
    if (a != null) return a;
    return sanitizeName(secondary);
  }

  static GeoLocation mergeLocation(GeoLocation local, GeoLocation remote) {
    final address = pickName(local.address, remote.address);
    final landmark = pickName(local.landmark, remote.landmark);
    return GeoLocation(
      latitude: remote.latitude,
      longitude: remote.longitude,
      altitude: remote.altitude ?? local.altitude,
      accuracyMeters: remote.accuracyMeters ?? local.accuracyMeters,
      address: address,
      landmark: landmark ?? address,
    );
  }

  static String regionFallback() => AppConstants.regionName.split(' ').first;
}
