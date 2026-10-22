/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.features.register.widgets
 * - File      : ymm_filter_bar.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Cascading Year-Make-Model filter strip for the center catalog.
 *               Each dropdown is a controlled, dense widget that reports into
 *               CatalogController; dependent selectors disable until their
 *               parent is chosen. Wide counters fold the strip with Wrap;
 *               narrow phones switch to a single horizontally scrollable row
 *               so the filter area cannot consume the catalog's height.
 * </pre>
 */

import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';

/// Dense YMM selector strip.
class YmmFilterBar extends StatelessWidget {
  const YmmFilterBar({
    super.key,
    required this.makes,
    required this.models,
    required this.years,
    required this.selectedMake,
    required this.selectedModel,
    required this.selectedYear,
    required this.onMakeChanged,
    required this.onModelChanged,
    required this.onYearChanged,
    required this.onReset,
    required this.hasActiveFilter,
  });

  final List<String> makes;
  final List<String> models;
  final List<int> years;
  final String? selectedMake;
  final String? selectedModel;
  final int? selectedYear;
  final ValueChanged<String?> onMakeChanged;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onReset;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _CompactDropdown<String>(
        label: 'Make',
        hint: 'All makes',
        width: 148,
        value: selectedMake,
        items: makes,
        itemLabel: (value) => value,
        onChanged: onMakeChanged,
      ),
      _CompactDropdown<String>(
        label: 'Model',
        hint: 'All models',
        width: 172,
        value: selectedModel,
        items: models,
        itemLabel: (value) => value,
        enabled: selectedMake != null,
        onChanged: onModelChanged,
      ),
      _CompactDropdown<int>(
        label: 'Year',
        hint: 'All years',
        width: 104,
        value: selectedYear,
        items: years,
        itemLabel: (value) => '$value',
        enabled: selectedModel != null,
        onChanged: onYearChanged,
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: IconButton(
          tooltip: 'Reset search and YMM filters',
          onPressed: hasActiveFilter ? onReset : null,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 19),
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.controlRadius),
            ),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones and split-screen tablets cannot afford the vertical space of
        // a folded filter strip. Keep one dense row and scroll horizontally;
        // wider counters retain the wrapping layout.
        if (constraints.maxWidth < 500) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  children[index],
                ],
              ],
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: children,
        );
      },
    );
  }
}

/// Compact labeled dropdown. Uses a controlled [DropdownButton] rather than a
/// form field so external controller resets always repaint the selected value.
class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.label,
    required this.hint,
    required this.width,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final double width;
  final T? value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldColor = enabled
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerHigh.withValues(alpha: 0.45);
    final foreground = enabled
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: width,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: scheme.surfaceContainerHigh,
              hint: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground.withValues(alpha: 0.75),
                ),
              ),
              icon: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: foreground,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              onChanged: enabled ? onChanged : null,
              items: [
                for (final item in items)
                  DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
