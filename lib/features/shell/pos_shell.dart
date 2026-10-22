/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.shell
 * - File      : pos_shell.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Responsive three-column POS frame. Owns module selection and
 *               the expanded/collapsed rail intent, then applies hard layout
 *               breakpoints: persistent rail + catalog + checkout on desktop,
 *               compact rail + catalog + checkout at tighter widths, and a
 *               checkout end drawer below 1024 px. The shelf never allows a
 *               fixed-width row child to force a RenderFlex overflow.
 * </pre>
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/email/invoice_email_service.dart';
import '../../core/printing/a4_receipt_pdf.dart';
import '../../core/printing/esc_pos_printer.dart';
import '../../core/printing/receipt_paper.dart';
import '../../core/security/permissions.dart';
import '../../core/theme/app_layout.dart';
import '../../data/database/database_maintenance_service.dart';
import '../../data/models/app_user.dart';
import '../../data/models/terminal_settings.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/change_pin_screen.dart';
import '../customers/customers_screen.dart';
import '../inventory/inventory_screen.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_inbox.dart';
import '../register/catalog_controller.dart';
import '../register/checkout_controller.dart';
import '../register/register_workspace.dart';
import '../register/widgets/checkout_panel.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import 'pos_module.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/module_placeholder.dart';

/// Application shell for the offline counter client.
class PosShell extends StatefulWidget {
  const PosShell({
    super.key,
    required this.catalogController,
    required this.checkoutController,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.authController,
    this.notificationController,
    this.settingsController,
    this.auditRepository,
    this.maintenanceService,
    this.shiftRepository,
    this.inventoryRepository,
    this.customerRepository,
    this.onSettingsSaved,
    this.onSyncNow,
    this.user,
    this.storeName = 'iPOS Parts Counter',
  });

  final CatalogController catalogController;
  final CheckoutController checkoutController;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AuthController? authController;
  final NotificationController? notificationController;
  final SettingsController? settingsController;
  final AuditRepository? auditRepository;
  final DatabaseMaintenanceService? maintenanceService;
  final ShiftRepository? shiftRepository;
  final InventoryRepository? inventoryRepository;
  final CustomerRepository? customerRepository;
  final ValueChanged<TerminalSettings>? onSettingsSaved;
  final Future<SyncRunResult> Function()? onSyncNow;
  final AppUser? user;
  final String storeName;

  @override
  State<PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<PosShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  PosModule _activeModule = PosModule.register;
  bool _sidebarExpanded = true;

  void _selectModule(PosModule module) {
    if (_activeModule == module) {
      return;
    }
    setState(() => _activeModule = module);
  }

  Future<void> _printDocument(
    ReceiptDocument document,
    ReceiptPaperSize paper,
  ) async {
    if (paper == ReceiptPaperSize.a4) {
      await const A4ReceiptPrinter().print(document);
      return;
    }
    final settings = widget.settingsController?.settings;
    if (settings == null) {
      throw StateError('Printer settings are not available.');
    }
    final printer = EscPosPrinter(
      host: settings.printerHost,
      port: settings.printerPort,
    );
    if (!printer.isConfigured) {
      throw StateError('No receipt printer is configured.');
    }
    await printer.print(document, paper: paper);
  }

  Future<void> Function(ReceiptDocument, ReceiptPaperSize)? get _printAction =>
      widget.settingsController == null ? null : _printDocument;

  ReceiptPaperSize get _defaultPaper =>
      widget.settingsController?.settings.receiptPaper ?? ReceiptPaperSize.mm80;

  Future<void> _emailDocument(
    ReceiptDocument document,
    EmailRequest request,
  ) async {
    final settings = widget.settingsController?.settings;
    if (settings == null) {
      throw StateError('Email settings are not available.');
    }
    await InvoiceEmailService(
      settings: settings,
    ).send(document: document, request: request);
  }

  Future<void> Function(ReceiptDocument, EmailRequest)? get _emailAction =>
      widget.settingsController == null ? null : _emailDocument;

