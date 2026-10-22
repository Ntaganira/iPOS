/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.security
 * - File      : permissions.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Stable permission keys and default offline roles. Keys are
 *               persisted in role JSON and must never be translated or reused
 *               for a different capability. Authorization checks use these
 *               constants rather than UI labels.
 * </pre>
 */

/// Capabilities enforced by the local RBAC layer.
enum AppPermission {
  sell('sell'),
  refund('refund'),
  manageInventory('inventory.manage'),
  manageCustomers('customers.manage'),
  manageSettings('settings.manage'),
  manageUsers('users.manage'),
  viewReports('reports.view'),
  viewAudit('audit.view'),
  manageBackup('backup.manage'),
  rotateKeys('keys.rotate');

  const AppPermission(this.key);

  final String key;

  static AppPermission? fromKey(String key) {
    for (final permission in values) {
      if (permission.key == key) {
        return permission;
      }
    }
    return null;
  }
}

/// Built-in role identifiers seeded on first launch.
abstract final class SystemRoles {
  static const String adminId = 'role-admin';
  static const String managerId = 'role-manager';
  static const String cashierId = 'role-cashier';

  static const List<AppPermission> adminPermissions = AppPermission.values;

  static const List<AppPermission> managerPermissions = <AppPermission>[
    AppPermission.sell,
    AppPermission.refund,
    AppPermission.manageInventory,
    AppPermission.manageCustomers,
    AppPermission.viewReports,
    AppPermission.viewAudit,
    AppPermission.manageBackup,
  ];

  static const List<AppPermission> cashierPermissions = <AppPermission>[
    AppPermission.sell,
  ];
}
