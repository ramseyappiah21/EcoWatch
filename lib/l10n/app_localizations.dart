import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'extra_strings.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('tw'),
    Locale('fat'),
  ];

  static const languageNames = {
    'en': 'English',
    'tw': 'Twi',
    'fat': 'Fante',
  };

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String _t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ??
        ExtraStrings.values[lang]?[key] ??
        _strings['en']![key] ??
        ExtraStrings.values['en']![key] ??
        key;
  }

  // General
  String get appName => _t('appName');
  String get ok => _t('ok');
  String get back => _t('back');
  String get next => _t('next');
  String get skip => _t('skip');
  String get getStarted => _t('getStarted');
  String get all => _t('all');

  // Splash
  String get splashTagline => _t('splashTagline');
  String get splashLocation => _t('splashLocation');

  // Navigation
  String get navHome => _t('navHome');
  String get navMaps => _t('navMaps');
  String get navTrack => _t('navTrack');
  String get navAlerts => _t('navAlerts');
  String get navProfile => _t('navProfile');
  String get navReport => _t('navReport');

  // Onboarding
  String get onboardingWelcomeTitle => _t('onboardingWelcomeTitle');
  String get onboardingWelcomeDesc => _t('onboardingWelcomeDesc');
  String get onboardingReportTitle => _t('onboardingReportTitle');
  String get onboardingReportDesc => _t('onboardingReportDesc');
  String get onboardingTrackTitle => _t('onboardingTrackTitle');
  String get onboardingTrackDesc => _t('onboardingTrackDesc');
  String get onboardingMapTitle => _t('onboardingMapTitle');
  String get onboardingMapDesc => _t('onboardingMapDesc');
  String get onboardingUssdTitle => _t('onboardingUssdTitle');
  String onboardingUssdDesc(String code) =>
      _t('onboardingUssdDesc').replaceAll('{code}', code);

  // Home
  String get homeTitle => _t('homeTitle');
  String get protectEnvironment => _t('protectEnvironment');
  String get regionName => _t('regionName');
  String get reportIncident => _t('reportIncident');
  String get recentReports => _t('recentReports');
  String get noReportsYet => _t('noReportsYet');
  String get ussdDialogTitle => _t('ussdDialogTitle');
  String ussdDialogBody(String code) =>
      _t('ussdDialogBody').replaceAll('{code}', code);
  String reportListSubtitle(String community, String status, String token) =>
      _t('reportListSubtitle')
          .replaceAll('{community}', community)
          .replaceAll('{status}', status)
          .replaceAll('{token}', token);

  // Track
  String get trackTitle => _t('trackTitle');
  String get trackingToken => _t('trackingToken');
  String get lookingUpReport => _t('lookingUpReport');
  String get statusTimeline => _t('statusTimeline');
  String tokenLabel(String token) =>
      _t('tokenLabel').replaceAll('{token}', token);

  // Maps
  String get mapTitle => _t('mapTitle');
  String get toggleHeatmap => _t('toggleHeatmap');

  // Notifications
  String get notificationsTitle => _t('notificationsTitle');
  String get markAllRead => _t('markAllRead');
  String get noNotifications => _t('noNotifications');
  String get noNotificationsSubtitle => _t('noNotificationsSubtitle');
  String hoursAgo(int hours) =>
      _t('hoursAgo').replaceAll('{hours}', '$hours');
  String daysAgo(int days) => _t('daysAgo').replaceAll('{days}', '$days');

  // Profile
  String get profileTitle => _t('profileTitle');
  String get citizenReporter => _t('citizenReporter');
  String get anonymousReporting => _t('anonymousReporting');
  String get appearanceLanguage => _t('appearanceLanguage');
  String get personalise => _t('personalise');
  String get darkMode => _t('darkMode');
  String get darkModeSubtitle => _t('darkModeSubtitle');
  String get language => _t('language');
  String get settings => _t('settings');
  String get privacyPolicy => _t('privacyPolicy');
  String get helpSupport => _t('helpSupport');
  String get chooseLanguage => _t('chooseLanguage');
  String languageChanged(String language) =>
      _t('languageChanged').replaceAll('{language}', language);

  // Settings
  String get settingsTitle => _t('settingsTitle');
  String get preferences => _t('preferences');
  String get storedLocally => _t('storedLocally');
  String get pushNotifications => _t('pushNotifications');
  String get reportStatusUpdates => _t('reportStatusUpdates');
  String get anonymousDefault => _t('anonymousDefault');
  String get noPersonalData => _t('noPersonalData');
  String get syncOfflineReports => _t('syncOfflineReports');
  String get uploadPending => _t('uploadPending');
  String syncedReports(int synced, int total) => _t('syncedReports')
      .replaceAll('{synced}', '$synced')
      .replaceAll('{total}', '$total');

  // Enums
  String get categoryAir => _t('categoryAir');
  String get categoryWater => _t('categoryWater');
  String get categoryIllegalMining => _t('categoryIllegalMining');
  String get categoryWasteDumping => _t('categoryWasteDumping');
  String get categoryFlooding => _t('categoryFlooding');
  String get statusSubmitted => _t('statusSubmitted');
  String get statusUnderReview => _t('statusUnderReview');
  String get statusVerified => _t('statusVerified');
  String get statusInProgress => _t('statusInProgress');
  String get statusCompleted => _t('statusCompleted');
  String get statusResolved => _t('statusResolved');
  String get statusRejected => _t('statusRejected');
  String get statusClosed => _t('statusClosed');
  String get severityLow => _t('severityLow');
  String get severityMedium => _t('severityMedium');
  String get severityHigh => _t('severityHigh');
  String get severityCritical => _t('severityCritical');

  // Report flow
  String get done => _t('done');
  String get saveDraft => _t('saveDraft');
  String get draftSaved => _t('draftSaved');
  String get reportSubmitted => _t('reportSubmitted');
  String get saveTrackingToken => _t('saveTrackingToken');
  String get searchLocation => _t('searchLocation');
  String get searchLocationHint => _t('searchLocationHint');
  String get searchAction => _t('search');
  String get searchMinChars => _t('searchMinChars');
  String get noPlacesFound => _t('noPlacesFound');
  String get mainPollutionCategory => _t('mainPollutionCategory');
  String get mainPollutionCategoryHelper => _t('mainPollutionCategoryHelper');
  String get categoryRequired => _t('categoryRequired');
  String get incidentLocationSection => _t('incidentLocationSection');
  String get descriptionOptional => _t('descriptionOptional');
  String get descriptionHint => _t('descriptionHint');
  String get descriptionSection => _t('descriptionSection');
  String get incidentLocationName => _t('incidentLocationName');
  String get incidentLocationHint => _t('incidentLocationHint');
  String get nearWaterBody => _t('nearWaterBody');
  String get nearWaterBodySubtitle => _t('nearWaterBodySubtitle');
  String get submitAnonymously => _t('submitAnonymously');
  String get submitAnonymouslySubtitle => _t('submitAnonymouslySubtitle');
  String get photo => _t('photo');
  String get video => _t('video');
  String get takePhoto => _t('takePhoto');
  String get recordVideo => _t('recordVideo');
  String get choosePhotoFromFiles => _t('choosePhotoFromFiles');
  String get chooseVideoFromFiles => _t('chooseVideoFromFiles');
  String get desktopMediaHint => _t('desktopMediaHint');
  String get submitReport => _t('submitReport');
  String get privateReporting => _t('privateReporting');
  String get refreshGpsTooltip => _t('refreshGpsTooltip');
  String get locatingGps => _t('locatingGps');
  String get gpsSharedNote => _t('gpsSharedNote');
  String get gpsUnavailableNote => _t('gpsUnavailableNote');
  String incidentPinLabel(String coords, {bool lookingUp = false}) =>
      _t('incidentPinLabel')
          .replaceAll('{coords}', coords)
          .replaceAll('{suffix}', lookingUp ? _t('lookingUpName') : '');
  String get photoAttached => _t('photoAttached');
  String get videoAttached => _t('videoAttached');

  // Map extras
  String get mapTapHint => _t('mapTapHint');
  String get yourPositionPrivate => _t('yourPositionPrivate');
  String get incidentLocationShared => _t('incidentLocationShared');
  String get youPrivateLegend => _t('youPrivateLegend');
  String get youPrivateWaitingGps => _t('youPrivateWaitingGps');
  String get showBothPins => _t('showBothPins');
  String get loadingMap => _t('loadingMap');
  String mapIncidentSummary(int count) =>
      _t('mapIncidentSummary').replaceAll('{count}', '$count');

  // Help
  String get helpReportQuestion => _t('helpReportQuestion');
  String get helpReportAnswer => _t('helpReportAnswer');
  String get helpTrackQuestion => _t('helpTrackQuestion');
  String get helpTrackAnswer => _t('helpTrackAnswer');
  String get helpUssdQuestion => _t('helpUssdQuestion');
  String helpUssdAnswer(String code) =>
      _t('helpUssdAnswer').replaceAll('{code}', code);
  String get helpOfficerQuestion => _t('helpOfficerQuestion');
  String helpOfficerAnswer(String url) =>
      _t('helpOfficerAnswer').replaceAll('{url}', url);
  String get emergencyContacts => _t('emergencyContacts');
  String get couldNotLoadContacts => _t('couldNotLoadContacts');
  String get checkConnection => _t('checkConnection');
  String get contactSupport => _t('contactSupport');
  String couldNotDialPhone(String phone) =>
      _t('couldNotDialPhone').replaceAll('{phone}', phone);

  // Privacy
  String get privacyTitle => _t('privacyTitle');
  String get privacyNeverStoreTitle => _t('privacyNeverStoreTitle');
  String get privacyNeverStoreBody => _t('privacyNeverStoreBody');
  String get privacyCollectTitle => _t('privacyCollectTitle');
  String get privacyCollectBody => _t('privacyCollectBody');
  String get privacyTokensTitle => _t('privacyTokensTitle');
  String get privacyTokensBody => _t('privacyTokensBody');
  String get privacySharingTitle => _t('privacySharingTitle');
  String get privacySharingBody => _t('privacySharingBody');
  String get privacyRightsTitle => _t('privacyRightsTitle');
  String get privacyRightsBody => _t('privacyRightsBody');
  String get privacySecurityTitle => _t('privacySecurityTitle');
  String get privacySecurityBody => _t('privacySecurityBody');

  // Login
  String get loginOfficialAccess => _t('loginOfficialAccess');
  String get loginSubtitle => _t('loginSubtitle');
  String get email => _t('email');
  String get password => _t('password');
  String get emailRequired => _t('emailRequired');
  String get passwordMinLength => _t('passwordMinLength');
  String get loginDemoHint => _t('loginDemoHint');
  String get signIn => _t('signIn');
  String get continueWithoutAccount => _t('continueWithoutAccount');

  String pollutionTypeLabel(String typeName) => _t('pollution_$typeName');

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appName': 'EcoWatch Tarkwa',
      'ok': 'OK',
      'back': 'Back',
      'next': 'Next',
      'skip': 'Skip',
      'getStarted': 'Get Started',
      'all': 'All',
      'splashTagline': 'Environmental Monitoring',
      'splashLocation': 'Tarkwa • Ghana',
      'navHome': 'Home',
      'navMaps': 'Maps',
      'navTrack': 'Track',
      'navAlerts': 'Alerts',
      'navProfile': 'Profile',
      'navReport': 'Report',
      'onboardingWelcomeTitle': 'Welcome to EcoWatch Tarkwa',
      'onboardingWelcomeDesc':
          'Your community platform for reporting environmental harm and helping authorities protect air, water, and land in Tarkwa.',
      'onboardingReportTitle': 'Report Environmental Issues',
      'onboardingReportDesc':
          'Capture photos, GPS location, and details for illegal mining, water pollution, waste dumping, air pollution, and more.',
      'onboardingTrackTitle': 'Track Your Reports',
      'onboardingTrackDesc':
          'Receive a tracking token after each submission. Follow progress from submitted to in progress to completed — no account required.',
      'onboardingMapTitle': 'Community Heatmaps',
      'onboardingMapDesc':
          'See environmental hotspots on interactive maps so responders can focus action where it is needed most.',
      'onboardingUssdTitle': 'USSD Access',
      'onboardingUssdDesc':
          'No smartphone? Dial {code} to report incidents via USSD in local languages.',
      'homeTitle': 'EcoWatch',
      'protectEnvironment': 'Protect Tarkwa\'s Environment',
      'regionName': 'Tarkwa-Nsuaem Municipal Assembly',
      'reportIncident': 'Report an Incident',
      'recentReports': 'Recent Reports',
      'noReportsYet':
          'No reports yet. Tap Report to submit your first incident.',
      'ussdDialogTitle': 'Report via USSD',
      'ussdDialogBody':
          'Dial {code} from any mobile phone to report environmental incidents without internet.\n\nYour tracking token will be sent via SMS.',
      'reportListSubtitle': '{community} • {status}\nToken: {token}',
      'trackTitle': 'Track Report',
      'trackingToken': 'Tracking Token',
      'lookingUpReport': 'Looking up report...',
      'statusTimeline': 'Status Timeline',
      'tokenLabel': 'Token: {token}',
      'mapTitle': 'Environmental Map',
      'toggleHeatmap': 'Toggle heatmap',
      'notificationsTitle': 'Notifications',
      'markAllRead': 'Mark all read',
      'noNotifications': 'No notifications',
      'noNotificationsSubtitle': 'Report updates will appear here',
      'hoursAgo': '{hours}h ago',
      'daysAgo': '{days}d ago',
      'profileTitle': 'Profile',
      'citizenReporter': 'Citizen Reporter',
      'anonymousReporting': 'Anonymous reporting — no account needed',
      'appearanceLanguage': 'Appearance & Language',
      'personalise': 'Personalise how EcoWatch looks and reads',
      'darkMode': 'Dark Mode',
      'darkModeSubtitle': 'On by default for EcoWatch',
      'language': 'Language',
      'settings': 'Settings',
      'privacyPolicy': 'Privacy Policy',
      'helpSupport': 'Help & Support',
      'chooseLanguage': 'Choose language',
      'languageChanged': 'Language set to {language}',
      'settingsTitle': 'Settings',
      'preferences': 'Preferences',
      'storedLocally': 'Stored locally until backend sync',
      'pushNotifications': 'Push Notifications',
      'reportStatusUpdates': 'Report status updates',
      'anonymousDefault': 'Anonymous by Default',
      'noPersonalData': 'No personal data in reports',
      'syncOfflineReports': 'Sync Offline Reports',
      'uploadPending': 'Upload pending reports when online',
      'syncedReports': 'Synced {synced}/{total} reports',
      'categoryAir': 'Air Pollution',
      'categoryWater': 'Water Pollution',
      'categoryIllegalMining': 'Illegal Mining',
      'categoryWasteDumping': 'Waste Dumping',
      'categoryFlooding': 'Flooding',
      'statusSubmitted': 'Submitted',
      'statusUnderReview': 'Under Review',
      'statusVerified': 'Verified',
      'statusInProgress': 'In Progress',
      'statusCompleted': 'Completed',
      'statusResolved': 'Resolved',
      'statusRejected': 'Rejected',
      'statusClosed': 'Closed',
      'severityLow': 'Low',
      'severityMedium': 'Medium',
      'severityHigh': 'High',
      'severityCritical': 'Critical',
    },
    'tw': {
      'appName': 'EcoWatch Tarkwa',
      'ok': 'Yoo',
      'back': 'San kɔ',
      'next': 'Deɛ ɛdi hɔ',
      'skip': 'Huru',
      'getStarted': 'Hyɛ aseɛ',
      'all': 'Nyinaa',
      'splashTagline': 'Bɔho hwɛ Kwan',
      'splashLocation': 'Tarkwa • Ghana',
      'navHome': 'Fie',
      'navMaps': 'Map',
      'navTrack': 'Di nkyi',
      'navAlerts': 'Nkratoɔ',
      'navProfile': 'Wo ho nsɛm',
      'navReport': 'Bɔ dawuro',
      'onboardingWelcomeTitle': 'Akwaaba ba EcoWatch Tarkwa',
      'onboardingWelcomeDesc':
          'Wo kurom dwumadie a wobɛbɔ dawuro fa abɔdeɛ ho mmɔden ne sɛ wobegye mframa, nsuo ne asase ho ban wɔ Tarkwa.',
      'onboardingReportTitle': 'Bɔ Abɔdeɛ Ho Dawuro',
      'onboardingReportDesc':
          'Fa mfonini, GPS baabi, ne nsɛm a ɛfa illegal mining, nsuo fi, ahosiesie gu, mframa fi ne nea ɛkeka ho ho.',
      'onboardingTrackTitle': 'Di Wo Dawuro Nkyi',
      'onboardingTrackDesc':
          'Gye tracking token wɔ bere a wode dawuro no kɔ hɔ. Hwɛ sɛ ɛkɔ submitted, in progress, completed — account nhia.',
      'onboardingMapTitle': 'Kurom Heatmap',
      'onboardingMapDesc':
          'Hwɛ abɔdeɛ fi baabi wɔ map so na mmara dwumadie ntumi ayɛ adwuma wɔ baabi a ɛho hia.',
      'onboardingUssdTitle': 'USSD Kwan',
      'onboardingUssdDesc':
          'Wonni smartphone? Frɛ {code} na fa USSD so bɔ dawuro wɔ wo kasa mu.',
      'homeTitle': 'EcoWatch',
      'protectEnvironment': 'Bɔ Tarkwa Abɔdeɛ Ho Ban',
      'regionName': 'Tarkwa-Nsuaem Municipal Assembly',
      'reportIncident': 'Bɔ Abisadeɛ Ho Dawuro',
      'recentReports': 'Dawuro A Ɛnkyɛ',
      'noReportsYet':
          'Dawuro biara nni hɔ. Klik Report na fa wo dawuro a edi kan no kɔ.',
      'ussdDialogTitle': 'Fa USSD So Bɔ Dawuro',
      'ussdDialogBody':
          'Frɛ {code} wɔ mobile phone biara so na bɔ abɔdeɛ ho dawuro a internet nhia.\n\nWɔbɛmena wo tracking token ma wo wɔ SMS so.',
      'reportListSubtitle': '{community} • {status}\nToken: {token}',
      'trackTitle': 'Di Dawuro Nkyi',
      'trackingToken': 'Tracking Token',
      'lookingUpReport': 'Rehwehwɛ dawuro no...',
      'statusTimeline': 'Status Nkwantoa',
      'tokenLabel': 'Token: {token}',
      'mapTitle': 'Abɔdeɛ Map',
      'toggleHeatmap': 'Sesa heatmap',
      'notificationsTitle': 'Nkratoɔ',
      'markAllRead': 'Fa nyinaa sɛ wokenkan',
      'noNotifications': 'Nkratoɔ biara nni hɔ',
      'noNotificationsSubtitle': 'Dawuro mfomso bɛda hɔ',
      'hoursAgo': 'nnɛ {hours} dɔnhwerew a atwam',
      'daysAgo': 'nnɛ {days} da a atwam',
      'profileTitle': 'Wo Ho Nsɛm',
      'citizenReporter': 'Citizen Reporter',
      'anonymousReporting': 'Bɔ dawuro a wonnim wo — account nhia',
      'appearanceLanguage': 'Appearance ne Kasa',
      'personalise': 'Siesie sɛdeɛ EcoWatch da ne sɛdeɛ ɛkenkan',
      'darkMode': 'Dark Mode',
      'darkModeSubtitle': 'Ɛyɛ default ma EcoWatch',
      'language': 'Kasa',
      'settings': 'Settings',
      'privacyPolicy': 'Privacy Policy',
      'helpSupport': 'Mmoa ne Support',
      'chooseLanguage': 'Paw kasa',
      'languageChanged': 'Wɔayɛ kasa no {language}',
      'settingsTitle': 'Settings',
      'preferences': 'Nhyehyeɛ',
      'storedLocally': 'Wɔase gu device so kosi backend sync',
      'pushNotifications': 'Push Notifications',
      'reportStatusUpdates': 'Dawuro status mfomso',
      'anonymousDefault': 'Anonymous Mfiase',
      'noPersonalData': 'Wo ho nsɛm nni dawuro mu',
      'syncOfflineReports': 'Sync Offline Dawuro',
      'uploadPending': 'Fa dawuro a ɛretwɛn no kɔ bere a wɔwɔ internet so',
      'syncedReports': 'Wɔasync {synced}/{total} dawuro',
      'categoryAir': 'Mframa Fi',
      'categoryWater': 'Nsuo Fi',
      'categoryIllegalMining': 'Illegal Mining',
      'categoryWasteDumping': 'Gu Ahosiesie',
      'categoryFlooding': 'Nsuo A Ɛgu So',
      'statusSubmitted': 'Wɔde akɔ',
      'statusUnderReview': 'Wɔrehwɛ',
      'statusVerified': 'Wɔasi gyinae',
      'statusInProgress': 'Wɔreyɛ adwuma',
      'statusCompleted': 'Awie',
      'statusResolved': 'Wɔayɛ no yie',
      'statusRejected': 'Wɔampene',
      'statusClosed': 'Wɔato mu',
      'severityLow': 'Kakra',
      'severityMedium': 'Mfinimfini',
      'severityHigh': 'Kɛse',
      'severityCritical': 'Huam',
    },
    'fat': {
      'appName': 'EcoWatch Tarkwa',
      'ok': 'Yoo',
      'back': 'San kɔ',
      'next': 'Deɛ ɛdi hɔ',
      'skip': 'Fa',
      'getStarted': 'Fi ase',
      'all': 'Nyinaa',
      'splashTagline': 'Bɔho hwɛ Kwan',
      'splashLocation': 'Tarkwa • Ghana',
      'navHome': 'Fie',
      'navMaps': 'Map',
      'navTrack': 'Di nkyi',
      'navAlerts': 'Nkrato',
      'navProfile': 'Wo ho nsɛm',
      'navReport': 'Bɔ dawuro',
      'onboardingWelcomeTitle': 'Akwaaba ba EcoWatch Tarkwa',
      'onboardingWelcomeDesc':
          'Wo kurom dwumadie a wobɛbɔ dawuro fa abɔde ho mmɔden na wobegye mframa, nsuo ne asase ho ban wɔ Tarkwa.',
      'onboardingReportTitle': 'Bɔ Abɔde Ho Dawuro',
      'onboardingReportDesc':
          'Fa mfonini, GPS baabi, ne nsɛm a ɛfa illegal mining, nsuo fi, ahosiesie gu, mframa fi ne nea ɛka ho ho.',
      'onboardingTrackTitle': 'Di Wo Dawuro Nkyi',
      'onboardingTrackDesc':
          'Gye tracking token bere a wode dawuro no kɔ. Hwɛ sɛ ɛkɔ submitted, in progress, completed — account nhia.',
      'onboardingMapTitle': 'Kurom Heatmap',
      'onboardingMapDesc':
          'Hwɛ abɔde fi baabi wɔ map so na mmara dwumadie ntumi ayɛ adwuma wɔ baabi a ɛho hia.',
      'onboardingUssdTitle': 'USSD Kwan',
      'onboardingUssdDesc':
          'Wonni smartphone? Frɛ {code} na fa USSD so bɔ dawuro wɔ wo kasa mu.',
      'homeTitle': 'EcoWatch',
      'protectEnvironment': 'Bɔ Tarkwa Abɔde Ho Ban',
      'regionName': 'Tarkwa-Nsuaem Municipal Assembly',
      'reportIncident': 'Bɔ Abisade Ho Dawuro',
      'recentReports': 'Dawuro A Ɛnkyɛ',
      'noReportsYet':
          'Dawuro biara nni hɔ. Klik Report na fa wo dawuro a edi kan no kɔ.',
      'ussdDialogTitle': 'Fa USSD So Bɔ Dawuro',
      'ussdDialogBody':
          'Frɛ {code} wɔ mobile phone biara so na bɔ abɔde ho dawuro a internet nhia.\n\nWɔbɛma wo tracking token wɔ SMS so.',
      'reportListSubtitle': '{community} • {status}\nToken: {token}',
      'trackTitle': 'Di Dawuro Nkyi',
      'trackingToken': 'Tracking Token',
      'lookingUpReport': 'Rehwehwɛ dawuro no...',
      'statusTimeline': 'Status Nkwantoa',
      'tokenLabel': 'Token: {token}',
      'mapTitle': 'Abɔde Map',
      'toggleHeatmap': 'Sesa heatmap',
      'notificationsTitle': 'Nkrato',
      'markAllRead': 'Fa nyinaa sɛ wokenkan',
      'noNotifications': 'Nkrato biara nni hɔ',
      'noNotificationsSubtitle': 'Dawuro mfomso bɛda hɔ',
      'hoursAgo': 'nnɛ {hours} dɔnhwerew a atwam',
      'daysAgo': 'nnɛ {days} da a atwam',
      'profileTitle': 'Wo Ho Nsɛm',
      'citizenReporter': 'Citizen Reporter',
      'anonymousReporting': 'Bɔ dawuro a wonnim wo — account nhia',
      'appearanceLanguage': 'Appearance ne Kasa',
      'personalise': 'Siesie sɛdeɛ EcoWatch da ne sɛdeɛ ɛkenkan',
      'darkMode': 'Dark Mode',
      'darkModeSubtitle': 'Ɛyɛ default ma EcoWatch',
      'language': 'Kasa',
      'settings': 'Settings',
      'privacyPolicy': 'Privacy Policy',
      'helpSupport': 'Mmoa ne Support',
      'chooseLanguage': 'Paw kasa',
      'languageChanged': 'Wɔayɛ kasa no {language}',
      'settingsTitle': 'Settings',
      'preferences': 'Nhyehyeɛ',
      'storedLocally': 'Wɔase gu device so kosi backend sync',
      'pushNotifications': 'Push Notifications',
      'reportStatusUpdates': 'Dawuro status mfomso',
      'anonymousDefault': 'Anonymous Mfiase',
      'noPersonalData': 'Wo ho nsɛm nni dawuro mu',
      'syncOfflineReports': 'Sync Offline Dawuro',
      'uploadPending': 'Fa dawuro a ɛretwɛn no kɔ bere a wɔwɔ internet so',
      'syncedReports': 'Wɔasync {synced}/{total} dawuro',
      'categoryAir': 'Mframa Fi',
      'categoryWater': 'Nsuo Fi',
      'categoryIllegalMining': 'Illegal Mining',
      'categoryWasteDumping': 'Gu Ahosiesie',
      'categoryFlooding': 'Nsuo A Ɛgu So',
      'statusSubmitted': 'Wɔde akɔ',
      'statusUnderReview': 'Wɔrehwɛ',
      'statusVerified': 'Wɔasi gyinae',
      'statusInProgress': 'Wɔreyɛ adwuma',
      'statusCompleted': 'Awie',
      'statusResolved': 'Wɔayɛ no yie',
      'statusRejected': 'Wɔampene',
      'statusClosed': 'Wɔato mu',
      'severityLow': 'Kakra',
      'severityMedium': 'Mfinimfini',
      'severityHigh': 'Kɛse',
      'severityCritical': 'Huam',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations._strings.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
