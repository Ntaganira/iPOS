/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos
 * - File      : app.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Application composition root. Owns the encrypted-database
 *               repositories, authentication session, notification stream,
 *               settings, register controllers, and localization. The root
 *               gates the register behind offline sign-in and forced PIN
 *               rotation, resolves every repository's audit actor from the
 *               active session, and applies persisted theme and language
 *               choices without a restart.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/database_maintenance_service.dart';
import 'data/repositories/audit_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/checkout_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/inventory_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/shift_repository.dart';
import 'data/sync/http_sync_transport.dart';
import 'data/sync/sync_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/change_pin_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/notifications/notification_controller.dart';
import 'features/register/catalog_controller.dart';
import 'features/register/checkout_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/shell/pos_shell.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/rw_localizations.dart';

/// Root widget for the offline till.
class PosApp extends StatefulWidget {
  const PosApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  late final AuthRepository _authRepository;
  late final SettingsRepository _settingsRepository;
  late final CatalogRepository _catalogRepository;
  late final CheckoutRepository _checkoutRepository;
  late final NotificationRepository _notificationRepository;
  late final AuditRepository _auditRepository;
  late final DatabaseMaintenanceService _maintenanceService;
  late final ShiftRepository _shiftRepository;
  late final InventoryRepository _inventoryRepository;
  late final CustomerRepository _customerRepository;

  late final AuthController _authController;
  late final SettingsController _settingsController;
  late final NotificationController _notificationController;
  late final CatalogController _catalogController;
  late final CheckoutController _checkoutController;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // The actor callback is invoked only after sign-in, so the late controller
    // reference is safe while still keeping one provider for every repository.
    _authRepository = AuthRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _settingsRepository = SettingsRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _catalogRepository = CatalogRepository(widget.database);
    _checkoutRepository = CheckoutRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _notificationRepository = NotificationRepository(widget.database);
    _auditRepository = AuditRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _maintenanceService = DatabaseMaintenanceService(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _shiftRepository = ShiftRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _inventoryRepository = InventoryRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );
    _customerRepository = CustomerRepository(
      widget.database,
      actorProvider: () => _authController.auditActor,
    );

    _authController = AuthController(repository: _authRepository);
    _settingsController = SettingsController(repository: _settingsRepository);
    _notificationController = NotificationController(
      repository: _notificationRepository,
    );
    _catalogController = CatalogController(repository: _catalogRepository);
    _checkoutController = CheckoutController(repository: _checkoutRepository);
    _settingsController.addListener(_applyRuntimeSettings);

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _settingsController.initialize();
    _applyRuntimeSettings();
    await _authController.initialize();
    await _notificationController.initialize();
    await _catalogController.initialize();
    await _checkoutController.initialize();
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  void _applyRuntimeSettings() {
    _checkoutController.setTaxRateBps(_settingsController.settings.taxRateBps);
  }

  @override
  void dispose() {
    _settingsController.removeListener(_applyRuntimeSettings);
    _catalogController.dispose();
    _checkoutController.dispose();
    _notificationController.dispose();
    _settingsController.dispose();
    _authController.dispose();
    // The app is the owner of the process-wide database. Closing releases the
    // background isolate and WAL handles; the OS reclaims them anyway, but an
    // explicit close keeps desktop hot-restart cycles clean.
    unawaited(widget.database.close());
    super.dispose();
  }

  Future<void> _toggleTheme() async {
    await _settingsController.save(
      _settingsController.settings.copyWith(
        darkMode: !_settingsController.settings.darkMode,
      ),
    );
  }

  Future<void> _setLanguage(String languageCode) async {
    await _settingsController.setLanguage(languageCode);
  }

  Future<SyncRunResult> _syncNow() {
    final settings = _settingsController.settings;
    if (!settings.syncConfigured) {
      throw StateError('Sync endpoint and token are not configured.');
    }
    return SyncService(
      database: widget.database,
      transport: HttpSyncTransport(
        endpoint: settings.syncEndpoint,
        token: settings.syncToken,
      ),
      deviceId: settings.deviceId,
      notifications: _notificationRepository,
    ).run();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _authController,
        _settingsController,
        _notificationController,
      ]),
      builder: (context, _) {
        final settings = _settingsController.settings;
        final themeMode = settings.darkMode ? ThemeMode.dark : ThemeMode.light;

        return MaterialApp(
          title: 'iPOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: Locale(settings.languageCode),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: iposLocalizationsDelegates,
          themeAnimationDuration: const Duration(milliseconds: 160),
          home: _home(),
        );
      },
    );
  }

  Widget _home() {
    if (!_initialized || _authController.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_authController.isAuthenticated) {
      return LoginScreen(
        controller: _authController,
        languageCode: _settingsController.languageCode,
        onLanguageChanged: _setLanguage,
        firstRun: _authController.firstRun,
      );
    }
    if (_authController.currentUser?.mustChangePin ?? false) {
      return ChangePinScreen(controller: _authController, forced: true);
    }
    return PosShell(
      catalogController: _catalogController,
      checkoutController: _checkoutController,
      isDarkMode: _settingsController.settings.darkMode,
      onToggleTheme: _toggleTheme,
      authController: _authController,
      notificationController: _notificationController,
      settingsController: _settingsController,
      auditRepository: _auditRepository,
      maintenanceService: _maintenanceService,
      shiftRepository: _shiftRepository,
      inventoryRepository: _inventoryRepository,
      customerRepository: _customerRepository,
      onSettingsSaved: (settings) =>
          _checkoutController.setTaxRateBps(settings.taxRateBps),
      onSyncNow: _syncNow,
      user: _authController.currentUser,
      storeName: _settingsController.settings.storeName,
    );
  }
}
