/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse
 * - File      : main.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Process entry point. Initializes Flutter bindings, provisions
 *               or retrieves the hardware-backed database key, mounts the
 *               SQLCipher ledger, and only then starts the POS. Failures fail
 *               closed into a support screen rather than silently creating a
 *               second key or an unencrypted database.
 * </pre>
 */

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = await AppDatabaseFactory.open();
    runApp(PosApp(database: database));
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'iWarehouse bootstrap',
        context: ErrorDescription('opening the encrypted local ledger'),
      ),
    );
    runApp(_BootFailureApp(error: error));
  }
}

/// Last-resort screen shown when the secure key or encrypted database cannot
/// be opened. It intentionally provides no "reset database" action: a lost key
/// is a data-loss event that must go through the documented recovery process.
class _BootFailureApp extends StatelessWidget {
  const _BootFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iWarehouse POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_person_rounded,
                      size: 48,
                      color: Color(0xFFFFC857),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Encrypted vault could not be opened',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The Till database was not started, so no sale can be '
                      'recorded. Restore the original platform secure-store '
                      'entry or contact a system administrator. Do not clear '
                      'app data unless the ledger has been exported.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB6C2CE),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151D25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A3742)),
                      ),
                      child: SelectableText(
                        error.toString(),
                        maxLines: 5,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB6C2CE),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
