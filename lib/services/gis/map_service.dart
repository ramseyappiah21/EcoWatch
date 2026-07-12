import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../models/enums.dart';
import '../../models/map_marker.dart';
import '../../models/media.dart' show GeoLocation;
import '../../models/report.dart';
import '../../models/tracking_token.dart';
import '../../repositories/interfaces/map_repository.dart';
import '../mock/dummy_data.dart';
import 'reverse_geocoding_service.dart';

/// Abstraction over map providers (Google Maps, Mapbox, etc.).
abstract class MapService {
  Future<Result<GeoLocation>> getCurrentLocation();

  Future<Result<bool>> requestLocationPermission();

  /// Reverse-geocode coordinates into a human-readable place name.
  Future<String?> resolvePlaceName(GeoLocation location);

  /// Search for places by name (forward geocoding).
  Future<List<PlaceSearchResult>> searchPlaces(String query);

  Future<Result<List<MapMarker>>> getVisibleMarkers({
    required double centerLat,
    required double centerLng,
    required double zoom,
  });
}

/// DBSCAN hotspot detection (PRD §7: eps=1km, minPts=5).
class HeatmapManager {
  HeatmapManager({
    this.epsMeters = 1000,
    this.minPts = 5,
  });

  final double epsMeters;
  final int minPts;

  List<Hotspot> generateHotspots(List<Report> reports) {
    if (reports.length < minPts) return [];

    final visited = <int>{};
    final clusters = <List<Report>>[];

    for (var i = 0; i < reports.length; i++) {
      if (visited.contains(i)) continue;
      visited.add(i);

      final neighbors = _regionQuery(reports, i);
      if (neighbors.length < minPts) continue;

      final cluster = <Report>[reports[i]];
      final queue = List<int>.from(neighbors)..remove(i);

      while (queue.isNotEmpty) {
        final j = queue.removeAt(0);
        if (!visited.contains(j)) {
          visited.add(j);
          final jNeighbors = _regionQuery(reports, j);
          if (jNeighbors.length >= minPts) {
            for (final n in jNeighbors) {
              if (!queue.contains(n)) queue.add(n);
            }
          }
        }
        if (!cluster.any((r) => r.id == reports[j].id)) {
          cluster.add(reports[j]);
        }
      }

      if (cluster.length >= minPts) clusters.add(cluster);
    }

    return clusters.asMap().entries.map((entry) {
      final group = entry.value;
      final avgLat =
          group.map((r) => r.location.latitude).reduce((a, b) => a + b) /
              group.length;
      final avgLng =
          group.map((r) => r.location.longitude).reduce((a, b) => a + b) /
              group.length;

      final categoryCounts = <IncidentCategory, int>{};
      for (final r in group) {
        categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
      }
      final dominant = categoryCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      final densityScore = (group.length / (reports.length)).clamp(0.0, 1.0);
      final priority = HotspotPriority.fromDensityScore(
        densityScore,
        reportCount: group.length,
      );

      return Hotspot(
        id: 'hotspot_${entry.key + 1}',
        latitude: avgLat,
        longitude: avgLng,
        intensity: densityScore,
        reportCount: group.length,
        dominantCategory: dominant,
        densityScore: densityScore,
        priority: priority,
        radiusMeters: epsMeters,
        reports: group,
      );
    }).toList()
      ..sort((a, b) => b.densityScore.compareTo(a.densityScore));
  }

