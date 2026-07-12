import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../models/analytics.dart';
import '../../../models/enums.dart';
import '../../../providers/dependency_injection.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.weekly;
  AnalyticsSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result =
        await ref.read(analyticsRepositoryProvider).getSummary(_period);
    if (mounted) {
      setState(() {
        _summary = result.dataOrNull;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const EcoLoadingIndicator(message: 'Loading analytics...')
          : _summary == null
              ? const EmptyStateWidget(
                  icon: Icons.analytics_outlined,
                  title: 'No data available',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<AnalyticsPeriod>(
                      segments: const [
                        ButtonSegment(
                          value: AnalyticsPeriod.daily,
                          label: Text('Daily'),
                        ),
                        ButtonSegment(
                          value: AnalyticsPeriod.weekly,
                          label: Text('Weekly'),
                        ),
                        ButtonSegment(
                          value: AnalyticsPeriod.monthly,
                          label: Text('Monthly'),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) {
                        setState(() => _period = s.first);
                        _load();
                      },
                    ),
                    const SizedBox(height: 16),
                    _SummaryRow(summary: _summary!),
                    const SizedBox(height: 24),
                    Text('Report Trend',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: _TrendChart(data: _summary!.dailyTrend),
                    ),
                    const SizedBox(height: 24),
                    Text('App vs USSD',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ..._summary!.sourceBreakdown.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              e.key == ReportSource.app
                                  ? Icons.phone_android
                                  : Icons.dialpad,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key.label)),
                            Text('${e.value}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Severity Trends',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: _SeverityChart(
                        breakdown: _summary!.severityBreakdown,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Hotspot Growth',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: _HotspotGrowthChart(
                        data: _summary!.hotspotGrowth,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('By Category',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ..._summary!.categoryBreakdown.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CategoryIcon(category: e.key, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key.label)),
                            Text('${e.value}'),
                          ],
                        ),
                      ),
                    ),
                    if (_summary!.hotspots.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Active Hotspots (DBSCAN)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ..._summary!.hotspots.map(
                        (h) => Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.whatshot,
                              color: Color(h.priority == HotspotPriority.critical
                                  ? 0xFFF44336
                                  : 0xFFFF9800),
                            ),
                            title: Text('${h.id} — ${h.priority.label} priority'),
                            subtitle: Text(
                              '${h.reportCount} reports • '
                              'density ${(h.densityScore * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Total',
            value: '${summary.totalReports}',
          ),
        ),
        Expanded(
          child: _MiniStat(
            label: 'Resolved',
            value: '${summary.resolvedReports}',
          ),
        ),
        Expanded(
          child: _MiniStat(
            label: 'Rate',
            value: '${(summary.resolutionRate * 100).toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final List<DailyReportCount> data;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble()))
                .toList(),
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityChart extends StatelessWidget {
  const _SeverityChart({required this.breakdown});

  final Map<SeverityLevel, int> breakdown;

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.toList();
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  entries[value.toInt()].key.label,
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value.toDouble(),
                color: Color(e.value.key.colorHex),
                width: 16,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _HotspotGrowthChart extends StatelessWidget {
  const _HotspotGrowthChart({required this.data});

  final List<HotspotGrowthPoint> data;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((e) =>
                    FlSpot(e.key.toDouble(), e.value.hotspotCount.toDouble()))
                .toList(),
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
