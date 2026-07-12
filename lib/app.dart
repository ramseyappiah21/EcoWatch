import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'l10n/localization_delegates.dart';
import 'providers/dependency_injection.dart';
import 'routes/app_router.dart';
class EcoWatchApp extends ConsumerStatefulWidget {
  const EcoWatchApp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<EcoWatchApp> createState() => _EcoWatchAppState();
}

class _EcoWatchAppState extends ConsumerState<EcoWatchApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offlineSyncServiceProvider).startAutoSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    final languageCode = ref.watch(languageCodeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...ecoLocalizationDelegates,
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return supported.first;
        for (final supportedLocale in supported) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return supported.first;
      },
      routerConfig: widget.router,
    );
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final introSessionComplete = ValueNotifier<bool>(false);

  final router = createAppRouter(introSessionComplete);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        introSessionCompleteProvider.overrideWithValue(introSessionComplete),
      ],
      child: EcoWatchApp(router: router),
    ),
  );
}
