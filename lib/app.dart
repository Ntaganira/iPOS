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

import 'core/security/database_key_rotation_service.dart';
import 'core/security/permissions.dart';
import 'core/security/secure_key_manager.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/app_database_factory.dart';
import 'data/database/database_maintenance_service.dart';
import 'data/models/customer_option.dart';
import 'data/repositories/audit_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/checkout_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/draft_repository.dart';
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

class _PosAppState extends State<PosApp> with WidgetsBindingObserver {
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
  late final DraftRepository _draftRepository;

  late final AuthController _authController;
  late final SettingsController _settingsController;
  late final NotificationController _notificationController;
  late final CatalogController _catalogController;
  late final CheckoutController _checkoutController;

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Timer? _draftTimer;
  String? _draftUserId;
  bool _restoringDraft = false;
  bool _initialized = false;
  bool _databaseClosed = false;
  bool _rotatingKey = false;
  bool _vaultRestartRequired = false;
  String? _rotationBackupPath;
  String? _rotationError;
  final DatabaseKeyRotationService _keyRotationService =
      DatabaseKeyRotationService();

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
    _draftRepository = DraftRepository(widget.database);

    _authController = AuthController(repository: _authRepository);
    _settingsController = SettingsController(repository: _settingsRepository);
    _notificationController = NotificationController(
      repository: _notificationRepository,
    );
    _catalogController = CatalogController(repository: _catalogRepository);
    _checkoutController = CheckoutController(repository: _checkoutRepository);
    _settingsController.addListener(_applyRuntimeSettings);
    _checkoutController.addListener(_scheduleDraftSave);
    _authController.addListener(_handleAuthChanged);
    WidgetsBinding.instance.addObserver(this);

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

  void _handleAuthChanged() {
    final userId = _authController.currentUser?.id;
    if (userId == null) {
      final previous = _draftUserId;
      if (previous != null) {
        _draftTimer?.cancel();
        unawaited(_flushDraft(previous));
        _draftUserId = null;
        _checkoutController.resetSession();
      }
      return;
    }
    if (userId == _draftUserId) {
      return;
    }
    _draftUserId = userId;
    unawaited(_restoreDraft(userId));
  }

