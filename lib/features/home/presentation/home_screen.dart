import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../l10n/enum_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/media.dart';
import '../../../models/report.dart';
import '../../../services/gis/location_label.dart';
import '../../../providers/dependency_injection.dart';
import '../../../routes/app_router.dart';

/// Citizen home — report, track, and map. Shows locally submitted reports.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Report> _reports = [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Local-only on open — server refresh is pull-to-refresh / after submit.
    // Auto-refresh was too slow on iPhone Safari over hotspot.
    _loadLocalOnly();
  }

  Future<void> _loadLocalOnly() async {
    final reports = await ref.read(localReportDataSourceProvider).getAllReports();
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) {
      setState(() {
        _reports = reports;
        _loading = false;
      });
    }
  }

  Future<void> _loadReports({bool fromServer = false}) async {
    await _loadLocalOnly();
    if (!fromServer || !mounted) return;

    setState(() => _refreshing = true);
    // Don't block the UI on network — especially slow on iPhone Safari.
    unawaited(() async {
      try {
        await ref.read(reportRepositoryProvider).refreshLocalReportsFromServer();
        await _loadLocalOnly();
      } finally {
        if (mounted) setState(() => _refreshing = false);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    ref.listen<int>(reportsListVersionProvider, (previous, next) {
      if (previous != next) _loadLocalOnly();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadReports(fromServer: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroCard(
              onReport: () async {
                await context.push(AppRoutes.report);
                await _loadReports(fromServer: true);
              },
            ),
            const SizedBox(height: 16),
            _QuickActions(
              onTrack: () => context.go(AppRoutes.track),
              onMap: () => context.go(AppRoutes.maps),
              onUssd: () => _showUssdInfo(context),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.recentReports,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_reports.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.noReportsYet,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else
              ..._reports.take(10).map(
                    (report) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: _ReportLeading(report: report),
                        title: Text(report.title ?? l10n.categoryLabel(report.category)),
                        subtitle: Text(
                          l10n.reportListSubtitle(
                            LocationLabel.displayForReport(report),
                            l10n.statusLabel(report.status),
                            report.trackingToken,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: SeverityBadge(
                          severity: report.severity,
                          compact: true,
                        ),
                        onTap: () => context.go(
                          '${AppRoutes.track}?token=${Uri.encodeComponent(report.trackingToken)}',
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showUssdInfo(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ussdDialogTitle),
        content: Text(l10n.ussdDialogBody(AppConstants.ussdShortCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}

class _ReportLeading extends StatelessWidget {
  const _ReportLeading({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    for (final media in report.media) {
      if (media.type == MediaType.photo &&
          (media.remoteUrl?.isNotEmpty ?? false)) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            media.remoteUrl!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                CategoryIcon(category: report.category),
          ),
        );
      }
    }
    return CategoryIcon(category: report.category);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.protectEnvironment,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.regionName,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E7D32),
            ),
            onPressed: onReport,
            child: Text(l10n.reportIncident),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onTrack,
    required this.onMap,
    required this.onUssd,
  });

  final VoidCallback onTrack;
  final VoidCallback onMap;
  final VoidCallback onUssd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.track_changes,
            label: l10n.navTrack,
            onTap: onTrack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.map,
            label: l10n.navMaps,
            onTap: onMap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.phone,
            label: 'USSD',
            onTap: onUssd,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
