import '../../core/errors/result.dart';
import '../../models/map_marker.dart';
import '../../models/tracking_token.dart';
import '../../models/enums.dart';
import '../../models/report.dart';

abstract class MapRepository {
  Future<Result<List<MapMarker>>> getMarkers({
    double? centerLat,
    double? centerLng,
    double? radiusKm,
  });

  Future<Result<List<Hotspot>>> getHotspots({
    IncidentCategory? categoryFilter,
  });

  Future<Result<List<Report>>> getReportsInBounds({
    required double northLat,
    required double southLat,
    required double eastLng,
    required double westLng,
  });
}
