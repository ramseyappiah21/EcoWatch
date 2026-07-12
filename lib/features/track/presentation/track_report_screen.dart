import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../l10n/enum_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/report.dart';
import '../../../providers/dependency_injection.dart';

class TrackReportScreen extends ConsumerStatefulWidget {
  const TrackReportScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<TrackReportScreen> createState() => _TrackReportScreenState();
}

class _TrackReportScreenState extends ConsumerState<TrackReportScreen> {
  final _tokenController = TextEditingController();
  Report? _report;
  bool _loading = false;
  String? _error;
  String? _lastToken;

  @override
  void initState() {
    super.initState();
    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      _tokenController.text = token.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _track();
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _track({bool silent = false}) async {
    final token = _tokenController.text.trim().toUpperCase();
    if (token.isEmpty) return;

    _lastToken = token;

    // Show cached report immediately so Track never waits on the network.
    final local = await ref
        .read(localReportDataSourceProvider)
        .getReportByToken(token);
    if (!mounted) return;

    if (local != null) {
      setState(() {
        _report = local;
        _error = null;
        _loading = false;
      });
      // Refresh from server in background — do not block the UI.
      unawaited(_refreshFromServer(token));
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _report = null;
      });
    } else {
      setState(() => _loading = true);
    }

    await _refreshFromServer(token);
  }

  Future<void> _refreshFromServer(String token) async {
    final result =
        await ref.read(reportRepositoryProvider).getReportByTrackingToken(token);

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (report) {
        setState(() {
          _report = report;
          _error = null;
        });
        ref.read(reportsListVersionProvider.notifier).state++;
      },
      failure: (e) => setState(() {
        _error = e.message;
        if (_report == null) _report = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_lastToken != null) {
            _tokenController.text = _lastToken!;
          }
          await _track(silent: _report != null);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: l10n.trackingToken,
                hintText: 'EW-XXXX-XXXX',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _track,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _track(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              EcoLoadingIndicator(message: l10n.lookingUpReport),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_report != null) _ReportDetailCard(report: _report!),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailCard extends StatelessWidget {
  const _ReportDetailCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(category: report.category),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.title ?? l10n.categoryLabel(report.category),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SeverityBadge(severity: report.severity, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            StatusChip(status: report.status),
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(report.description),
            ],
            const Divider(height: 24),
            Text(
              l10n.tokenLabel(report.trackingToken),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.statusTimeline,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...report.statusHistory.map(
              (update) => ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 12),
                title: Text(l10n.statusLabel(update.status)),
                subtitle: Text(
                  '${update.timestamp.toLocal()}${update.message != null ? '\n${update.message}' : ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
