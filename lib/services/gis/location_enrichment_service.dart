import '../../models/report.dart';
import 'location_label.dart';
import 'reverse_geocoding_service.dart';

/// Fills in place names from coordinates when offline submit had no geocoder.
class LocationEnrichmentService {
  const LocationEnrichmentService({
    ReverseGeocodingService? geocoding,
  }) : _geocoding = geocoding ?? const ReverseGeocodingService();

  final ReverseGeocodingService _geocoding;

  Future<Report> enrichIfNeeded(Report report) async {
    final existing = LocationLabel.pickName(
      report.communityName,
      LocationLabel.pickName(
        report.location.address,
        report.location.landmark,
      ),
    );
    if (existing != null) {
      return report.copyWith(
        communityName: existing,
        location: report.location.copyWith(
          address: report.location.address ?? existing,
          landmark: report.location.landmark ?? existing,
        ),
      );
    }

    final resolved = await _geocoding.resolvePlaceName(report.location);
    if (resolved == null || resolved.trim().isEmpty) {
      return report;
    }

    final name = resolved.trim();
    return report.copyWith(
      communityName: name,
      location: report.location.copyWith(address: name, landmark: name),
    );
  }
}
