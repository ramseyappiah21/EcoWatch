import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/media.dart';

/// A place returned from a forward location search.
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

/// Resolves GPS coordinates to a human-readable place name and searches places.
///
/// Uses the platform geocoder on mobile; falls back to OpenStreetMap Nominatim
/// via Dio (works on web, desktop, and mobile).
class ReverseGeocodingService {
  const ReverseGeocodingService();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'EcoWatch-Tarkwa/1.0 (civic reporting)',
        'Accept': 'application/json',
      },
    ),
  );

  Future<String?> resolvePlaceName(GeoLocation location) async {
    if (!kIsWeb) {
      final native = await _fromPlatformGeocoder(location);
      if (native != null) return native;
    }

    return _fromNominatim(location.latitude, location.longitude);
  }

  Future<String?> _fromPlatformGeocoder(GeoLocation location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isEmpty) return null;
      return _formatPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fromNominatim(double latitude, double longitude) async {
    try {
      final response = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '14',
          'addressdetails': '1',
        },
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final json = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;
      return _formatNominatim(json);
    } catch (_) {
      return null;
    }
  }

  String? _formatPlacemark(Placemark place) {
    final parts = <String>{
      if (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
        place.subLocality!.trim(),
      if (place.locality != null && place.locality!.trim().isNotEmpty)
        place.locality!.trim(),
      if (place.subAdministrativeArea != null &&
          place.subAdministrativeArea!.trim().isNotEmpty)
        place.subAdministrativeArea!.trim(),
      if (place.administrativeArea != null &&
          place.administrativeArea!.trim().isNotEmpty)
        place.administrativeArea!.trim(),
      if (place.country != null && place.country!.trim().isNotEmpty)
        place.country!.trim(),
    };
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  String? _formatNominatim(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is Map<String, dynamic>) {
      final parts = <String>{
        for (final key in [
          'neighbourhood',
          'suburb',
          'village',
          'town',
          'city',
          'county',
          'state',
          'country',
        ])
          if (address[key] is String &&
              (address[key] as String).trim().isNotEmpty)
            (address[key] as String).trim(),
      };
      if (parts.isNotEmpty) return parts.join(', ');
    }

    final display = json['display_name'];
    if (display is String && display.trim().isNotEmpty) {
      final segments = display.split(', ').take(3).toList();
      return segments.join(', ');
    }
    return null;
  }

  /// Search for places by name — biased toward Ghana / Tarkwa region.
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    if (!kIsWeb) {
      final native = await _searchFromPlatformGeocoder(trimmed, limit);
      if (native.isNotEmpty) return native;
    }

    final local =
        await _searchFromNominatim(trimmed, limit: limit, bounded: true);
    if (local.isNotEmpty) return local;
    return _searchFromNominatim(trimmed, limit: limit, bounded: false);
  }

  Future<List<PlaceSearchResult>> _searchFromPlatformGeocoder(
    String query,
    int limit,
  ) async {
    try {
      final locations = await locationFromAddress(query);
      return locations.take(limit).map((loc) {
        return PlaceSearchResult(
          displayName: query,
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PlaceSearchResult>> _searchFromNominatim(
    String query, {
    required int limit,
    bool bounded = true,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'countrycodes': 'gh',
      };
      if (bounded) {
        params['viewbox'] = '-2.15,5.15,-1.85,5.45';
        params['bounded'] = '1';
      }

      final response = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: params,
      );
      if (response.statusCode != 200 || response.data == null) return [];

      final list = response.data is List
          ? response.data as List<dynamic>
          : jsonDecode(response.data.toString()) as List<dynamic>;

      return list.map((item) {
        final json = item as Map<String, dynamic>;
        final name = json['display_name'] as String? ?? query;
        final shortName = name.split(', ').take(3).join(', ');
        return PlaceSearchResult(
          displayName: shortName,
          latitude: double.parse(json['lat'] as String),
          longitude: double.parse(json['lon'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
