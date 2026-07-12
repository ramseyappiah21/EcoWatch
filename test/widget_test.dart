import 'package:flutter_test/flutter_test.dart';

import 'package:ecowatch/models/enums.dart';
import 'package:ecowatch/models/media.dart';
import 'package:ecowatch/models/report.dart';
import 'package:ecowatch/services/gis/map_service.dart';
import 'package:ecowatch/services/mock/dummy_data.dart';
import 'package:ecowatch/services/severity/severity_engine.dart';

void main() {
  test('PRD severity engine scores additively up to 6', () {
    final engine = SeverityEngine();
    final now = DateTime.now();

    final report = Report(
      id: 'test_1',
      trackingToken: 'EW-TEST-0001',
      category: IncidentCategory.waterPollution,
      description: 'Test pollution report',
      location: const GeoLocation(latitude: 5.31, longitude: -1.98),
      status: ReportStatus.submitted,
      severity: SeverityLevel.low,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      media: [
        MediaAttachment(
          id: 'm1',
          type: MediaType.photo,
          localPath: '/test.jpg',
        ),
      ],
    );

    final nearby = [
      Report(
        id: 'test_2',
        trackingToken: 'EW-TEST-0002',
        category: IncidentCategory.illegalMining,
        description: 'Nearby mining',
        location: const GeoLocation(latitude: 5.3105, longitude: -1.9805),
        status: ReportStatus.submitted,
        severity: SeverityLevel.medium,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
        syncStatus: SyncStatus.synced,
      ),
    ];

    final score = engine.calculateScore(report, existingReports: nearby);
    expect(score, 6);
    expect(engine.calculate(report, existingReports: nearby),
        SeverityLevel.critical);
  });

  test('DBSCAN finds hotspot cluster with minPts=5', () {
    final manager = HeatmapManager(epsMeters: 1000, minPts: 5);
    final hotspots = manager.generateHotspots(DummyData.sampleReports);

    expect(hotspots, isNotEmpty);
    expect(hotspots.first.reportCount, greaterThanOrEqualTo(5));
    expect(hotspots.first.densityScore, greaterThan(0));
  });
}
