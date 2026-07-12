import '../../core/errors/result.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';

/// Contract for analytics data — backend replaces mock implementation.
abstract class AnalyticsRepository {
  Future<Result<AnalyticsSummary>> getSummary(AnalyticsPeriod period);

  Future<Result<List<AnalyticsSummary>>> getHistoricalSummaries({
    required AnalyticsPeriod period,
    required int count,
  });

  Future<Result<Map<IncidentCategory, double>>> getCategoryTrends({
    required DateTime start,
    required DateTime end,
  });
}
