import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' as http_parser;

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_mappers.dart';
import '../../core/network/dio_api_client.dart';
import '../../models/enums.dart';
import '../../models/media.dart';
import '../../models/report.dart';
import 'report_repository_impl.dart';

class HttpReportRemoteDataSource implements ReportRemoteDataSource {
  HttpReportRemoteDataSource(this._client);

  final DioApiClient _client;

  http_parser.MediaType _contentTypeFor(MediaAttachment media, String filename) {
    final mime = media.mimeType;
    if (mime != null && mime.contains('/')) {
      final parts = mime.split('/');
      return http_parser.MediaType(parts[0], parts[1]);
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return http_parser.MediaType('image', 'png');
    if (lower.endsWith('.webp')) return http_parser.MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return http_parser.MediaType('image', 'gif');
    if (lower.endsWith('.mp4')) return http_parser.MediaType('video', 'mp4');
    if (lower.endsWith('.mov')) {
      return http_parser.MediaType('video', 'quicktime');
    }
    if (media.type == MediaType.video) {
      return http_parser.MediaType('video', 'mp4');
    }
    return http_parser.MediaType('image', 'jpeg');
  }

  @override
  Future<Report> submitReport(Report report) async {
    final files = <MultipartFile>[];
    final expectedMedia = report.media.where((m) => m.localPath.isNotEmpty).toList();
    for (final media in expectedMedia) {
      final file = File(media.localPath);
      if (!await file.exists()) {
        throw NetworkException(
          'Attached media file is missing and could not be uploaded',
        );
      }
      final filename = media.localPath.split(RegExp(r'[\\/]')).last;
      files.add(
        await MultipartFile.fromFile(
          media.localPath,
          filename: filename.isEmpty ? 'evidence.jpg' : filename,
          contentType: _contentTypeFor(media, filename),
        ),
      );
    }

    final response = await _client.postMultipart(
      ApiEndpoints.reports,
      fields: {
        'category': report.category.name,
        'title': report.title ?? '',
        'description': report.description,
        'latitude': report.location.latitude.toString(),
        'longitude': report.location.longitude.toString(),
        if (report.location.accuracyMeters != null)
          'accuracyMeters': report.location.accuracyMeters.toString(),
        'address': report.location.address ?? report.communityName ?? '',
        'landmark': report.location.landmark ?? report.communityName ?? '',
        'communityName': report.communityName ?? '',
        'source': report.source.name,
        'isAnonymous': report.isAnonymous.toString(),
        'waterBodyNearby': report.waterBodyNearby.toString(),
        if (report.aiDetectedSubtype != null)
          'aiSuggestedCategory': report.aiDetectedSubtype!.name,
        if (report.aiConfidence != null)
          'aiConfidence': report.aiConfidence.toString(),
      },
      files: files,
    );

    if (!response.isSuccess || response.data == null) {
      throw NetworkException(response.message ?? 'Failed to submit report');
    }
    return Report.fromJson(normalizeReportJson(response.data!));
  }

  @override
  Future<Report> fetchReport(String id) async {
    throw const NetworkException('Single report fetch not implemented on server');
  }

  @override
  Future<Report> fetchByToken(String token) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.reportByToken(token),
    );
    if (response.statusCode == 404) {
      throw const NotFoundException('Invalid tracking token');
    }
    if (!response.isSuccess || response.data == null) {
      throw NetworkException(response.message ?? 'Failed to fetch report');
    }
    return Report.fromJson(normalizeReportJson(response.data!));
  }

  @override
  Future<List<Report>> fetchAll() async {
    final response = await _client.get<List<dynamic>>(ApiEndpoints.reports);
    if (!response.isSuccess || response.data == null) {
      throw NetworkException(response.message ?? 'Failed to fetch reports');
    }
    return response.data!
        .map((e) => Report.fromJson(
              normalizeReportJson(e as Map<String, dynamic>),
            ))
        .toList();
  }

  @override
  Future<Report> updateStatus({
    required String reportId,
    required ReportStatus status,
    String? message,
    String? updatedBy,
  }) async {
    final response = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiEndpoints.reportById(reportId)}/status',
      data: {
        'status': status.name,
        if (message != null) 'message': message,
      },
    );
    final data = response.data;
    if (response.statusCode == 404) throw const NotFoundException();
    if (data == null) {
      throw NetworkException('Failed to update status');
    }
    return Report.fromJson(normalizeReportJson(data));
  }
}
