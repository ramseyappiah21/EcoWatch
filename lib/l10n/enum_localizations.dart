import '../models/enums.dart';
import '../models/pollution_types.dart';
import 'app_localizations.dart';

extension LocalizedEnums on AppLocalizations {
  String categoryLabel(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.airPollution:
        return categoryAir;
      case IncidentCategory.waterPollution:
        return categoryWater;
      case IncidentCategory.illegalMining:
        return categoryIllegalMining;
      case IncidentCategory.wasteDumping:
        return categoryWasteDumping;
      case IncidentCategory.flooding:
        return categoryFlooding;
      case IncidentCategory.bushFire:
      case IncidentCategory.illegalLogging:
      case IncidentCategory.chemicalSpill:
        return category.label;
    }
  }

  String statusLabel(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
        return statusSubmitted;
      case ReportStatus.underReview:
        return statusUnderReview;
      case ReportStatus.verified:
        return statusVerified;
      case ReportStatus.inProgress:
        return statusInProgress;
      case ReportStatus.completed:
        return statusCompleted;
      case ReportStatus.resolved:
        return statusResolved;
      case ReportStatus.rejected:
        return statusRejected;
      case ReportStatus.closed:
        return statusClosed;
    }
  }

  String severityLabel(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return severityLow;
      case SeverityLevel.medium:
        return severityMedium;
      case SeverityLevel.high:
        return severityHigh;
      case SeverityLevel.critical:
        return severityCritical;
    }
  }

  String specificPollutionLabel(SpecificPollutionType type) =>
      pollutionTypeLabel(type.name);
}