  List<PosModule> get _visibleModules {
    final user = widget.user;
    if (user == null) {
      return PosModule.values;
    }
    return PosModule.values
        .where((module) {
          return switch (module) {
            PosModule.register => user.can(AppPermission.sell),
            PosModule.inventory => user.can(AppPermission.manageInventory),
            PosModule.customers => user.can(AppPermission.manageCustomers),
            PosModule.settings =>
              user.can(AppPermission.manageSettings) ||
                  user.can(AppPermission.manageUsers) ||
                  user.can(AppPermission.manageBackup) ||
                  user.can(AppPermission.viewAudit) ||
                  user.can(AppPermission.rotateKeys),
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final inlineCheckout = width >= AppLayout.inlineCheckoutBreakpoint;
        final canExpandSidebar = width >= AppLayout.expandedSidebarBreakpoint;
        final effectiveSidebarExpanded = _sidebarExpanded && canExpandSidebar;
        final isRegister = _activeModule == PosModule.register;
        final checkoutWidth = width >= AppLayout.wideCheckoutBreakpoint
            ? AppLayout.checkoutWidthWide
            : AppLayout.checkoutWidthCompact;
        final checkoutDrawerWidth = math.min(
          AppLayout.checkoutDrawerMaxWidth,
          width * 0.92,
        );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: scheme.surface,
          // The persistent rail handles expansion explicitly. Disabling edge
          // drag prevents an accidental drawer over the catalog on tablets.
          drawerEnableOpenDragGesture: false,
          drawerScrimColor: scheme.scrim.withValues(alpha: 0.52),
          drawer: canExpandSidebar
              ? null
              : Drawer(
                  width: AppLayout.sidebarDrawerWidth,
                  backgroundColor: scheme.surface,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AppSidebar(
                        expanded: true,
                        activeModule: _activeModule,
                        modules: _visibleModules,
                        onModuleSelected: (module) {
                          _selectModule(module);
                          Navigator.of(context).pop();
                        },
                        onToggleExpanded: () => Navigator.of(context).pop(),
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                        showCollapseAction: true,
                      ),
                    ),
                  ),
                ),
          endDrawer: isRegister && !inlineCheckout
              ? Drawer(
                  width: checkoutDrawerWidth,
                  backgroundColor: scheme.surface,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CheckoutPanel(
                        controller: widget.checkoutController,
                        onClose: () => Navigator.of(context).pop(),
                        onPrint: _printAction,
                        onEmail: _emailAction,
                        storeName: widget.storeName,
                        defaultPaper: _defaultPaper,
                      ),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: AppLayout.shellPadding,
              child: Column(
                children: [
                  _SessionBar(
                    storeName: widget.storeName,
                    user: widget.user,
                    authController: widget.authController,
                    notificationController: widget.notificationController,
                  ),
                  const SizedBox(height: AppLayout.shellGap),
                  Expanded(
                    child: FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSidebar(
                            expanded: effectiveSidebarExpanded,
                            activeModule: _activeModule,
                            modules: _visibleModules,
                            onModuleSelected: _selectModule,
                            onToggleExpanded: () {
                              if (canExpandSidebar) {
                                setState(
                                  () => _sidebarExpanded = !_sidebarExpanded,
                                );
                              } else {
                                _scaffoldKey.currentState?.openDrawer();
                              }
                            },
                            isDarkMode: widget.isDarkMode,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                          const SizedBox(width: AppLayout.shellGap),
                          Expanded(
                            child: switch (_activeModule) {
                              PosModule.register => RegisterWorkspace(
                                catalogController: widget.catalogController,
                                checkoutController: widget.checkoutController,
                                settings: widget.settingsController?.settings,
                                onOpenCheckout: isRegister && !inlineCheckout
                                    ? () => _scaffoldKey.currentState
                                          ?.openEndDrawer()
                                    : null,
                              ),
                              PosModule.inventory
                                  when widget.inventoryRepository != null =>
                                InventoryScreen(
                                  repository: widget.inventoryRepository!,
                                ),
                              PosModule.customers
                                  when widget.customerRepository != null =>
                                CustomersScreen(
                                  repository: widget.customerRepository!,
                                ),
                              PosModule.settings
                                  when widget.settingsController != null &&
                                      widget.authController != null &&
                                      widget.auditRepository != null &&
                                      widget.maintenanceService != null &&
                                      widget.shiftRepository != null =>
                                SettingsScreen(
                                  controller: widget.settingsController!,
                                  authController: widget.authController!,
                                  auditRepository: widget.auditRepository!,
                                  maintenance: widget.maintenanceService!,
                                  shifts: widget.shiftRepository!,
                                  onSettingsSaved:
                                      widget.onSettingsSaved ?? (_) {},
                                  onSyncNow: widget.onSyncNow,
                                ),
                              _ => ModulePlaceholder(module: _activeModule),
                            },
                          ),
                          if (isRegister && inlineCheckout) ...[
                            const SizedBox(width: AppLayout.shellGap),
                            SizedBox(
                              width: checkoutWidth,
                              child: CheckoutPanel(
                                controller: widget.checkoutController,
                                onPrint: _printAction,
                                onEmail: _emailAction,
                                storeName: widget.storeName,
                                defaultPaper: _defaultPaper,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.storeName,
    required this.user,
    required this.authController,
    required this.notificationController,
  });

  final String storeName;
  final AppUser? user;
  final AuthController? authController;
  final NotificationController? notificationController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentUser = user;
    final notifications = notificationController;

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (notifications != null)
            AnimatedBuilder(
              animation: notifications,
              builder: (context, _) {
                final unread = notifications.unreadCount;
                return IconButton(
                  tooltip: l10n.notifications,
                  onPressed: () =>
                      showNotificationInbox(context, notifications),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                );
              },
            ),
          if (currentUser != null)
            PopupMenuButton<String>(
              tooltip: l10n.loggedInAs(currentUser.displayName),
              onSelected: (value) async {
                if (value == 'pin') {
                  final controller = authController;
                  if (controller == null) {
                    return;
                  }
                  await showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                      child: SizedBox(
                        width: 400,
                        child: ChangePinScreen(controller: controller),
                      ),
                    ),
                  );
                } else if (value == 'logout') {
                  await authController?.logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    '${currentUser.displayName} · ${currentUser.roleName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'pin',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.password_rounded, size: 18),
                    title: Text(l10n.changePin),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, size: 18),
                    title: Text(l10n.logout),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        _initials(currentUser.displayName),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentUser.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}
