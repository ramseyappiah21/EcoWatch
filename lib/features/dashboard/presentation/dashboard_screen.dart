import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/report.dart';
import '../../../services/gis/location_label.dart';
import '../../../providers/dependency_injection.dart';
import '../../../routes/app_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Report> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(reportRepositoryProvider).getServerReports();
    if (!mounted) return;
    result.when(
      success: (reports) => setState(() {
        _reports = reports;
        _loading = false;
      }),
      failure: (e) => setState(() {
        _error = e.message;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Officer Dashboard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadReports,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final pending = _reports.where((r) => !r.status.isTerminal).length;
    final critical =
        _reports.where((r) => r.severity == SeverityLevel.critical).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.push(AppRoutes.analytics),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active Reports',
                    value: '$pending',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Critical',
                    value: '$critical',
                    icon: Icons.warning_amber,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Reports',
                    value: '${_reports.length}',
                    icon: Icons.assignment,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Resolved',
                    value:
                        '${_reports.where((r) => r.status == ReportStatus.resolved).length}',
                    icon: Icons.check_circle_outline,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Priority Queue', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_reports.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No reports yet. Submit one from the mobile app.'),
              )
            else
              ..._reports
                  .where((r) => r.severity.rank >= SeverityLevel.high.rank)
                  .map(
                    (report) => Card(
                      child: ListTile(
                        leading: CategoryIcon(category: report.category),
                        title: Text(report.title ?? report.category.label),
                        subtitle: Text(
                          '${LocationLabel.displayForReport(report)} • ${report.status.label}\n'
                          'Token: ${report.trackingToken}',
                        ),
                        isThreeLine: true,
                        trailing:
                            SeverityBadge(severity: report.severity, compact: true),
                        onTap: () => _showUpdateDialog(report.id),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(String reportId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Update Report Status')),
            ...ReportStatus.values.map(
              (status) => ListTile(
                title: Text(status.label),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(reportRepositoryProvider).updateReportStatus(
                        reportId: reportId,
                        status: status,
                        updatedBy: 'Environmental Officer',
                      );
                  await _loadReports();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Status updated to ${status.label}'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
