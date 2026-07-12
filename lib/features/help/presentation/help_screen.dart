import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../providers/dependency_injection.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  Future<void> _callPhone(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotDialPhone(phone))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpSupport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpansionTile(
            title: Text(l10n.helpReportQuestion),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.helpReportAnswer),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(l10n.helpTrackQuestion),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.helpTrackAnswer),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(l10n.helpUssdQuestion),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.helpUssdAnswer(AppConstants.ussdShortCode)),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(l10n.helpOfficerQuestion),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.helpOfficerAnswer(AppConstants.adminPortalUrl)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.emergencyContacts,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          contactsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListTile(
              title: Text(l10n.couldNotLoadContacts),
              subtitle: Text(l10n.checkConnection),
            ),
            data: (contacts) => Column(
              children: contacts
                  .map(
                    (c) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.phone_in_talk_outlined),
                        title: Text(c.name),
                        subtitle: Text('${c.agency}\n${c.phone}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.call),
                          onPressed: () => _callPhone(context, c.phone),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(l10n.contactSupport),
            subtitle: const Text('support@ecowatch-tarkwa.gov.gh'),
          ),
        ],
      ),
    );
  }
}
