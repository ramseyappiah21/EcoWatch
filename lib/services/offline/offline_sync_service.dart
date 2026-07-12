import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../models/enums.dart';
import '../../models/report.dart';
import '../../repositories/interfaces/report_repository.dart';
import 'connectivity_service.dart';

/// Queues and syncs locally stored reports when connectivity is restored.
class OfflineSyncService {
  OfflineSyncService({
    required ReportRepository reportRepository,
    required ConnectivityService connectivity,
  })  : _reportRepository = reportRepository,
        _connectivity = connectivity;

  final ReportRepository _reportRepository;
  final ConnectivityService _connectivity;

  Future<Result<SyncProgress>> syncPendingReports() async {
    if (!await _connectivity.isOnline) {
      return const Failure(
        NetworkException('Cannot sync while offline'),
      );
    }

    final pendingResult = await _reportRepository.getPendingSyncReports();
    if (pendingResult.isFailure) {
      return Failure(pendingResult.errorOrNull!);
    }

    final pending = pendingResult.dataOrNull ?? [];
    var synced = 0;
    var failed = 0;

    for (final report in pending) {
      try {
        if (report.syncStatus == SyncStatus.pendingUpload) {
          final result = await _reportRepository.uploadPendingReport(report);
          if (result.isFailure) {
            failed++;
            continue;
          }
        } else if (report.syncStatus == SyncStatus.pendingUpdate) {
          await _reportRepository.updateReportStatus(
            reportId: report.id,
            status: report.status,
          );
        } else {
          await _reportRepository.markReportSynced(report.id);
        }
        synced++;
      } catch (_) {
        failed++;
      }
    }

    return Success(
      SyncProgress(total: pending.length, synced: synced, failed: failed),
    );
  }

  void startAutoSync() {
    _connectivity.onConnectivityChanged.listen((online) async {
      if (online) await syncPendingReports();
    });
  }
}

class SyncProgress {
  const SyncProgress({
    required this.total,
    required this.synced,
    required this.failed,
  });

  final int total;
  final int synced;
  final int failed;

  bool get isComplete => synced + failed >= total;
}