  List<int> _regionQuery(List<Report> reports, int index) {
    final result = <int>[];
    for (var i = 0; i < reports.length; i++) {
      if (_distanceMeters(reports[index].location, reports[i].location) <=
          epsMeters) {
        result.add(i);
      }
    }
    return result;
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

/// Simple distance-based marker clustering for map performance.
class MarkerClusterManager {
  MarkerClusterManager({this.clusterRadiusMeters = 300});

  final double clusterRadiusMeters;

  List<MapMarker> clusterMarkers(List<MapMarker> markers) {
    if (markers.length <= 1) return markers;

    final clustered = <String>{};
    final result = <MapMarker>[];

    for (var i = 0; i < markers.length; i++) {
      if (clustered.contains(markers[i].id)) continue;

      final group = <MapMarker>[markers[i]];
      clustered.add(markers[i].id);

      for (var j = i + 1; j < markers.length; j++) {
        if (clustered.contains(markers[j].id)) continue;
        if (_distanceMeters(markers[i], markers[j]) <= clusterRadiusMeters) {
          group.add(markers[j]);
          clustered.add(markers[j].id);
        }
      }

      if (group.length == 1) {
        result.add(group.first);
      } else {
        final cluster = MarkerCluster(
          id: 'cluster_${group.first.id}',
          latitude: group.map((m) => m.latitude).reduce((a, b) => a + b) /
              group.length,
          longitude: group.map((m) => m.longitude).reduce((a, b) => a + b) /
              group.length,
          markers: group,
          dominantSeverity: _dominantSeverity(group),
        );
        result.add(cluster.toClusterMarker());
      }
    }
    return result;
  }

  SeverityLevel _dominantSeverity(List<MapMarker> markers) {
    return markers
        .map((m) => m.severity)
        .reduce((a, b) => a.rank >= b.rank ? a : b);
  }

  double _distanceMeters(MapMarker a, MapMarker b) {
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

class GeolocatorMapService implements MapService {
  GeolocatorMapService(
    this._clusterManager, {
    ReverseGeocodingService? geocoding,
  }) : _geocoding = geocoding ?? const ReverseGeocodingService();

  final MarkerClusterManager _clusterManager;
  final ReverseGeocodingService _geocoding;

  @override
  Future<Result<GeoLocation>> getCurrentLocation() async {
    try {
      if (kIsWeb) {
        // iOS Safari only allows geolocation in a secure context (HTTPS / localhost).
        // Plain http://LAN-IP is blocked by the browser.
        final insecure = Uri.base.scheme != 'https' &&
            Uri.base.host != 'localhost' &&
            Uri.base.host != '127.0.0.1';
        if (insecure) {
          return const Failure(
            ValidationException(
              'GPS needs HTTPS on iPhone. Open the secure EcoWatch link, '
              'or pin the incident on the map / search for a place.',
            ),
          );
        }
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Failure(
          ValidationException(
            'Location services are off. Enable location in device settings.',
          ),
        );
      }

      final permitted = await requestLocationPermission();
      if (permitted.isFailure || permitted.dataOrNull != true) {
        return const Failure(
          ValidationException('Location permission denied'),
        );
      }

      if (!kIsWeb) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return Success(
            GeoLocation(
              latitude: lastKnown.latitude,
              longitude: lastKnown.longitude,
              accuracyMeters: lastKnown.accuracy,
              altitude: lastKnown.altitude,
            ),
          );
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
          timeLimit: Duration(seconds: kIsWeb ? 12 : 20),
        ),
      );

      return Success(
        GeoLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          altitude: position.altitude,
        ),
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('secure') ||
          message.contains('only secure origins') ||
          message.contains('insecure')) {
        return const Failure(
          ValidationException(
            'GPS needs HTTPS on iPhone. Open the secure EcoWatch link, '
            'or pin the incident on the map / search for a place.',
          ),
        );
      }
      return Failure(
        ValidationException('Could not get location: $e'),
      );
    }
  }

  @override
  Future<String?> resolvePlaceName(GeoLocation location) =>
      _geocoding.resolvePlaceName(location);

  @override
  Future<List<PlaceSearchResult>> searchPlaces(String query) =>
      _geocoding.searchPlaces(query);

  @override
  Future<Result<bool>> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const Success(false);
    }
    return const Success(true);
  }

  @override
  Future<Result<List<MapMarker>>> getVisibleMarkers({
    required double centerLat,
    required double centerLng,
    required double zoom,
  }) async {
    final markers =
        DummyData.sampleReports.map(MapMarker.fromReport).toList();
    return Success(_clusterManager.clusterMarkers(markers));
  }
}

class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl(this._heatmapManager);

  final HeatmapManager _heatmapManager;

  @override
  Future<Result<List<MapMarker>>> getMarkers({
    double? centerLat,
    double? centerLng,
    double? radiusKm,
  }) async {
    final markers =
        DummyData.sampleReports.map(MapMarker.fromReport).toList();
    return Success(markers);
  }

  @override
  Future<Result<List<Hotspot>>> getHotspots({
    IncidentCategory? categoryFilter,
  }) async {
    var reports = DummyData.sampleReports;
    if (categoryFilter != null) {
      reports = reports.where((r) => r.category == categoryFilter).toList();
    }
    return Success(_heatmapManager.generateHotspots(reports));
  }

  @override
  Future<Result<List<Report>>> getReportsInBounds({
    required double northLat,
    required double southLat,
    required double eastLng,
    required double westLng,
  }) async {
    final filtered = DummyData.sampleReports.where((r) {
      return r.location.latitude <= northLat &&
          r.location.latitude >= southLat &&
          r.location.longitude <= eastLng &&
          r.location.longitude >= westLng;
    }).toList();
    return Success(filtered);
  }
}
