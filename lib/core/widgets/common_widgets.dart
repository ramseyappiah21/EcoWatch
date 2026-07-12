import 'package:flutter/material.dart';

import '../../l10n/enum_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/enums.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity, this.compact = false});

  final SeverityLevel severity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Color(severity.colorHex);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        l10n.severityLabel(severity),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        context.l10n.statusLabel(status),
        style: const TextStyle(fontSize: 12),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.size = 24});

  final IncidentCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final icon = switch (category) {
      IncidentCategory.airPollution => Icons.cloud,
      IncidentCategory.waterPollution => Icons.water_drop,
      IncidentCategory.illegalMining => Icons.construction,
      IncidentCategory.wasteDumping => Icons.delete_outline,
      IncidentCategory.flooding => Icons.flood,
      IncidentCategory.bushFire => Icons.local_fire_department,
      IncidentCategory.illegalLogging => Icons.forest,
      IncidentCategory.chemicalSpill => Icons.science,
    };

    final color = switch (category) {
      IncidentCategory.airPollution => Colors.blueGrey,
      IncidentCategory.waterPollution => Colors.blue,
      IncidentCategory.illegalMining => Colors.amber.shade800,
      IncidentCategory.wasteDumping => Colors.brown,
      IncidentCategory.flooding => Colors.indigo,
      IncidentCategory.bushFire => Colors.deepOrange,
      IncidentCategory.illegalLogging => Colors.green.shade800,
      IncidentCategory.chemicalSpill => Colors.purple,
    };

    return Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: l10n.categoryLabel(category),
    );
  }
}

class EcoLoadingIndicator extends StatelessWidget {
  const EcoLoadingIndicator({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
