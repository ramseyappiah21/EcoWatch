import '../../models/enums.dart';
import '../../models/media.dart';
import '../../models/report.dart';
import '../../models/tracking_token.dart';

/// Seed data for development and demo without backend.
class DummyData {
  DummyData._();

  static final List<Report> sampleReports = [
    _report(
      id: 'rpt_001',
      token: 'EW-A1B2-C3D4',
      category: IncidentCategory.illegalMining,
      title: 'Galamsey activity near River Ankobra',
      description:
          'Observed excavators operating illegally near the river bank at night. '
          'Heavy sediment visible in the water.',
      lat: 5.3120,
      lng: -1.9850,
      status: ReportStatus.underReview,
      severity: SeverityLevel.critical,
      waterBodyNearby: true,
      community: 'Tarkwa Banso',
      daysAgo: 2,
      source: ReportSource.app,
      hasMedia: true,
    ),
    _report(
      id: 'rpt_002',
      token: 'EW-E5F6-G7H8',
      category: IncidentCategory.waterPollution,
      title: 'Discoloured water in community stream',
      description:
          'Stream water has turned reddish-brown. Possible chemical runoff from nearby mining.',
      lat: 5.3122,
      lng: -1.9848,
      status: ReportStatus.verified,
      severity: SeverityLevel.high,
      waterBodyNearby: true,
      community: 'Nsuaem',
      daysAgo: 5,
      source: ReportSource.ussd,
    ),
    _report(
      id: 'rpt_003',
      token: 'EW-I9J0-K1L2',
      category: IncidentCategory.illegalMining,
      title: 'Illegal dump site expanding',
      description:
          'Large quantities of plastic and industrial waste dumped near school grounds.',
      lat: 5.3118,
      lng: -1.9852,
      status: ReportStatus.inProgress,
      severity: SeverityLevel.medium,
      community: 'Tarkwa',
      daysAgo: 7,
      source: ReportSource.app,
    ),
    _report(
      id: 'rpt_004',
      token: 'EW-M3N4-O5P6',
      category: IncidentCategory.illegalMining,
      title: 'Forest clearing for mining',
      description:
          'Approximately 2 hectares of forest cleared without permits visible.',
      lat: 5.3121,
      lng: -1.9845,
      status: ReportStatus.submitted,
      severity: SeverityLevel.high,
      areaSqM: 20000,
      community: 'Teberebie',
      daysAgo: 1,
      source: ReportSource.ussd,
    ),
    _report(
      id: 'rpt_005',
      token: 'EW-Q7R8-S9T0',
      category: IncidentCategory.illegalMining,
      title: 'Pit mining in restricted zone',
      description: 'Multiple pits dug within 50m of residential area.',
      lat: 5.3119,
      lng: -1.9851,
      status: ReportStatus.resolved,
      severity: SeverityLevel.critical,
      waterBodyNearby: false,
      community: 'Cyanide',
      daysAgo: 14,
      source: ReportSource.app,
      hasMedia: true,
    ),
    _report(
      id: 'rpt_006',
      token: 'EW-U1V2-W3X4',
      category: IncidentCategory.waterPollution,
      title: 'Oil slick on pond',
      description: 'Fuel or oil contamination observed on surface of community pond.',
      lat: 5.3123,
      lng: -1.9849,
      status: ReportStatus.submitted,
      severity: SeverityLevel.medium,
      waterBodyNearby: true,
      community: 'Tarkwa',
      daysAgo: 0,
      source: ReportSource.ussd,
    ),
    _report(
      id: 'rpt_007',
      token: 'EW-Y5Z6-A7B8',
      category: IncidentCategory.airPollution,
      title: 'Dust clouds from blasting',
      description: 'Daily blasting creating dust affecting nearby homes.',
      lat: 5.2980,
      lng: -2.0010,
      status: ReportStatus.submitted,
      severity: SeverityLevel.medium,
      community: 'Nsuaem',
      daysAgo: 3,
      source: ReportSource.app,
    ),
    _report(
      id: 'rpt_008',
      token: 'EW-C9D0-E1F2',
      category: IncidentCategory.illegalMining,
      title: 'Night-time mining noise',
      description: 'Loud machinery operating past midnight near residential area.',
      lat: 5.3050,
      lng: -1.9900,
      status: ReportStatus.underReview,
      severity: SeverityLevel.low,
      community: 'Tarkwa',
      daysAgo: 4,
      source: ReportSource.ussd,
    ),
    _report(
      id: 'rpt_009',
      token: 'EW-G3H4-I5J6',
      category: IncidentCategory.illegalMining,
      title: 'Eroded hillside from mining',
      description: 'Visible soil erosion and gullies on hillside slope.',
      lat: 5.3200,
      lng: -1.9750,
      status: ReportStatus.submitted,
      severity: SeverityLevel.high,
      community: 'Teberebie',
      daysAgo: 6,
      source: ReportSource.app,
    ),
  ];

  static Report _report({
    required String id,
    required String token,
    required IncidentCategory category,
    required String title,
    required String description,
    required double lat,
    required double lng,
    required ReportStatus status,
    required SeverityLevel severity,
    required int daysAgo,
    ReportSource source = ReportSource.app,
    String? community,
    bool waterBodyNearby = false,
    double? areaSqM,
    bool hasMedia = false,
  }) {
    final created = DateTime.now().subtract(Duration(days: daysAgo));
    return Report(
      id: id,
      trackingToken: token,
      category: category,
      title: title,
      description: description,
      location: GeoLocation(
        latitude: lat,
        longitude: lng,
        address: community ?? 'Tarkwa-Nsuaem',
        landmark: community,
      ),
      status: status,
      severity: severity,
      source: source,
      createdAt: created,
      updatedAt: created.add(const Duration(hours: 4)),
      syncStatus: SyncStatus.synced,
      waterBodyNearby: waterBodyNearby,
      communityName: community,
      estimatedAreaSqMeters: areaSqM,
      isAnonymous: true,
      media: hasMedia
          ? [
              MediaAttachment(
                id: 'media_$id',
                type: MediaType.photo,
                localPath: '/mock/photo_$id.jpg',
              ),
            ]
          : [],
      statusHistory: [
        StatusUpdate(
          status: ReportStatus.submitted,
          timestamp: created,
          message: 'Report received',
        ),
        if (status != ReportStatus.submitted)
          StatusUpdate(
            status: status,
            timestamp: created.add(const Duration(hours: 4)),
            message: 'Status updated',
            updatedBy: 'Environmental Officer',
          ),
      ],
    );
  }

  static List<Hotspot> get sampleHotspots => sampleReports
      .map(
        (r) => Hotspot(
          id: 'hs_${r.id}',
          latitude: r.location.latitude,
          longitude: r.location.longitude,
          intensity: r.severity.rank / 4,
          reportCount: 1,
          dominantCategory: r.category,
          densityScore: 0.1,
          priority: HotspotPriority.low,
        ),
      )
      .toList();

  static List<TrackingToken> get sampleTokens => sampleReports
      .map(
        (r) => TrackingToken(
          token: r.trackingToken,
          reportId: r.id,
          createdAt: r.createdAt,
        ),
      )
      .toList();
}
