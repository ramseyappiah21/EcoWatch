import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/help/presentation/help_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/main_shell.dart';
import '../features/maps/presentation/maps_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/privacy/presentation/privacy_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/report/presentation/report_incident_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/track/presentation/track_report_screen.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const report = '/report';
  static const track = '/track';
  static const maps = '/maps';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const settings = '/settings';
  static const privacy = '/privacy';
  static const help = '/help';
}

bool _requiresIntro(String location) {
  return location.startsWith(AppRoutes.home) ||
      location.startsWith(AppRoutes.maps) ||
      location.startsWith(AppRoutes.track) ||
      location.startsWith(AppRoutes.notifications) ||
      location.startsWith(AppRoutes.profile) ||
      location.startsWith(AppRoutes.report) ||
      location.startsWith(AppRoutes.settings) ||
      location.startsWith(AppRoutes.privacy) ||
      location.startsWith(AppRoutes.help);
}

GoRouter createAppRouter(ValueNotifier<bool> introSessionComplete) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: introSessionComplete,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final introDone = introSessionComplete.value;

      if (!introDone && _requiresIntro(location)) {
        return AppRoutes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.maps,
            builder: (context, state) => const MapsScreen(),
          ),
          GoRoute(
            path: AppRoutes.track,
            builder: (context, state) => TrackReportScreen(
              initialToken: state.uri.queryParameters['token'],
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (context, state) => const ReportIncidentScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (context, state) => const HelpScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
