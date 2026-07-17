import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../models/report.dart';
import '../../models/tracking_token.dart';
import '../../models/enums.dart';
import '../../models/media.dart';
import '../../repositories/interfaces/report_repository.dart';
import '../../services/security/token_service.dart';
import '../../services/severity/severity_engine.dart';
import '../../services/offline/connectivity_service.dart';
import '../../services/offline/local_report_datasource.dart';
import '../../services/gis/location_enrichment_service.dart';
import '../../services/gis/location_label.dart';

/// Remote API contract — implement with HTTP client when backend is ready.
abstract class ReportRemoteDataSource {
  Future<Report> submitReport(Report report);
  Future<Report> fetchReport(String id);
  Future<Report> fetchByToken(String token);
  Future<List<Report>> fetchAll();
  Future<Report> updateStatus({
    required String reportId,
    required ReportStatus status,
    String? message,
    String? updatedBy,
  });
}

/// Mock remote responses for development without backend.
class MockReportRemoteDataSource implements ReportRemoteDataSource {
  final List<Report> _serverReports = [];

  @override
  Future<Report> submitReport(Report report) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final synced = report.copyWith(syncStatus: SyncStatus.synced);
    _serverReports.add(synced);
    return synced;
  }

  @override
  Future<Report> fetchReport(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _serverReports.firstWhere(
      (r) => r.id == id,
      orElse: () => throw const NotFoundException('Report not found'),
    );
  }

  @override
  Future<Report> fetchByToken(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _serverReports.firstWhere(
      (r) => r.trackingToken == token,
      orElse: () => throw const NotFoundException('Invalid tracking token'),
    );
  }

  @override
  Future<List<Report>> fetchAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(_serverReports);
  }

  @override
  Future<Report> updateStatus({
    required String reportId,
    required ReportStatus status,
    String? message,
    String? updatedBy,
  }) async {
    final index = _serverReports.indexWhere((r) => r.id == reportId);
    if (index < 0) throw const NotFoundException();
    final existing = _serverReports[index];
    final updated = existing.copyWith(
      status: status,
      updatedAt: DateTime.now(),
      statusHistory: [
        ...existing.statusHistory,
        StatusUpdate(
          status: status,
          timestamp: DateTime.now(),
          message: message,
          updatedBy: updatedBy,
        ),
      ],
    );
    _serverReports[index] = updated;
    return updated;
  }
}

