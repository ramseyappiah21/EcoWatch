import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_mappers.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';
import '../../models/tracking_token.dart';
import '../../repositories/interfaces/analytics_repository.dart';
import '../../services/gis/map_service.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl({
    required HeatmapManager heatmapManager,
    ApiClient? apiClient,
  })  : _heatmapManager = heatmapManager,
        _apiClient = apiClient;

  final HeatmapManager _heatmapManager;
  final ApiClient? _apiClient;

  @override
  Future<Result<AnalyticsSummary>> getSummary(AnalyticsPeriod period) async {
    if (_apiClient != null) {
      try {
        return Success(await _fetchFromApi(period));
      } catch (_) {
        // Fall through to local dummy data if API unavailable
      }
    }
    return _getDummySummary(period);
  }

  Future<AnalyticsSummary> _fetchFromApi(AnalyticsPeriod period) async {
    final response = await _apiClient!.get<Map<String, dynamic>>(
      ApiEndpoints.analytics,
      queryParams: {'period': period.name},
    );
    if (!response.isSuccess || response.data == null) {
      throw NetworkException('Failed to load analytics');
    }
    final data = response.data!;
    final now = DateTime.now();
    final days = period == AnalyticsPeriod.monthly
        ? 30
        : period == AnalyticsPeriod.daily
            ? 1
            : 7;

    final categoryRaw =
        (data['categoryBreakdown'] as Map<String, dynamic>? ?? {});
    final severityRaw =
        (data['severityBreakdown'] as Map<String, dynamic>? ?? {});
    final sourceRaw = (data['sourceBreakdown'] as Map<String, dynamic>? ?? {});
    final trendRaw = (data['dailyTrend'] as List<dynamic>? ?? []);
    final hotspotsRaw = (data['hotspots'] as List<dynamic>? ?? []);

    return AnalyticsSummary(
      period: period,
      startDate: now.subtract(Duration(days: days)),
      endDate: now,
      totalReports: data['totalReports'] as int? ?? 0,
      resolvedReports: data['resolvedReports'] as int? ?? 0,
      averageResolutionHours: 72,
      categoryBreakdown: {
        for (final e in categoryRaw.entries)
          parseIncidentCategory(e.key): e.value as int,
      },
      severityBreakdown: {
        for (final e in severityRaw.entries)
          parseSeverityLevel(e.key): e.value as int,
      },
      sourceBreakdown: {
        for (final e in sourceRaw.entries)
          parseReportSource(e.key): e.value as int,
      },
      dailyTrend: trendRaw
          .map(
            (item) => DailyReportCount(
              date: DateTime.parse((item as Map)['date'] as String),
              count: item['count'] as int? ?? 0,
              resolvedCount: 0,
            ),
          )
          .toList(),
      hotspots: hotspotsRaw.map((item) {
        final h = item as Map<String, dynamic>;
        final density = (h['densityScore'] as num?)?.toDouble() ?? 0;
        return Hotspot(
          id: h['id'] as String,
          latitude: (h['latitude'] as num).toDouble(),
          longitude: (h['longitude'] as num).toDouble(),
          intensity: density,
          reportCount: h['reportCount'] as int? ?? 0,
          dominantCategory:
              parseIncidentCategory(h['dominantCategory'] as String),
          densityScore: density,
          priority: parseHotspotPriority(h['priority'] as String? ?? 'low'),
          radiusMeters: (h['radiusMeters'] as num?)?.toDouble() ?? 1000,
        );
      }).toList(),
      hotspotGrowth: (data['hotspotGrowth'] as List<dynamic>? ?? [])
          .map(
            (item) => HotspotGrowthPoint(
              date: DateTime.parse((item as Map)['date'] as String),
              hotspotCount: item['hotspotCount'] as int? ?? 0,
              totalReportsInHotspots:
                  item['totalReportsInHotspots'] as int? ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<Result<AnalyticsSummary>> _getDummySummary(
    AnalyticsPeriod period,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final start = _periodStart(now, period);
    return Success(
      AnalyticsSummary(
        period: period,
        startDate: start,
        endDate: now,
        totalReports: 0,
        resolvedReports: 0,
        averageResolutionHours: 0,
        categoryBreakdown: const {},
        severityBreakdown: const {},
        sourceBreakdown: const {},
        dailyTrend: const [],
        hotspots: _heatmapManager.generateHotspots(const []),
        hotspotGrowth: const [],
      ),
    );
  }

  @override
  Future<Result<List<AnalyticsSummary>>> getHistoricalSummaries({
    required AnalyticsPeriod period,
    required int count,
  }) async {
    final summaries = <AnalyticsSummary>[];
    for (var i = 0; i < count; i++) {
      final result = await getSummary(period);
      if (result.isSuccess) summaries.add(result.dataOrNull!);
    }
    return Success(summaries);
  }

  @override
  Future<Result<Map<IncidentCategory, double>>> getCategoryTrends({
    required DateTime start,
    required DateTime end,
  }) async {
    final summary = await getSummary(AnalyticsPeriod.monthly);
    if (!summary.isSuccess) return Failure(summary.errorOrNull!);
    final breakdown = summary.dataOrNull!.categoryBreakdown;
    final total = breakdown.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const Success({});
    return Success({
      for (final e in breakdown.entries) e.key: e.value / total,
    });
  }

  DateTime _periodStart(DateTime now, AnalyticsPeriod period) =>
      switch (period) {
        AnalyticsPeriod.daily => now.subtract(const Duration(days: 1)),
        AnalyticsPeriod.weekly => now.subtract(const Duration(days: 7)),
        AnalyticsPeriod.monthly => now.subtract(const Duration(days: 30)),
      };
}
