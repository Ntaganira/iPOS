/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.users
 * - File      : users_roles_screen.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline user and role administration. Administrators create
 *               accounts, change role and active status, and issue temporary
 *               PINs. The repository enforces the last-administrator guard and
 *               writes before/after audit snapshots for every change; this
 *               screen only collects input, displays resolved permissions, and
 *               surfaces errors without ever reading a stored PIN digest.
 * </pre>
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security/permissions.dart';
import '../../data/models/app_user.dart';
import '../../l10n/display_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_controller.dart';

/// User directory plus create/edit/reset flows.
class UsersRolesScreen extends StatelessWidget {
  const UsersRolesScreen({super.key, required this.authController});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final users = authController.allUsers;
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
                          l10n.usersTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.permissionDenied,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(l10n.addUser),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: users.isEmpty
                    ? Center(child: Text(l10n.noUsers))
                    : ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _UserCard(
                            user: user,
                            authController: authController,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, {AppUser? user}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _UserEditorDialog(authController: authController, user: user),
    );
    if (result == true && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user == null ? l10n.userCreated : l10n.userUpdated),
        ),
      );
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.authController});

  final AppUser user;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCurrent = authController.currentUser?.id == user.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: user.isActive
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              child: Text(
                _initials(user.displayName),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: user.isActive
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.person_pin_circle_outlined,
                          size: 15,
                          color: scheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(
                        text: roleLabel(l10n, user.roleId),
                        color: scheme.primary,
                      ),
                      if (!user.isActive)
                        _Pill(text: l10n.inactive, color: scheme.error),
                      if (user.mustChangePin)
                        _Pill(
                          text: l10n.mustChangePin,
                          color: const Color(0xFFE0A100),
                        ),
                      Text(
                        '${l10n.lastSignIn}: '
                        '${user.lastLoginAt == null ? l10n.never : _date(user.lastLoginAt!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.editUser,
              onSelected: (value) async {
                if (value == 'edit') {
                  await showDialog<bool>(
                    context: context,
                    builder: (context) => _UserEditorDialog(
                      authController: authController,
                      user: user,
                    ),
                  );
                } else if (value == 'reset') {
                  final reset = await showDialog<bool>(
                    context: context,
                    builder: (context) => _ResetPinDialog(
                      authController: authController,
                      user: user,
                    ),
                  );
                  if (reset == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).pinResetDone,
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined, size: 18),
                    title: Text(l10n.editUser),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'reset',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pin_outlined, size: 18),
                    title: Text(l10n.resetPin),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2));
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _UserEditorDialog extends StatefulWidget {
  const _UserEditorDialog({required this.authController, this.user});

  final AuthController authController;
  final AppUser? user;

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _pin;
  late String _roleId;
  late bool _active;
  bool _busy = false;
  String? _error;

  bool get _creating => widget.user == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.displayName ?? '');
    _pin = TextEditingController();
    _roleId = widget.user?.roleId ?? SystemRoles.cashierId;
    _active = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.customerName);
      return;
    }
    if (_creating && !RegExp(r'^\d{4,8}$').hasMatch(_pin.text)) {
      setState(() => _error = l10n.pinInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = _creating
        ? await widget.authController.createUser(
            displayName: _name.text,
            roleId: _roleId,
            pin: _pin.text,
          )
        : await widget.authController.updateUser(
            userId: widget.user!.id,
            displayName: _name.text,
            roleId: _roleId,
            isActive: _active,
          );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = widget.authController.error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = widget.authController.roles;
    final selectedRole = roles.where((role) => role.id == _roleId).firstOrNull;

    return AlertDialog(
      title: Text(_creating ? l10n.addUser : l10n.editUser),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.customerName,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _roleId,
                decoration: InputDecoration(
                  labelText: l10n.roleLabel,
                  prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                ),
                items: [
                  for (final role in roles)
                    DropdownMenuItem<String>(
                      value: role.id,
                      child: Text(roleLabel(l10n, role.id)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _roleId = value ?? _roleId),
              ),
              if (!_creating) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.active),
                  subtitle: Text(_active ? l10n.activate : l10n.inactive),
                  value: _active,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _active = value),
                ),
              ],
              if (_creating) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.pinLabel,
                    helperText: l10n.passwordPolicy,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                ),
              ],
              if (selectedRole != null) ...[
                const SizedBox(height: 14),
                Text(l10n.rolePermissions, style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final permission in selectedRole.permissions)
                      _Pill(
                        text: permissionLabel(l10n, permission),
                        color: scheme.primary,
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}

class _ResetPinDialog extends StatefulWidget {
  const _ResetPinDialog({required this.authController, required this.user});

  final AuthController authController;
  final AppUser user;

  @override
  State<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<_ResetPinDialog> {
  final TextEditingController _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!RegExp(r'^\d{4,8}$').hasMatch(_pin.text)) {
      setState(() => _error = l10n.pinInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.authController.resetPin(
      userId: widget.user.id,
      newPin: _pin.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = widget.authController.error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.resetPin),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l10n.confirmResetPin}\n${widget.user.displayName}'),
          const SizedBox(height: 14),
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: l10n.setTemporaryPin,
              helperText: l10n.passwordPolicy,
              prefixIcon: const Icon(Icons.lock_reset_rounded),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
