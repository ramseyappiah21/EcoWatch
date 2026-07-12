import '../../models/enums.dart';
import '../../models/user.dart';

/// Client-side RBAC — server must enforce the same rules on API calls.
class RbacService {
  const RbacService();

  bool canSubmitReport(User? user) => true;

  bool canTrackReport(User? user) => true;

  bool canAccessDashboard(User? user) =>
      user != null && user.role.canAccessAdmin;

  bool canAccessAdmin(User? user) =>
      user != null && user.role.canAccessAdmin;

  bool canAccessAnalytics(User? user) =>
      user != null && user.role.canAccessAnalytics;

  bool canVerifyReports(User? user) =>
      user != null && user.role.canVerifyReports;

  bool canExportData(User? user) =>
      user != null && user.role.canExportData;

  bool canUpdateReportStatus(User? user, ReportStatus targetStatus) {
    if (user == null || !user.role.canVerifyReports) return false;
    return targetStatus == ReportStatus.verified ||
        targetStatus == ReportStatus.inProgress ||
        targetStatus == ReportStatus.resolved ||
        targetStatus == ReportStatus.underReview;
  }

  List<UserRole> get availableRoles => UserRole.values
      .where((r) => r != UserRole.anonymous)
      .toList();
}
