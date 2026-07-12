import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter only ships Material/Cupertino/Widgets localizations for standard
/// locales. EcoWatch uses custom Twi (`tw`) and Fante (`fat`) for app strings,
/// so framework widgets fall back to English while [AppLocalizations] stays
/// in the user's chosen language.
class EcoMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const EcoMaterialLocalizationsDelegate();

  static const Locale _fallback = Locale('en');

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final target = GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : _fallback;
    return GlobalMaterialLocalizations.delegate.load(target);
  }

  @override
  bool shouldReload(EcoMaterialLocalizationsDelegate old) => false;
}

class EcoWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const EcoWidgetsLocalizationsDelegate();

  static const Locale _fallback = Locale('en');

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final target = GlobalWidgetsLocalizations.delegate.isSupported(locale)
        ? locale
        : _fallback;
    return GlobalWidgetsLocalizations.delegate.load(target);
  }

  @override
  bool shouldReload(EcoWidgetsLocalizationsDelegate old) => false;
}

class EcoCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const EcoCupertinoLocalizationsDelegate();

  static const Locale _fallback = Locale('en');

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final target = GlobalCupertinoLocalizations.delegate.isSupported(locale)
        ? locale
        : _fallback;
    return GlobalCupertinoLocalizations.delegate.load(target);
  }

  @override
  bool shouldReload(EcoCupertinoLocalizationsDelegate old) => false;
}

/// Delegates for [MaterialApp.localizationsDelegates].
const List<LocalizationsDelegate<dynamic>> ecoLocalizationDelegates = [
  EcoMaterialLocalizationsDelegate(),
  EcoWidgetsLocalizationsDelegate(),
  EcoCupertinoLocalizationsDelegate(),
];
