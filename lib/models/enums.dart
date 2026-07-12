/// Main environmental incident types for citizen reporting.
enum IncidentCategory {
  airPollution('Air Pollution', 'Harmful emissions and air quality issues'),
  waterPollution('Water Pollution', 'Contamination of rivers and water bodies'),
  illegalMining('Illegal Mining', 'Unauthorized galamsey and mining activity'),
  wasteDumping('Waste Dumping', 'Illegal waste disposal on land'),
  flooding('Flooding', 'Flooding, blocked drains, and overflow'),
  bushFire('Bush Fire', 'Bushfires and vegetation fires'),
  illegalLogging('Illegal Logging', 'Unauthorized logging and forest degradation'),
  chemicalSpill('Chemical Spill', 'Chemical emergencies requiring multi-agency response');

  const IncidentCategory(this.label, this.description);
  final String label;
  final String description;
}
/// Report submission channel for analytics (PRD §9).
enum ReportSource {
  app('Mobile App'),
  ussd('USSD');

  const ReportSource(this.label);
  final String label;
}

/// Lifecycle status of an environmental report.
///
/// Citizens see [submitted] → [inProgress] → [completed].
/// Admins work with [underReview] → [inProgress] → [resolved] in the dashboard.
enum ReportStatus {
  submitted('Submitted', 'Report received and pending review'),
  underReview('Under Review', 'Authorities are reviewing the report'),
  verified('Verified', 'Report confirmed by field officers'),
  inProgress('In Progress', 'Remediation or enforcement action underway'),
  completed('Completed', 'Your report has been fully addressed'),
  resolved('Resolved', 'Issue has been addressed'),
  rejected('Rejected', 'Report could not be verified'),
  closed('Closed', 'Case closed without further action');

  const ReportStatus(this.label, this.description);
  final String label;
  final String description;

  bool get isTerminal =>
      this == ReportStatus.completed ||
      this == ReportStatus.resolved ||
      this == ReportStatus.rejected ||
      this == ReportStatus.closed;
}

/// Severity levels from PRD additive score (0–6).
enum SeverityLevel {
  low(1, 'Low', 0xFF4CAF50),
  medium(2, 'Medium', 0xFFFFC107),
  high(3, 'High', 0xFFFF9800),
  critical(4, 'Critical', 0xFFF44336);

  const SeverityLevel(this.rank, this.label, this.colorHex);
  final int rank;
  final String label;
  final int colorHex;

  /// Maps PRD severity score (0–6) to a level.
  static SeverityLevel fromScore(int score) {
    if (score >= 5) return SeverityLevel.critical;
    if (score >= 3) return SeverityLevel.high;
    if (score >= 1) return SeverityLevel.medium;
    return SeverityLevel.low;
  }
}

/// Hotspot priority from DBSCAN density (PRD §7).
enum HotspotPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const HotspotPriority(this.label);
  final String label;

  static HotspotPriority fromDensityScore(double score, {int reportCount = 0}) {
    if (reportCount >= 12 || score >= 0.4) return HotspotPriority.critical;
    if (reportCount >= 8 || score >= 0.2) return HotspotPriority.high;
    if (reportCount >= 5 || score >= 0.1) return HotspotPriority.medium;
    return HotspotPriority.low;
  }
}

/// User roles for municipal platform RBAC.
enum UserRole {
  citizen('Citizen', 'Can submit and track reports'),
  superAdmin(
    'Super Administrator',
    'Municipal Assembly ICT — full platform access',
  ),
  municipalAdmin(
    'Municipal Administrator',
    'Municipality-wide monitoring and coordination',
  ),
  agencyAdmin(
    'Agency Administrator',
    'Manages incidents routed to their agency mandate',
  ),
  environmentalOfficer(
    'Environmental Officer',
    'Field investigator for assigned incidents',
  ),
  emergencyOfficer(
    'Emergency Response Officer',
    'Emergency incidents for Fire Service and NADMO',
  ),
  policeSupport(
    'Police Support',
    'Law enforcement support for criminal environmental offences',
  ),
  researcher('Researcher', 'Anonymized analytics and research export'),
  anonymous('Anonymous', 'Submit reports without account');

  const UserRole(this.label, this.description);
  final String label;
  final String description;

  bool get canAccessAdmin =>
      this == UserRole.superAdmin ||
      this == UserRole.municipalAdmin ||
      this == UserRole.agencyAdmin ||
      this == UserRole.environmentalOfficer ||
      this == UserRole.emergencyOfficer ||
      this == UserRole.policeSupport ||
      this == UserRole.researcher;
  bool get canAccessAnalytics => canAccessAdmin;
  bool get canVerifyReports =>
      this == UserRole.superAdmin ||
      this == UserRole.municipalAdmin ||
      this == UserRole.agencyAdmin ||
      this == UserRole.environmentalOfficer ||
      this == UserRole.emergencyOfficer ||
      this == UserRole.policeSupport;
  bool get canExportData =>
      this == UserRole.superAdmin ||
      this == UserRole.municipalAdmin ||
      this == UserRole.agencyAdmin ||
      this == UserRole.researcher;
}

/// Sync state for offline-first reports.
enum SyncStatus {
  synced,
  pendingUpload,
  pendingUpdate,
  conflict,
  failed,
}
