import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'pollution_types.dart';

/// Geographic coordinate with optional accuracy metadata.
class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracyMeters,
    this.address,
    this.landmark,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracyMeters;
  final String? address;
  final String? landmark;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracyMeters': accuracyMeters,
        'address': address,
        'landmark': landmark,
      };

  factory GeoLocation.fromJson(Map<String, dynamic> json) => GeoLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        address: json['address'] as String?,
        landmark: json['landmark'] as String?,
      );

  GeoLocation copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracyMeters,
    String? address,
    String? landmark,
  }) =>
      GeoLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        altitude: altitude ?? this.altitude,
        accuracyMeters: accuracyMeters ?? this.accuracyMeters,
        address: address ?? this.address,
        landmark: landmark ?? this.landmark,
      );

  @override
  List<Object?> get props =>
      [latitude, longitude, altitude, accuracyMeters, address, landmark];
}

/// Photo or video evidence attached to a report.
class MediaAttachment extends Equatable {
  const MediaAttachment({
    required this.id,
    required this.type,
    required this.localPath,
    this.remoteUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.capturedAt,
    this.aiPrediction,
  });

  final String id;
  final MediaType type;
  final String localPath;
  final String? remoteUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final DateTime? capturedAt;
  final AiPredictionSummary? aiPrediction;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'localPath': localPath,
        'remoteUrl': remoteUrl,
        'mimeType': mimeType,
        'fileSizeBytes': fileSizeBytes,
        'capturedAt': capturedAt?.toIso8601String(),
        'aiPrediction': aiPrediction?.toJson(),
      };

  /// Returns null for legacy or unsupported types (e.g. removed voice notes).
  static MediaAttachment? tryFromJson(Map<String, dynamic> json) {
    final type = _parseMediaType(json['type'] as String?);
    if (type == null) return null;
    return MediaAttachment(
        id: json['id'] as String,
        type: type,
        localPath: json['localPath'] as String,
        remoteUrl: json['remoteUrl'] as String?,
        mimeType: json['mimeType'] as String?,
        fileSizeBytes: json['fileSizeBytes'] as int?,
        capturedAt: json['capturedAt'] != null
            ? DateTime.parse(json['capturedAt'] as String)
            : null,
        aiPrediction: json['aiPrediction'] != null
            ? AiPredictionSummary.fromJson(
                json['aiPrediction'] as Map<String, dynamic>,
              )
            : null,
      );
  }

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    final attachment = tryFromJson(json);
    if (attachment == null) {
      throw FormatException('Unsupported media type: ${json['type']}');
    }
    return attachment;
  }

  static MediaType? _parseMediaType(String? name) {
    if (name == null || name == 'audio') return null;
    return MediaType.values.byName(name);
  }

  MediaAttachment copyWith({
    String? localPath,
    String? remoteUrl,
    AiPredictionSummary? aiPrediction,
  }) =>
      MediaAttachment(
        id: id,
        type: type,
        localPath: localPath ?? this.localPath,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        mimeType: mimeType,
        fileSizeBytes: fileSizeBytes,
        capturedAt: capturedAt,
        aiPrediction: aiPrediction ?? this.aiPrediction,
      );

  @override
  List<Object?> get props => [id, type, localPath, remoteUrl];
}

enum MediaType { photo, video }

/// Lightweight AI prediction summary stored on media.
class AiPredictionSummary extends Equatable {
  const AiPredictionSummary({
    required this.mainCategory,
    required this.specificType,
    required this.confidence,
    required this.modelVersion,
  });

  final IncidentCategory mainCategory;
  final SpecificPollutionType specificType;
  final double confidence;
  final String modelVersion;

  Map<String, dynamic> toJson() => {
        'mainCategory': mainCategory.name,
        'specificType': specificType.name,
        'predictedCategory': specificType.name,
        'confidence': confidence,
        'modelVersion': modelVersion,
      };

  factory AiPredictionSummary.fromJson(Map<String, dynamic> json) =>
      AiPredictionSummary(
        mainCategory: normalizeMainCategory(
          (json['mainCategory'] ?? json['predictedCategory']) as String,
        ),
        specificType: SpecificPollutionType.tryParse(
              json['specificType'] as String? ??
                  json['predictedCategory'] as String?,
            ) ??
            SpecificPollutionType.hazardousLandWaste,
        confidence: (json['confidence'] as num).toDouble(),
        modelVersion: json['modelVersion'] as String,
      );

  @override
  List<Object?> get props => [mainCategory, specificType, confidence];
}
