/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.shell
 * - File      : module_labels.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Localized presentation metadata for the module rail. Keeping
 *               the translation lookup here lets the enum stay a pure identity
 *               and keeps every navigation surface in sync across locales.
 * </pre>
 */

import '../../l10n/generated/app_localizations.dart';
import 'pos_module.dart';

/// Localized full module name.
String moduleLabel(AppLocalizations l10n, PosModule module) => switch (module) {
  PosModule.register => l10n.navRegister,
  PosModule.inventory => l10n.inventoryTitle,
  PosModule.customers => l10n.customersTitle,
  PosModule.settings => l10n.settingsTitle,
};

/// Localized compact label for the expanded rail.
String moduleShortLabel(AppLocalizations l10n, PosModule module) =>
    switch (module) {
      PosModule.register => l10n.navRegister,
      PosModule.inventory => l10n.navInventory,
      PosModule.customers => l10n.navCustomers,
      PosModule.settings => l10n.navSettings,
    };

/// Localized module summary for scaffolds and empty states.
String moduleDescription(AppLocalizations l10n, PosModule module) =>
    switch (module) {
      PosModule.register => l10n.frontCounterSubtitle,
      PosModule.inventory => l10n.inventorySubtitle,
      PosModule.customers => l10n.customersSubtitle,
      PosModule.settings => l10n.settingsSubtitle,
    };
