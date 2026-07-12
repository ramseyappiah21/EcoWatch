import 'package:flutter/material.dart';

import '../../../l10n/l10n_extensions.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.privacyTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _Section(title: l10n.privacyNeverStoreTitle, body: l10n.privacyNeverStoreBody),
          _Section(title: l10n.privacyCollectTitle, body: l10n.privacyCollectBody),
          _Section(title: l10n.privacyTokensTitle, body: l10n.privacyTokensBody),
          _Section(title: l10n.privacySharingTitle, body: l10n.privacySharingBody),
          _Section(title: l10n.privacyRightsTitle, body: l10n.privacyRightsBody),
          _Section(title: l10n.privacySecurityTitle, body: l10n.privacySecurityBody),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(height: 1.5, color: Colors.grey.shade800)),
        ],
      ),
    );
  }
}
