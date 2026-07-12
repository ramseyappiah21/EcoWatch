import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'tracking_token.dart';

/// Aggregated analytics for dashboards and reports (PRD §9).
class AnalyticsSummary extends Equatable {
  const AnalyticsSummary({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalReports,
    required this.resolvedReports,
    required this.averageResolutionHours,
    required this.categoryBreakdown,
    required this.severityBreakdown,
    required this.sourceBreakdown,
    required this.dailyTrend,
    required this.hotspots,
    required this.hotspotGrowth,
    this.predictedTrend,
  });

  final AnalyticsPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalReports;
  final int resolvedReports;
  final double averageResolutionHours;
  final Map<IncidentCategory, int> categoryBreakdown;
  final Map<SeverityLevel, int> severityBreakdown;
  final Map<ReportSource, int> sourceBreakdown;
  final List<DailyReportCount> dailyTrend;
  final List<Hotspot> hotspots;
  final List<HotspotGrowthPoint> hotspotGrowth;
  final TrendPrediction? predictedTrend;

  double get resolutionRate =>
      totalReports == 0 ? 0 : resolvedReports / totalReports;

  Map<String, dynamic> toJson() => {
        'period': period.name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'totalReports': totalReports,
        'resolvedReports': resolvedReports,
        'averageResolutionHours': averageResolutionHours,
        'categoryBreakdown':
            categoryBreakdown.map((k, v) => MapEntry(k.name, v)),
        'severityBreakdown':
            severityBreakdown.map((k, v) => MapEntry(k.name, v)),
        'sourceBreakdown':
            sourceBreakdown.map((k, v) => MapEntry(k.name, v)),
        'dailyTrend': dailyTrend.map((d) => d.toJson()).toList(),
        'hotspots': hotspots.map((h) => h.toJson()).toList(),
        'hotspotGrowth': hotspotGrowth.map((h) => h.toJson()).toList(),
        'predictedTrend': predictedTrend?.toJson(),
      };

  @override
  List<Object?> get props => [period, startDate, endDate, totalReports];
}

enum AnalyticsPeriod { daily, weekly, monthly }

class DailyReportCount extends Equatable {
  const DailyReportCount({
    required this.date,
    required this.count,
    required this.resolvedCount,
  });

  final DateTime date;
  final int count;
  final int resolvedCount;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'count': count,
        'resolvedCount': resolvedCount,
      };

  factory DailyReportCount.fromJson(Map<String, dynamic> json) =>
      DailyReportCount(
        date: DateTime.parse(json['date'] as String),
        count: json['count'] as int,
        resolvedCount: json['resolvedCount'] as int,
      );

  @override
  List<Object?> get props => [date, count];
}

class HotspotGrowthPoint extends Equatable {
  const HotspotGrowthPoint({
    required this.date,
    required this.hotspotCount,
    required this.totalReportsInHotspots,
  });

  final DateTime date;
  final int hotspotCount;
  final int totalReportsInHotspots;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'hotspotCount': hotspotCount,
        'totalReportsInHotspots': totalReportsInHotspots,
      };

  @override
  List<Object?> get props => [date, hotspotCount];
}

/// Placeholder for future ML-based trend prediction.
class TrendPrediction extends Equatable {
  const TrendPrediction({
    required this.predictedReportsNextWeek,
    required this.confidence,
    required this.risingCategories,
    required this.generatedAt,
  });

  final int predictedReportsNextWeek;
  final double confidence;
  final List<IncidentCategory> risingCategories;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'predictedReportsNextWeek': predictedReportsNextWeek,
        'confidence': confidence,
        'risingCategories':
            risingCategories.map((c) => c.name).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [predictedReportsNextWeek, confidence];
}
