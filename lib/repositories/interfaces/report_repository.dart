import '../../core/errors/result.dart';
import '../../models/enums.dart';
import '../../models/report.dart';
import '../../models/tracking_token.dart';

abstract class ReportRepository {
  Future<Result<Report>> submitReport(Report report);

  Future<Result<Report>> getReportById(String id);

  Future<Result<Report>> getReportByTrackingToken(String token);

  Future<Result<List<Report>>> getAllReports();

  /// Fetch reports from server (dashboard / officer use).
  Future<Result<List<Report>>> getServerReports();

  Future<Result<List<Report>>> getReportsByStatus(String status);

  Future<Result<Report>> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? message,
    String? updatedBy,
  });

  Future<Result<List<Report>>> getPendingSyncReports();

  Future<Result<Report>> uploadPendingReport(Report report);

  Future<Result<void>> markReportSynced(String reportId);

  /// Pull latest status from the server for locally cached citizen reports.
  Future<Result<void>> refreshLocalReportsFromServer();

  Stream<List<Report>> watchLocalReports();
}

abstract class TrackingTokenRepository {
  Future<Result<TrackingToken>> generateToken(String reportId);

  Future<Result<TrackingToken>> getToken(String token);

  Future<Result<List<TrackingToken>>> getLocalTokens();
}
