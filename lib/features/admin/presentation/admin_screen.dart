import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/enums.dart';
import '../../../providers/dependency_injection.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('User Management'),
              subtitle: const Text('Manage roles and permissions (backend required)'),
              onTap: () => _showPlaceholder(context, 'User management connects to backend RBAC API'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Incident Categories'),
              subtitle: const Text('Configure monitored categories'),
              onTap: () => _showPlaceholder(context, 'Category config stored server-side'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Severity Rules'),
              subtitle: const Text('Adjust severity engine weights'),
              onTap: () => _showSeverityRules(context, ref),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('USSD Configuration'),
              subtitle: const Text('Africa\'s Talking integration pending'),
              onTap: () => _showPlaceholder(context, 'Configure USSD menus via backend webhook'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('AI Model Management'),
              subtitle: const Text('Upload TFLite models for classification'),
              onTap: () => _showPlaceholder(context, 'Model versioning via backend storage'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('Sync Status'),
              subtitle: const Text('Monitor offline queue and API health'),
              onTap: () async {
                final result =
                    await ref.read(offlineSyncServiceProvider).syncPendingReports();
                if (!context.mounted) return;
                result.when(
                  success: (p) => _showPlaceholder(
                    context,
                    'Pending: ${p.total}, Synced: ${p.synced}, Failed: ${p.failed}',
                  ),
                  failure: (e) => _showPlaceholder(context, e.message),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Available Roles', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...ref.read(rbacServiceProvider).availableRoles.map(
                (role) => ListTile(
                  dense: true,
                  leading: Icon(_roleIcon(role)),
                  title: Text(role.label),
                  subtitle: Text(role.description),
                ),
              ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole role) => switch (role) {
        UserRole.citizen => Icons.person,
        UserRole.superAdmin => Icons.admin_panel_settings,
        UserRole.municipalAdmin => Icons.account_balance,
        UserRole.agencyAdmin => Icons.apartment,
        UserRole.environmentalOfficer => Icons.badge,
        UserRole.emergencyOfficer => Icons.emergency,
        UserRole.policeSupport => Icons.local_police,
        UserRole.researcher => Icons.analytics,
        UserRole.anonymous => Icons.person_off,
      };

  void _showPlaceholder(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Integration Point'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSeverityRules(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Severity Engine Rules'),
        content: const Text(
          'PRD additive scoring (max 6):\n'
          '• Image included: +2\n'
          '• Nearby reports (1 km): +3\n'
          '• Recent report (24h): +1\n\n'
          'Hotspot detection uses DBSCAN (current clusters) plus predictive models (Random Forest, XGBoost, LSTM) for 7-day forecasts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}
