/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.settings
 * - File      : maintenance_view.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Operator-facing maintenance panel. Executes shift close plus
 *               post-shift VACUUM, encrypted backup, gated plaintext export, and
 *               SQLCipher integrity verification, and the explicit admin
 *               key-rotation ceremony. Every mutating operation is audited by
 *               the service with the signed-in actor, and dangerous actions
 *               require an explicit confirmation before running.
 * </pre>
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/database/database_maintenance_service.dart';
import '../../data/repositories/shift_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Maintenance and shift-closing controls.
class MaintenanceView extends StatefulWidget {
  const MaintenanceView({
    super.key,
    required this.maintenance,
    required this.shifts,
    required this.canBackup,
    required this.canCloseShift,
    this.canRotate = false,
    this.onRotate,
  });

  final DatabaseMaintenanceService maintenance;
  final ShiftRepository shifts;
  final bool canBackup;
  final bool canCloseShift;
  final bool canRotate;
  final Future<void> Function()? onRotate;

  @override
  State<MaintenanceView> createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends State<MaintenanceView> {
  ShiftSummary? _lastShift;
  bool _busy = false;
  String? _result;
  bool? _resultOk;

  @override
  void initState() {
    super.initState();
    _loadShift();
  }

  Future<void> _loadShift() async {
    final shift = await widget.shifts.latest();
    if (mounted) {
      setState(() => _lastShift = shift);
    }
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
      _resultOk = null;
    });
    try {
      final message = await action();
      if (mounted) {
        setState(() {
          _result = message;
          _resultOk = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _result = error.toString();
          _resultOk = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _closeShift() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(l10n.shiftCloseConfirm);
    if (!confirmed) {
      return;
    }
    await _run(() async {
      final summary = await widget.shifts.closeShift();
      await widget.maintenance.runPostShiftMaintenance();
      await _loadShift();
      return '${l10n.shiftClosed}: ${summary.invoiceCount} · '
          '${(summary.grossCents / 100).toStringAsFixed(2)}';
    });
  }

  Future<void> _integrity() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final report = await widget.maintenance.verifyIntegrity();
      return report.isValid ? l10n.integrityValid : l10n.integrityInvalid;
    });
  }

  Future<void> _backup() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final file = await widget.maintenance.createEncryptedBackup();
      return '${l10n.backupCreated}\n${file.path}';
    });
  }

  Future<void> _vacuum() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      await widget.maintenance.checkpoint();
      await widget.maintenance.vacuum();
      return l10n.vacuumDone;
    });
  }

  Future<void> _rotateKey() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      '${l10n.keyRotationWarning}\n\n${l10n.rotateKey}',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _run(() async {
      final rotate = widget.onRotate;
      if (rotate == null) {
        throw StateError('Key rotation is not available.');
      }
      await rotate();
      return '${l10n.keyRotated}\n${l10n.restartRequired}';
    });
  }

  Future<void> _exportPlaintext() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      '${l10n.plaintextWarning}\n\n${l10n.plaintextExportConfirm}',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _run(() async {
      final databaseFile = await widget.maintenance.resolveDatabaseFile();
      final destination = Directory(
        p.join(databaseFile.parent.path, 'exports'),
      );
      final file = await widget.maintenance.exportPlaintext(
        destination: destination,
        acknowledgeRisk: true,
      );
      return '${l10n.plaintextWarning}\n${file.path}';
    });
  }

  Future<bool> _confirm(String message, {bool destructive = false}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          destructive ? Icons.warning_amber_rounded : Icons.help_outline,
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(destructive ? l10n.confirm : l10n.close),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shift = _lastShift;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: ListView(
        children: [
          Text(
            l10n.maintenanceTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            l10n.maintenanceSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (_resultOk == true ? const Color(0xFF2E9E6B) : scheme.error)
                        .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      (_resultOk == true
                              ? const Color(0xFF2E9E6B)
                              : scheme.error)
                          .withValues(alpha: 0.35),
                ),
              ),
              child: SelectableText(_result!, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 12),
          ],
          _MaintenanceCard(
            icon: Icons.point_of_sale_rounded,
            title: l10n.shiftSummary,
            subtitle: shift == null
                ? l10n.noSalesInShift
                : '${l10n.invoicesCount}: ${shift.invoiceCount} · '
                      '${l10n.gross}: ${(shift.grossCents / 100).toStringAsFixed(2)} · '
                      '${l10n.tax}: ${(shift.taxCents / 100).toStringAsFixed(2)}',
            action: FilledButton.icon(
              onPressed: !widget.canCloseShift || _busy ? null : _closeShift,
              icon: const Icon(Icons.lock_clock_rounded, size: 18),
              label: Text(l10n.closeShift),
            ),
          ),
          const SizedBox(height: 10),
          _MaintenanceCard(
            icon: Icons.fact_check_outlined,
            title: l10n.integrityCheck,
            subtitle: l10n.databaseMaintenance,
            action: OutlinedButton(
              onPressed: _busy ? null : _integrity,
              child: Text(l10n.confirm),
            ),
          ),
          const SizedBox(height: 10),
          _MaintenanceCard(
            icon: Icons.inventory_2_outlined,
            title: l10n.encryptedBackup,
            subtitle: l10n.backupCreated,
            action: OutlinedButton(
              onPressed: !widget.canBackup || _busy ? null : _backup,
              child: Text(l10n.confirm),
            ),
          ),
          const SizedBox(height: 10),
          _MaintenanceCard(
            icon: Icons.compress_rounded,
            title: 'VACUUM',
            subtitle: l10n.vacuumDone,
            action: OutlinedButton(
              onPressed: !widget.canBackup || _busy ? null : _vacuum,
              child: Text(l10n.confirm),
            ),
          ),
          const SizedBox(height: 10),
          _MaintenanceCard(
            icon: Icons.key_rounded,
            title: l10n.rotateKey,
            subtitle: l10n.keyRotationWarning,
            action: OutlinedButton(
              key: const Key('rotate-key-action'),
              onPressed: !widget.canRotate || widget.onRotate == null || _busy
                  ? null
                  : _rotateKey,
              child: Text(l10n.confirm),
            ),
            danger: true,
          ),
          const SizedBox(height: 10),
          _MaintenanceCard(
            icon: Icons.no_encryption_gmailerrorred_rounded,
            title: l10n.exportPlaintext,
            subtitle: l10n.plaintextWarning,
            action: OutlinedButton(
              onPressed: !widget.canBackup || _busy ? null : _exportPlaintext,
              child: Text(l10n.confirm),
            ),
            danger: true,
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = danger ? scheme.error : scheme.primary;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: danger
              ? scheme.error.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}
