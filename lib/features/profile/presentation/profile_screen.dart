import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../providers/dependency_injection.dart';
import '../../../routes/app_router.dart';

/// Citizen profile — no admin login; officials use the web portal.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(languageCodeProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.chooseLanguage,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final entry in AppLocalizations.languageNames.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: current == entry.key
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, entry.key),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await ref.read(languageCodeProvider.notifier).setLanguage(selected);
      if (context.mounted) {
        final label = AppLocalizations.languageNames[selected] ?? selected;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.languageChanged(label))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final darkMode = ref.watch(darkModeProvider);
    final languageCode = ref.watch(languageCodeProvider);
    final languageLabel =
        AppLocalizations.languageNames[languageCode] ?? 'English';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            accountName: Text(l10n.citizenReporter),
            accountEmail: Text(l10n.anonymousReporting),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Icon(
                Icons.person_outline,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.appearanceLanguage),
            subtitle: Text(l10n.personalise),
          ),
          SwitchListTile(
            secondary: Icon(
              darkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            title: Text(l10n.darkMode),
            subtitle: Text(l10n.darkModeSubtitle),
            value: darkMode,
            onChanged: (value) =>
                ref.read(darkModeProvider.notifier).setEnabled(value),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(languageLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settings),
            onTap: () => context.push(AppRoutes.settings),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            onTap: () => context.push(AppRoutes.privacy),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l10n.helpSupport),
            onTap: () => context.push(AppRoutes.help),
          ),
        ],
      ),
    );
  }
}
