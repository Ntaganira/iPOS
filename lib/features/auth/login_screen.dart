/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.auth
 * - File      : login_screen.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline sign-in gate. Lists active local accounts, accepts a
 *               masked numeric PIN, and unlocks the session. PINs are never
 *               logged or retained after verification. The first-run banner
 *               discloses the seeded administrator PIN and the forced rotation
 *               is enforced by the application gate before the register mounts.
 * </pre>
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';

/// Account selection and PIN entry.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
    required this.languageCode,
    required this.onLanguageChanged,
    this.firstRun = false,
  });

  final AuthController controller;
  final String languageCode;
  final ValueChanged<String> onLanguageChanged;
  final bool firstRun;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _userId;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final users = widget.controller.activeUsers;
    final userId = _userId ?? (users.isEmpty ? null : users.first.id);
    if (userId == null || _pin.text.trim().isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.controller.login(
      userId: userId,
      pin: _pin.text.trim(),
    );
    if (!ok) {
      _pin
        ..clear()
        ..text = '';
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final users = widget.controller.activeUsers;
    final selectedId = _userId ?? (users.isEmpty ? null : users.first.id);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surfaceContainerLow,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [scheme.primary, scheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.point_of_sale_rounded,
                                color: scheme.onPrimary,
                              ),
                            ),
                            const Spacer(),
                            _LanguageMenu(
                              languageCode: widget.languageCode,
                              onChanged: widget.onLanguageChanged,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          l10n.loginTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.loginSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.firstRun) ...[
                          const SizedBox(height: 16),
                          _Banner(
                            icon: Icons.key_rounded,
                            color: scheme.tertiary,
                            text: l10n.firstRunHint,
                          ),
                        ],
                        if (widget.controller.error != null) ...[
                          const SizedBox(height: 16),
                          _Banner(
                            icon: Icons.error_outline_rounded,
                            color: scheme.error,
                            text: l10n.invalidCredentials,
                          ),
                        ],
                        const SizedBox(height: 22),
                        DropdownButtonFormField<String>(
                          initialValue: selectedId,
                          decoration: InputDecoration(
                            labelText: l10n.selectUser,
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          items: [
                            for (final user in users)
                              DropdownMenuItem<String>(
                                value: user.id,
                                child: Text(
                                  '${user.displayName} · ${_roleLabel(l10n, user.roleId)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _userId = value),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pin,
                          autofocus: true,
                          obscureText: _obscure,
                          enabled: !_busy && users.isNotEmpty,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.pin,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show PIN' : 'Hide PIN',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: users.isEmpty || _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_open_rounded),
                          label: Text(l10n.signIn),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.offlineCommit,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String roleId) {
    return switch (roleId) {
      'role-admin' => l10n.roleAdmin,
      'role-manager' => l10n.roleManager,
      _ => l10n.roleCashier,
    };
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.languageCode, required this.onChanged});

  final String languageCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: AppLocalizations.of(context).language,
      initialValue: languageCode,
      onSelected: onChanged,
      icon: const Icon(Icons.translate_rounded),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'en',
          child: Text(AppLocalizations.of(context).languageEnglish),
        ),
        PopupMenuItem<String>(
          value: 'fr',
          child: Text(AppLocalizations.of(context).languageFrench),
        ),
        PopupMenuItem<String>(
          value: 'rw',
          child: Text(AppLocalizations.of(context).languageKinyarwanda),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
