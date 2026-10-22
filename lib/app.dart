/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse
 * - File      : app.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Application composition root. Owns the database-backed
 *               repositories, register controllers, theme mode, and the root
 *               MaterialApp. Controllers are created once for the process and
 *               disposed with the app; no screen owns database lifecycle. Dark
 *               warehouse mode is the default, with a one-tap light-mode
 *               switch in the module rail.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/checkout_repository.dart';
import 'features/register/catalog_controller.dart';
import 'features/register/checkout_controller.dart';
import 'features/shell/pos_shell.dart';

/// Root widget for the offline till.
class PosApp extends StatefulWidget {
  const PosApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  late final CatalogRepository _catalogRepository;
  late final CheckoutRepository _checkoutRepository;
  late final CatalogController _catalogController;
  late final CheckoutController _checkoutController;

  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();

    _catalogRepository = CatalogRepository(widget.database);
    _checkoutRepository = CheckoutRepository(widget.database);
    _catalogController = CatalogController(repository: _catalogRepository);
    _checkoutController = CheckoutController(repository: _checkoutRepository);

    unawaited(_catalogController.initialize());
    unawaited(_checkoutController.initialize());
  }

  @override
  void dispose() {
    _catalogController.dispose();
    _checkoutController.dispose();
    // The app is the owner of the process-wide database. Closing releases the
    // background isolate and WAL handles; the OS reclaims them anyway, but an
    // explicit close keeps desktop hot-restart cycles clean.
    unawaited(widget.database.close());
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iWarehouse POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 160),
      home: PosShell(
        catalogController: _catalogController,
        checkoutController: _checkoutController,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
