import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../providers/dependency_injection.dart';
import '../../../routes/app_router.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _reloadToken = 0;

  Future<void> _reload() async {
    setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationRepositoryProvider)
                  .markAllAsRead();
              await _reload();
            },
            child: Text(l10n.markAllRead),
          ),
        ],
      ),
      body: FutureBuilder(
        key: ValueKey(_reloadToken),
        future: ref.read(notificationRepositoryProvider).getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EcoLoadingIndicator();
          }
          final notifications = snapshot.data?.dataOrNull ?? [];
          if (notifications.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: l10n.noNotifications,
              subtitle: l10n.noNotificationsSubtitle,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markAsRead(n.id);
                  },
                  background: Container(
                    color: Colors.green,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.done, color: Colors.white),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.isRead
                          ? Colors.grey.shade200
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.notifications,
                        color: n.isRead ? Colors.grey : null,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight:
                            n.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(n.body),
                    trailing: Text(
                      _formatTime(l10n, n.createdAt),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () async {
                      await ref
                          .read(notificationRepositoryProvider)
                          .markAsRead(n.id);
                      if (!context.mounted) return;
                      if (n.actionRoute == '/track') {
                        context.go(AppRoutes.track);
                      } else {
                        await _reload();
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTime(AppLocalizations l10n, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    return l10n.daysAgo(diff.inDays);
  }
}
