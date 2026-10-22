/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.features.shell
 * - File      : pos_module.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Module identity and presentation metadata for the collapsible
 *               left navigation rail. Keeping labels, icons, and descriptions
 *               in one enum extension prevents the rail and module placeholders
 *               from drifting apart as back-office-backed screens come online.
 * </pre>
 */

import 'package:flutter/material.dart';

/// Top-level client modules reachable from the module rail.
enum PosModule { register, inventory, customers, settings }

/// Presentation metadata attached to each module.
extension PosModulePresentation on PosModule {
  String get label => switch (this) {
    PosModule.register => 'Register',
    PosModule.inventory => 'Inventory Registry',
    PosModule.customers => 'Customers',
    PosModule.settings => 'Settings',
  };

  String get shortLabel => switch (this) {
    PosModule.register => 'Register',
    PosModule.inventory => 'Inventory',
    PosModule.customers => 'Customers',
    PosModule.settings => 'Settings',
  };

  IconData get icon => switch (this) {
    PosModule.register => Icons.point_of_sale_rounded,
    PosModule.inventory => Icons.inventory_2_rounded,
    PosModule.customers => Icons.groups_rounded,
    PosModule.settings => Icons.tune_rounded,
  };

  String get description => switch (this) {
    PosModule.register =>
      'Front-counter search, fitment filtering, and offline checkout.',
    PosModule.inventory =>
      'Bin-level stock ledger, receiving, counts, and movement history.',
    PosModule.customers =>
      'Trade accounts, contact details, cached balances, and statements.',
    PosModule.settings =>
      'Terminal identity, tax profile, security, sync, and appearance.',
  };
}
