import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../providers/dependency_injection.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.preferences),
            subtitle: Text(l10n.storedLocally),
          ),
          SwitchListTile(
            title: Text(l10n.pushNotifications),
            subtitle: Text(l10n.reportStatusUpdates),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l10n.syncOfflineReports),
            subtitle: Text(l10n.uploadPending),
            onTap: () async {
              final sync = ref.read(offlineSyncServiceProvider);
              final result = await sync.syncPendingReports();
              if (!context.mounted) return;
              result.when(
                success: (progress) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.syncedReports(progress.synced, progress.total),
                      ),
                    ),
                  );
                },
                failure: (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