  void _scheduleDraftSave() {
    final userId = _draftUserId;
    if (userId == null ||
        _restoringDraft ||
        _authController.currentUser == null) {
      return;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_flushDraft(userId));
    });
  }

  Future<void> _flushDraft(String userId) async {
    final draft = _checkoutController.draftSnapshot();
    try {
      if (draft == null) {
        await _draftRepository.clear(userId);
      } else {
        await _draftRepository.save(userId, draft);
      }
    } catch (error, stackTrace) {
      debugPrint('Draft save failed: $error\n$stackTrace');
    }
  }

  Future<void> _restoreDraft(String userId) async {
    _restoringDraft = true;
    try {
      final draft = await _draftRepository.load(userId);
      if (!mounted ||
          draft == null ||
          _draftUserId != userId ||
          _checkoutController.lines.isNotEmpty) {
        return;
      }
      final customerId = draft.customerId;
      CustomerOption? customer;
      if (customerId != null) {
        for (final option in _checkoutController.customers) {
          if (option.id == customerId) {
            customer = option;
            break;
          }
        }
      }
      _checkoutController.restoreDraft(draft, customer: customer);
      final messenger = _messengerKey.currentState;
      final messengerContext = messenger?.context;
      if (messenger != null &&
          messengerContext != null &&
          messengerContext.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(messengerContext).draftRestored),
          ),
        );
      }
    } finally {
      _restoringDraft = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      final userId = _draftUserId;
      if (userId != null) {
        _draftTimer?.cancel();
        unawaited(_flushDraft(userId));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _checkoutController.removeListener(_scheduleDraftSave);
    _authController.removeListener(_handleAuthChanged);
    _settingsController.removeListener(_applyRuntimeSettings);
    _catalogController.dispose();
    _checkoutController.dispose();
    _notificationController.dispose();
    _settingsController.dispose();
    _authController.dispose();
    // The app is the owner of the process-wide database. Closing releases the
    // background isolate and WAL handles; the OS reclaims them anyway, but an
    // explicit close keeps desktop hot-restart cycles clean. A rotation has
    // already closed it and closed handles must not be closed twice.
    if (!_databaseClosed) {
      unawaited(widget.database.close());
    }
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

  Future<void> _rotateDatabaseKey() async {
    final user = _authController.currentUser;
    if (user == null || !user.can(AppPermission.rotateKeys)) {
      throw StateError(
        'Rotating the database key requires the administrator key-rotation '
        'permission.',
      );
    }
    if (_rotatingKey || _databaseClosed || _vaultRestartRequired) {
      throw StateError('A database key rotation is already in progress.');
    }
    _rotatingKey = true;
    KeyRotationResult? result;
    try {
      final keyManager = SecureKeyManager.instance;
      final oldKey = await keyManager.databaseKeyHex();
      final newKey = keyManager.generateCandidateKey();
      final databaseFile = await AppDatabaseFactory.resolveDatabaseFile();
      if (!databaseFile.existsSync()) {
        throw StateError('The encrypted database file was not found.');
      }
      await _auditRepository.append(
        eventType: 'security.key_rotation_requested',
        action: 'keys.rotate',
        actor: _authController.auditActor,
        entityType: 'database',
        entityId: 'primary',
        message: '${user.displayName} requested SQLCipher key rotation.',
        payload: <String, Object?>{
          'device_id': _settingsController.settings.deviceId,
        },
      );

      _draftTimer?.cancel();
      final draftUserId = _draftUserId;
      if (draftUserId != null) {
        await _flushDraft(draftUserId);
      }
      try {
        await widget.database.close();
      } finally {
        _databaseClosed = true;
      }

      try {
        result = await _keyRotationService.rotate(
          databaseFile: databaseFile,
          oldKeyHex: oldKey,
          newKeyHex: newKey,
        );
        await keyManager.replaceDatabaseKey(newKey);
      } catch (_) {
        // If the secure-store write failed after rekeying, restore the
        // pre-rotation file so the still-persisted old key can open it.
        if (result != null) {
          try {
            await result.backupFile.copy(databaseFile.path);
          } catch (_) {
            // Keep the original failure; the restart screen names the
            // recovery backup for manual restoration.
          }
        }
        rethrow;
      }

      if (mounted) {
        setState(() {
          _rotationBackupPath = result?.backupFile.path;
          _vaultRestartRequired = true;
          _rotationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (result != null) {
            _rotationBackupPath = result.backupFile.path;
          }
          _rotationError = error.toString();
          _vaultRestartRequired = _databaseClosed;
        });
      }
      rethrow;
    } finally {
      _rotatingKey = false;
    }
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
          scaffoldMessengerKey: _messengerKey,
          themeAnimationDuration: const Duration(milliseconds: 160),
          home: _home(),
        );
      },
    );
  }

  Widget _home() {
    if (_vaultRestartRequired) {
      return _KeyRotationRestartScreen(
        backupPath: _rotationBackupPath,
        error: _rotationError,
      );
    }
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
      onRotateKey: _rotateDatabaseKey,
      user: _authController.currentUser,
      storeName: _settingsController.settings.storeName,
    );
  }
}

class _KeyRotationRestartScreen extends StatelessWidget {
  const _KeyRotationRestartScreen({this.backupPath, this.error});

  final String? backupPath;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = error != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed ? Icons.gpp_bad_rounded : Icons.lock_reset_rounded,
                    size: 52,
                    color: failed ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    failed ? l10n.keyRotationWarning : l10n.keyRotated,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.restartRequired,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (backupPath != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.encryptedBackup,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            backupPath!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (failed) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
