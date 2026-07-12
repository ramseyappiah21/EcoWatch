import '../../core/constants/app_constants.dart';
import '../../models/enums.dart';

/// USSD session request from Africa's Talking (PRD §5).
class UssdRequest {
  const UssdRequest({
    required this.sessionId,
    required this.phoneNumber,
    required this.serviceCode,
    required this.text,
    required this.networkCode,
  });

  final String sessionId;
  final String phoneNumber;
  final String serviceCode;
  /// Cumulative user input separated by * (e.g. "1*2*Mining near river")
  final String text;
  final String networkCode;

  List<String> get selections => text.isEmpty ? [] : text.split('*');

  String? get lastInput => selections.isEmpty ? null : selections.last;

  factory UssdRequest.fromJson(Map<String, dynamic> json) => UssdRequest(
        sessionId: json['sessionId'] as String,
        phoneNumber: json['phoneNumber'] as String,
        serviceCode: json['serviceCode'] as String,
        text: json['text'] as String? ?? '',
        networkCode: json['networkCode'] as String? ?? '',
      );
}

/// USSD response sent back to gateway.
class UssdResponse {
  const UssdResponse({
    required this.message,
    required this.endSession,
  });

  final String message;
  final bool endSession;

  String toGatewayFormat() => '${endSession ? 'END' : 'CON'} $message';

  Map<String, dynamic> toJson() => {
        'message': message,
        'endSession': endSession,
      };
}

/// Parsed USSD report payload ready for backend submission.
class UssdReportPayload {
  const UssdReportPayload({
    required this.category,
    required this.description,
    required this.community,
    required this.phoneNumber,
    required this.waterBodyNearby,
  });

  final IncidentCategory category;
  final String description;
  final String community;
  final String phoneNumber;
  final bool waterBodyNearby;

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'description': description,
        'community': community,
        'phoneNumber': phoneNumber,
        'waterBodyNearby': waterBodyNearby,
        'source': ReportSource.ussd.name,
      };
}

/// USSD menu flow handler — stateless; session state comes from [UssdRequest.text].
abstract class UssdService {
  UssdResponse handleRequest(UssdRequest request);
}

/// Mock USSD handler implementing the EcoWatch PRD menu tree.
class MockUssdService implements UssdService {
  static const _shortCode = AppConstants.ussdShortCode;

  @override
  UssdResponse handleRequest(UssdRequest request) {
    final level = request.selections.length;

    return switch (level) {
      0 => _mainMenu(),
      1 => _handleMainSelection(request.selections[0]),
      2 => _handleSecondLevel(request),
      3 => _handleThirdLevel(request),
      4 => _handleFourthLevel(request),
      5 => _handleDescriptionInput(request),
      _ => UssdResponse(
          message: 'Invalid input. Dial $_shortCode to start again.',
          endSession: true,
        ),
    };
  }

  UssdResponse _mainMenu() => UssdResponse(
        message: 'Welcome to EcoWatch Tarkwa\n'
            '1. Report Incident\n'
            '2. Track Report\n'
            '3. Privacy Information\n'
            '4. Help',
        endSession: false,
      );

  UssdResponse _handleMainSelection(String choice) => switch (choice) {
        '1' => const UssdResponse(
            message: 'Select category:\n'
                '1. Illegal Mining\n'
                '2. Water Pollution\n'
                '3. Waste Dumping\n'
                '4. Air Pollution\n'
                '5. Noise Pollution\n'
                '6. Deforestation\n'
                '7. Land Degradation\n'
                '8. Other',
            endSession: false,
          ),
        '2' => const UssdResponse(
            message: 'Enter tracking token (EW-XXXX-XXXX):',
            endSession: false,
          ),
        '3' => const UssdResponse(
            message: 'EcoWatch Privacy:\n'
                'We never store IMEI, device IDs, or IP addresses.\n'
                'Only your tracking token is saved for follow-up.',
            endSession: true,
          ),
        '4' => UssdResponse(
            message: 'EcoWatch: Report environmental issues in Tarkwa.\n'
                'Dial $_shortCode anytime.\n'
                'EPA support: 0302-664697',
            endSession: true,
          ),
        _ => const UssdResponse(
            message: 'Invalid option. Try again.',
            endSession: true,
          ),
      };

  UssdResponse _handleSecondLevel(UssdRequest request) {
    if (request.selections[0] == '2') {
      return const UssdResponse(
        message: 'Tracking report...\nStatus: Under Review\nThank you.',
        endSession: true,
      );
    }

    final categoryValid =
        RegExp(r'^[1-8]$').hasMatch(request.selections[1]);
    if (!categoryValid) {
      return const UssdResponse(message: 'Invalid category.', endSession: true);
    }

    return const UssdResponse(
      message: 'Enter community name:',
      endSession: false,
    );
  }

  UssdResponse _handleThirdLevel(UssdRequest request) {
    if (request.selections[0] == '2') {
      return const UssdResponse(
        message: 'Tracking report...\nStatus: Under Review\nThank you.',
        endSession: true,
      );
    }

    return const UssdResponse(
      message: 'Near water body?\n1. Yes\n2. No',
      endSession: false,
    );
  }

  UssdResponse _handleFourthLevel(UssdRequest request) {
    if (request.selections[0] == '2') {
      return const UssdResponse(
        message: 'Tracking report...\nStatus: Under Review\nThank you.',
        endSession: true,
      );
    }

    return const UssdResponse(
      message: 'Describe the incident:',
      endSession: false,
    );
  }

  UssdResponse _handleDescriptionInput(UssdRequest request) {
    final selections = request.selections;
    final category = _categoryFromChoice(selections[1]);
    final community = selections[2];
    final waterNearby = selections[3] == '1';
    final description = request.lastInput ?? 'USSD report';

    // Backend integration: POST UssdReportPayload to ApiEndpoints.reports
    // ignore: unused_local_variable
    final payload = UssdReportPayload(
      category: category,
      description: description,
      community: community,
      phoneNumber: request.phoneNumber,
      waterBodyNearby: waterNearby,
    );

    final mockToken =
        'EW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return UssdResponse(
      message: 'Report submitted!\nToken: $mockToken\n'
          'Save this to track your report.\nThank you.',
      endSession: true,
    );
  }

  IncidentCategory _categoryFromChoice(String choice) => switch (choice) {
        '1' => IncidentCategory.airPollution,
        '2' => IncidentCategory.waterPollution,
        '3' => IncidentCategory.illegalMining,
        '4' => IncidentCategory.wasteDumping,
        '5' => IncidentCategory.flooding,
        '6' => IncidentCategory.bushFire,
        '7' => IncidentCategory.illegalLogging,
        '8' => IncidentCategory.chemicalSpill,
        _ => IncidentCategory.wasteDumping,
      };
}
