/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.l10n
 * - File      : display_labels.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Localized presentation for stable role IDs and permission keys.
 *               Persistence and authorization always use the stable keys; only
 *               these helpers translate them for display.
 * </pre>
 */

import '../core/security/permissions.dart';
import 'generated/app_localizations.dart';

/// Localizes a seeded role identifier.
String roleLabel(AppLocalizations l10n, String roleId) {
  return switch (roleId) {
    SystemRoles.adminId => l10n.roleAdmin,
    SystemRoles.managerId => l10n.roleManager,
    _ => l10n.roleCashier,
  };
}

/// Localizes one permission capability.
String permissionLabel(AppLocalizations l10n, AppPermission permission) {
  return switch (permission) {
    AppPermission.sell => l10n.permSell,
    AppPermission.refund => l10n.permRefund,
    AppPermission.manageInventory => l10n.permInventory,
    AppPermission.manageCustomers => l10n.permCustomers,
    AppPermission.manageSettings => l10n.permSettings,
    AppPermission.manageUsers => l10n.permUsers,
    AppPermission.viewReports => l10n.permReports,
    AppPermission.viewAudit => l10n.permAudit,
    AppPermission.manageBackup => l10n.permBackup,
    AppPermission.rotateKeys => l10n.permRotate,
  };
}
