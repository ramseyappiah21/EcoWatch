import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../models/report.dart';
import '../../models/tracking_token.dart';

/// Local persistence for offline-first report storage.
abstract class LocalReportDataSource {
  Future<List<Report>> getAllReports();
  Future<Report?> getReportById(String id);
  Future<Report?> getReportByToken(String token);
  Future<void> saveReport(Report report);
  Future<void> deleteReport(String id);
  Future<List<Report>> getPendingSyncReports();
  Future<void> saveDraft(Map<String, dynamic> draft);
  Future<Map<String, dynamic>?> getDraft();
  Future<void> clearDraft();
}

class SharedPrefsReportDataSource implements LocalReportDataSource {
  SharedPrefsReportDataSource(this._prefs);

  final SharedPreferences _prefs;

  List<Report> _readReports() {
    final raw = _prefs.getString(AppConstants.cachedReportsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeReports(List<Report> reports) async {
    final encoded =
        jsonEncode(reports.map((r) => r.toJson()).toList());
    await _prefs.setString(AppConstants.cachedReportsKey, encoded);
  }

  @override
  Future<List<Report>> getAllReports() async => _readReports();

  @override
  Future<Report?> getReportById(String id) async {
    try {
      return _readReports().firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Report?> getReportByToken(String token) async {
    try {
      return _readReports().firstWhere((r) => r.trackingToken == token);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveReport(Report report) async {
    final reports = _readReports();
    final index = reports.indexWhere((r) => r.id == report.id);
    if (index >= 0) {
      reports[index] = report;
    } else {
      reports.insert(0, report);
    }
    await _writeReports(reports);
  }

  @override
  Future<void> deleteReport(String id) async {
    final reports = _readReports()..removeWhere((r) => r.id == id);
    await _writeReports(reports);
  }

  @override
  Future<List<Report>> getPendingSyncReports() async =>
      _readReports().where((r) => r.syncStatus.name.contains('pending')).toList();

  @override
  Future<void> saveDraft(Map<String, dynamic> draft) async {
    await _prefs.setString(AppConstants.reportDraftKey, jsonEncode(draft));
  }

  @override
  Future<Map<String, dynamic>?> getDraft() async {
    final raw = _prefs.getString(AppConstants.reportDraftKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> clearDraft() async {
    await _prefs.remove(AppConstants.reportDraftKey);
  }
}

abstract class LocalTokenDataSource {
  Future<List<TrackingToken>> getTokens();
  Future<void> saveToken(TrackingToken token);
}

class SharedPrefsTokenDataSource implements LocalTokenDataSource {
  SharedPrefsTokenDataSource(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<TrackingToken>> getTokens() async {
    final raw = _prefs.getString(AppConstants.trackingTokensKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => TrackingToken.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveToken(TrackingToken token) async {
    final tokens = await getTokens();
    tokens.insert(0, token);
    await _prefs.setString(
      AppConstants.trackingTokensKey,
      jsonEncode(tokens.map((t) => t.toJson()).toList()),
    );
  }
}
