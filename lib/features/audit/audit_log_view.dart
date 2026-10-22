/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.audit
 * - File      : audit_log_view.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Read-only audit trail browser. Each row shows when an action
 *               happened, who performed it, the stable action/entity keys, and
 *               expandable before/after JSON so managers can reconstruct a
 *               change. The verify action recomputes the full SHA-256 chain and
 *               reports the first broken event instead of silently trusting the
 *               table.
 * </pre>
 */

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/repositories/audit_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Searchable audit list with chain verification.
class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key, required this.repository});

  final AuditRepository repository;

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  final TextEditingController _search = TextEditingController();
  List<AuditEntry> _entries = const <AuditEntry>[];
  bool _loading = true;
  AuditChainVerification? _verification;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _entries = await widget.repository.list(term: _search.text, limit: 300);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verify() async {
    final result = await widget.repository.verifyChain();
    if (mounted) {
      setState(() => _verification = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.auditTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.auditSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _verify,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(l10n.verifyChain),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.refresh,
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_verification != null) ...[
            const SizedBox(height: 10),
            _VerificationBanner(result: _verification!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: l10n.searchAudit,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: _load, child: Text(l10n.search)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: SelectableText(
                      _error!,
                      style: TextStyle(color: scheme.error),
                    ),
                  )
                : _entries.isEmpty
                ? Center(child: Text(l10n.noAudit))
                : ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) =>
                        _AuditTile(entry: _entries[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.result});

  final AuditChainVerification result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = result.isValid
        ? const Color(0xFF2E9E6B)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            result.isValid ? Icons.verified_rounded : Icons.gpp_bad_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.isValid
                  ? l10n.chainValid(result.checkedEvents)
                  : l10n.chainInvalid(result.firstBrokenEventId ?? '?'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = entry.actorUserId == 'system'
        ? l10n.systemActor
        : entry.actorName;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _actionIcon(entry.action),
            size: 17,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          entry.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 3,
            children: [
              Text(
                '${l10n.actorLabel}: $actor',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${l10n.actionLabel}: ${entry.action}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (entry.entityType != null)
                Text(
                  '${l10n.entityLabel}: ${entry.entityType}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Text(
                _timestamp(entry.occurredAt.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        children: [
          _JsonBlock(label: l10n.beforeLabel, value: entry.before),
          const SizedBox(height: 8),
          _JsonBlock(label: l10n.afterLabel, value: entry.after),
          if (entry.payload != null && entry.payload!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _JsonBlock(label: 'Payload', value: entry.payload),
          ],
        ],
      ),
    );
  }

  IconData _actionIcon(String action) {
    return switch (action) {
      'create' => Icons.add_circle_outline_rounded,
      'update' => Icons.edit_outlined,
      'delete' => Icons.delete_outline_rounded,
      'login' => Icons.login_rounded,
      'logout' => Icons.logout_rounded,
      'export' => Icons.ios_share_rounded,
      'verify' => Icons.fact_check_outlined,
      _ => Icons.history_rounded,
    };
  }

  String _timestamp(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mi = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$dd/$mm/${value.year} $hh:$mi:$ss';
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.label, required this.value});

  final String label;
  final Map<String, Object?>? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final text = const JsonEncoder.withIndent('  ').convert(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
