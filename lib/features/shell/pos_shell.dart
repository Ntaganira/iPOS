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

import '../../core/theme/app_layout.dart';
import '../register/catalog_controller.dart';
import '../register/checkout_controller.dart';
import '../register/register_workspace.dart';
import '../register/widgets/checkout_panel.dart';
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
  });

  final CatalogController catalogController;
  final CheckoutController checkoutController;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final inlineCheckout =
            width >= AppLayout.inlineCheckoutBreakpoint;
        final canExpandSidebar =
            width >= AppLayout.expandedSidebarBreakpoint;
        final effectiveSidebarExpanded =
            _sidebarExpanded && canExpandSidebar;
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
                      ),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: AppLayout.shellPadding,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSidebar(
                      expanded: effectiveSidebarExpanded,
                      activeModule: _activeModule,
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
                          onOpenCheckout: isRegister && !inlineCheckout
                              ? () => _scaffoldKey.currentState
                                    ?.openEndDrawer()
                              : null,
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
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
