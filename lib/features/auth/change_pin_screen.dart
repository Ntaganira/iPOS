/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.auth
 * - File      : change_pin_screen.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : PIN rotation gate. The forced variant blocks the register for
 *               seeded or administrator-reset accounts until a new salted PIN
 *               is written. The voluntary variant is reusable from Settings.
 *               Both variants verify the current PIN in the repository and
 *               never hold the new PIN beyond the submit call.
 * </pre>
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';

/// Current-PIN verification plus new-PIN confirmation.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({
    super.key,
    required this.controller,
    this.forced = false,
    this.onCompleted,
  });

  final AuthController controller;
  final bool forced;
  final VoidCallback? onCompleted;

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) {
      return;
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(_next.text)) {
      setState(() => _error = l10n.pinInvalid);
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = l10n.pinMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.controller.changePin(
      currentPin: _current.text,
      newPin: _next.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = widget.controller.error ?? l10n.errorGeneric);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pinChanged)));
    if (!widget.forced) {
      Navigator.of(context).pop();
    }
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = widget.controller.currentUser;
    final content = Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.password_rounded,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.changePin,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (user != null) ...[
              const SizedBox(height: 6),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (widget.forced) ...[
              const SizedBox(height: 12),
              Text(
                l10n.mustChangePin,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            _PinField(controller: _current, label: l10n.currentPin),
            const SizedBox(height: 12),
            _PinField(controller: _next, label: l10n.newPin),
            const SizedBox(height: 12),
            _PinField(controller: _confirm, label: l10n.confirmPin),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 18),
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
            if (widget.forced) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: widget.controller.logout,
                child: Text(l10n.logout),
              ),
            ],
          ],
        ),
      ),
    );

    if (!widget.forced) {
      return content;
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
      ),
    );
  }
}