/// Offline-first report repository orchestrating local + remote sources.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    required LocalReportDataSource local,
    required ReportRemoteDataSource remote,
    required ConnectivityService connectivity,
    required TokenService tokenService,
    required SeverityEngine severityEngine,
    LocationEnrichmentService? locationEnrichment,
  })  : _local = local,
        _remote = remote,
        _connectivity = connectivity,
        _tokenService = tokenService,
        _severityEngine = severityEngine,
        _locationEnrichment =
            locationEnrichment ?? const LocationEnrichmentService();

  final LocalReportDataSource _local;
  final ReportRemoteDataSource _remote;
  final ConnectivityService _connectivity;
  final TokenService _tokenService;
  final SeverityEngine _severityEngine;
  final LocationEnrichmentService _locationEnrichment;

  @override
  Future<Result<Report>> submitReport(Report report) async {
    try {
      final existing = await _local.getAllReports();
      final token = _tokenService.generateTrackingToken();
      final severity = _severityEngine.calculate(
        report,
        existingReports: existing,
      );
      final draft = report.copyWith(
        trackingToken: token,
        severity: severity,
        source: report.source,
        syncStatus: SyncStatus.pendingUpload,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        statusHistory: [
          StatusUpdate(
            status: ReportStatus.submitted,
            timestamp: DateTime.now(),
            message: 'Report submitted successfully',
          ),
        ],
      );

      await _local.saveReport(draft);

      if (await _connectivity.isOnline) {
        try {
          final synced = await _remote.submitReport(draft);
          await _upsertFromServer(synced);
          final saved = await _local.getReportByToken(synced.trackingToken) ?? synced;
          return Success(saved);
        } catch (e) {
          // Keep the local draft for later sync, but surface media/upload failures
          // so the user does not think evidence already reached admin.
          if (draft.media.any((m) => m.localPath.isNotEmpty)) {
            return Failure(
              NetworkException(
                e is AppException
                    ? e.message
                    : 'Report saved on device, but photo/video upload failed. Try sync again.',
              ),
            );
          }
          return Success(draft);
        }
      }
      return Success(draft);
    } catch (e) {
      return Failure(ValidationException(e.toString()));
    }
  }

  Report _mergeSyncedReport(Report local, Report synced) {
    final mergedMedia = <MediaAttachment>[];
    for (var i = 0; i < synced.media.length; i++) {
      final remote = synced.media[i];
      final localMedia = i < local.media.length ? local.media[i] : null;
      mergedMedia.add(
        remote.copyWith(
          localPath: (localMedia?.localPath.isNotEmpty ?? false)
              ? localMedia!.localPath
              : remote.localPath,
        ),
      );
    }
    if (local.media.length > synced.media.length) {
      mergedMedia.addAll(local.media.skip(synced.media.length));
    }
    return synced.copyWith(
      media: mergedMedia,
      syncStatus: SyncStatus.synced,
      communityName: LocationLabel.pickName(
        local.communityName,
        synced.communityName,
      ),
      location: LocationLabel.mergeLocation(local.location, synced.location),
    );
  }

  Future<Report> _enrichAndSave(Report report) async {
    if (!await _connectivity.isOnline) {
      await _local.saveReport(report);
      return report;
    }
    final enriched = await _locationEnrichment.enrichIfNeeded(report);
    await _local.saveReport(enriched);
    return enriched;
  }

  Future<void> _upsertFromServer(Report remote, {bool enrich = true}) async {
    final local = await _local.getReportByToken(remote.trackingToken) ??
        await _local.getReportById(remote.id);
    final merged =
        local != null ? _mergeSyncedReport(local, remote) : remote;
    if (local != null && local.id != merged.id) {
      await _local.deleteReport(local.id);
    }
    if (enrich) {
      await _enrichAndSave(merged);
    } else {
      await _local.saveReport(merged);
    }
  }

  @override
  Future<Result<Report>> uploadPendingReport(Report report) async {
    try {
      if (!await _connectivity.isOnline) {
        return const Failure(NetworkException('No internet connection'));
      }
      final synced = await _remote.submitReport(report);
      final merged = _mergeSyncedReport(report, synced);
      final enriched = await _enrichAndSave(merged);
      return Success(enriched);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  @override
  Future<Result<Report>> getReportById(String id) async {
    try {
      final local = await _local.getReportById(id);
      if (local != null) return Success(local);
      if (await _connectivity.isOnline) {
        return Success(await _remote.fetchReport(id));
      }
      return const Failure(NotFoundException());
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<Report>> getReportByTrackingToken(String token) async {
    try {
      if (await _connectivity.isOnline) {
        try {
          final remote = await _remote.fetchByToken(token);
          // Skip geocoding on lookup — status must return quickly on slow networks.
          await _upsertFromServer(remote, enrich: false);
          final updated = await _local.getReportByToken(token) ?? remote;
          return Success(updated);
        } on NotFoundException {
          return const Failure(NotFoundException('Invalid tracking token'));
        }
      }
      final local = await _local.getReportByToken(token);
      if (local != null) return Success(local);
      return const Failure(NotFoundException('Invalid tracking token'));
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<void>> refreshLocalReportsFromServer() async {
    try {
      if (!await _connectivity.isOnline) {
        return const Success(null);
      }
      final localReports = await _local.getAllReports();
      final toRefresh = localReports
          .where((r) => r.trackingToken.isNotEmpty)
          .toList();

      // Fetch status updates in parallel — sequential calls made home/track feel stuck.
      // Skip reverse-geocoding here; place names are filled on submit/track only.
      await Future.wait(
        toRefresh.map((report) async {
          try {
            final remote = await _remote.fetchByToken(report.trackingToken);
            await _upsertFromServer(remote, enrich: false);
          } catch (_) {
            // Keep cached copy when a single report cannot be refreshed.
          }
        }),
      );
      return const Success(null);
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<List<Report>>> getAllReports() async {
    try {
      return Success(await _local.getAllReports());
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<List<Report>>> getServerReports() async {
    try {
      if (!await _connectivity.isOnline) {
        return const Failure(NetworkException('No internet connection'));
      }
      return Success(await _remote.fetchAll());
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<List<Report>>> getReportsByStatus(String status) async {
    try {
      final reports = await _local.getAllReports();
      return Success(
        reports.where((r) => r.status.name == status).toList(),
      );
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<Report>> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? message,
    String? updatedBy,
  }) async {
    try {
      final local = await _local.getReportById(reportId);
      if (local == null) return const Failure(NotFoundException());

      final updated = local.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pendingUpdate,
        statusHistory: [
          ...local.statusHistory,
          StatusUpdate(
            status: status,
            timestamp: DateTime.now(),
            message: message,
            updatedBy: updatedBy,
          ),
        ],
      );
      await _local.saveReport(updated);

      if (await _connectivity.isOnline) {
        final synced = await _remote.updateStatus(
          reportId: reportId,
          status: status,
          message: message,
          updatedBy: updatedBy,
        );
        await _local.saveReport(synced.copyWith(syncStatus: SyncStatus.synced));
        return Success(synced);
      }
      return Success(updated);
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<List<Report>>> getPendingSyncReports() async {
    try {
      return Success(await _local.getPendingSyncReports());
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<void>> markReportSynced(String reportId) async {
    try {
      final report = await _local.getReportById(reportId);
      if (report == null) return const Failure(NotFoundException());
      await _local.saveReport(
        report.copyWith(syncStatus: SyncStatus.synced),
      );
      return const Success(null);
    } on AppException catch (e) {
      return Failure(e);
    }
  }

  @override
  Stream<List<Report>> watchLocalReports() async* {
    yield await _local.getAllReports();
  }
}

class TrackingTokenRepositoryImpl implements TrackingTokenRepository {
  TrackingTokenRepositoryImpl({
    required LocalTokenDataSource local,
    required TokenService tokenService,
  })  : _local = local,
        _tokenService = tokenService;

  final LocalTokenDataSource _local;
  final TokenService _tokenService;

  @override
  Future<Result<TrackingToken>> generateToken(String reportId) async {
    final token = TrackingToken(
      token: _tokenService.generateTrackingToken(),
      reportId: reportId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );
    await _local.saveToken(token);
    return Success(token);
  }

  @override
  Future<Result<TrackingToken>> getToken(String token) async {
    final tokens = await _local.getTokens();
    try {
      return Success(tokens.firstWhere((t) => t.token == token));
    } catch (_) {
      return const Failure(NotFoundException('Token not found'));
    }
  }

  @override
  Future<Result<List<TrackingToken>>> getLocalTokens() async {
    return Success(await _local.getTokens());
  }
}
