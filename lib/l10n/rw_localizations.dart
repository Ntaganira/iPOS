/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.l10n
 * - File      : rw_localizations.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Kinyarwanda fallback delegates for framework strings. Flutter's
 *               global Material/Widgets/Cupertino bundles do not ship `rw`, and
 *               the Localizations widget refuses to build Material controls
 *               without MaterialLocalizations. These delegates answer `rw` and
 *               load the English framework bundle, keeping our translated app
 *               strings while framework labels (dropdowns, dialogs, date
 *               pickers) degrade gracefully instead of crashing.
 * </pre>
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/app_localizations.dart';

const Locale _english = Locale('en');

bool _isRw(Locale locale) => locale.languageCode == 'rw';

/// Material framework strings for Kinyarwanda, backed by the English bundle.
class RwMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const RwMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isRw(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_english);

  @override
  bool shouldReload(RwMaterialLocalizationsDelegate old) => false;
}

/// Widgets framework strings for Kinyarwanda, backed by the English bundle.
class RwWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const RwWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isRw(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(_english);

  @override
  bool shouldReload(RwWidgetsLocalizationsDelegate old) => false;
}

/// Cupertino framework strings for Kinyarwanda, backed by the English bundle.
class RwCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const RwCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isRw(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_english);

  @override
  bool shouldReload(RwCupertinoLocalizationsDelegate old) => false;
}

/// Complete delegate set for the terminal and widget tests.
const List<LocalizationsDelegate<dynamic>> iposLocalizationsDelegates = [
  AppLocalizations.delegate,
  RwMaterialLocalizationsDelegate(),
  RwWidgetsLocalizationsDelegate(),
  RwCupertinoLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
