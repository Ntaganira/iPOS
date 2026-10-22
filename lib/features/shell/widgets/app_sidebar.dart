/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.shell.widgets
 * - File      : app_sidebar.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Collapsible module rail for Register, Inventory Registry,
 *               Customers, and Settings. The animated rail owns no business
 *               state: it renders an expanded label view or a compact icon-only
 *               strip and delegates resizing to the responsive shell. Labels
 *               use ellipsis and clipped animated width so short desktop
 *               viewports and tablets never throw overflow exceptions.
 * </pre>
 */

import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../module_labels.dart';
import '../pos_module.dart';

/// Left navigation rail with an expanded and collapsed presentation.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.expanded,
    required this.activeModule,
    required this.onModuleSelected,
    required this.onToggleExpanded,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.showCollapseAction = true,
    this.modules = PosModule.values,
  });

  final bool expanded;
  final PosModule activeModule;
  final ValueChanged<PosModule> onModuleSelected;
  final VoidCallback onToggleExpanded;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool showCollapseAction;
  final List<PosModule> modules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return AnimatedContainer(
      duration: AppLayout.layoutAnimation,
      curve: Curves.easeOutCubic,
      width: expanded
          ? AppLayout.sidebarExpandedWidth
          : AppLayout.sidebarCollapsedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppLayout.panelRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The rail width is animated. Switch to the labelled presentation
          // only after enough width exists, otherwise labels overflow during
          // the collapse/expand animation frames.
          final showLabels = expanded && constraints.maxWidth >= 160;

          return Column(
            children: [
              _BrandHeader(expanded: showLabels),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: ListView(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final module in modules)
                      _SidebarDestination(
                        module: module,
                        expanded: showLabels,
                        selected: module == activeModule,
                        onTap: () => onModuleSelected(module),
                      ),
                  ],
                ),
              ),
              _LocalVaultBadge(expanded: showLabels),
              Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: showLabels
                    ? Row(
                        children: [
                          _SidebarIconButton(
                            tooltip: isDarkMode
                                ? l10n.switchToLight
                                : l10n.switchToDark,
                            icon: isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            onPressed: onToggleTheme,
                          ),
                          const Spacer(),
                          if (showCollapseAction)
                            _SidebarIconButton(
                              tooltip: l10n.collapseSidebar,
                              icon: Icons.keyboard_double_arrow_left_rounded,
                              onPressed: onToggleExpanded,
                            ),
                        ],
                      )
                    : Column(
                        children: [
                          _SidebarIconButton(
                            tooltip: isDarkMode
                                ? l10n.switchToLight
                                : l10n.switchToDark,
                            icon: isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            onPressed: onToggleTheme,
                          ),
                          const SizedBox(height: 4),
                          if (showCollapseAction)
                            _SidebarIconButton(
                              tooltip: l10n.expandSidebar,
                              icon: Icons.keyboard_double_arrow_right_rounded,
                              onPressed: onToggleExpanded,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Brand lockup. Text is only mounted in the expanded state, and the animate
/// width clips any intermediate frame during a fast collapse.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 62,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
        child: expanded
            ? Row(
                children: [
                  _BrandMark(scheme: scheme),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'iPOS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          AppLocalizations.of(context).appTagline.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Center(child: _BrandMark(scheme: scheme)),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(Icons.inventory_2_rounded, size: 19, color: scheme.onPrimary),
    );
  }
}

/// One rail destination. The whole 42 px row is the tap target; the icon-only
/// variant gets a tooltip so the compact rail remains discoverable.
class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.module,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final PosModule module;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    final icon = Icon(module.icon, size: 20, color: foreground);

    final content = expanded
        ? Row(
            children: [
              SizedBox(width: 38, child: Center(child: icon)),
              Expanded(
                child: Text(
                  moduleShortLabel(l10n, module),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          )
        : Center(child: icon);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: expanded ? '' : moduleLabel(l10n, module),
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppLayout.controlRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: AppLayout.sidebarItemHeight,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small local-only assurance badge. It deliberately says local vault, not
/// "synced", because the back-office transport is not part of this increment.
class _LocalVaultBadge extends StatelessWidget {
  const _LocalVaultBadge({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final icon = Icon(
      Icons.lock_outline_rounded,
      size: 16,
      color: scheme.primary,
    );

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Tooltip(
          message: l10n.encryptedVaultActive,
          child: SizedBox(height: 32, child: Center(child: icon)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.offlineReady,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    l10n.encryptedLocalVault,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
