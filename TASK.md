# iPOS - Implementation Tracker

> Project: iPOS - Point Of Sale
> Owner: Hntaganira
> Started: 2026. 10. 22.
> Architecture: Offline-first Flutter client + encrypted local ledger + online web back office (separate deployment).

This tracker is the single source of truth for the build. A checked item means the
source is present and reviewed in this repository. Items marked `[ ]` are deliberately
left for the next integration pass (native shells, web back office, sync transport,
or CI-only work).

## 1. Dependencies & Project Setup

- [x] Declare Flutter/Dart SDK constraints and production dependency graph in `pubspec.yaml`.
- [x] Add Drift 2.x for typed schema ownership, migrations, transactions, and reactive-ready queries.
- [x] Select SQLCipher through `package:sqlite3` 3.x native build hooks
      (`hooks.user_defines.sqlite3.source: sqlcipher`). This replaces the retired
      `sqlcipher_flutter_libs` / `sqflite_sqlcipher` generation.
- [x] Add `flutter_secure_storage` 11.x for Android Keystore, iOS/macOS Keychain,
      Windows credential protection, and Linux Secret Service access.
- [x] Add `path_provider`, `path`, `uuid`, and `intl` utilities.
- [x] Add `drift_dev` + `build_runner` generation dependencies.
- [x] Add `main.dart` / `app.dart` composition root with fail-closed vault startup,
      process-wide repository/controller ownership, dark POS default, and theme toggle.
- [x] Run `flutter pub get` and `dart run build_runner build` with the installed
      toolchain; `app_database.g.dart` is generated and committed as the reviewable schema artifact.
- [x] Generate Android, iOS, Windows, macOS, and Linux runner scaffolding, set the visible
      iPOS identity, enforce Android `minSdk 23`, and disable Android auto-backup so the
      encrypted vault is never restored without its Keystore key. Web is unsupported because
      SQLCipher uses `dart:ffi`.
- [ ] Add iOS/macOS Keychain Sharing entitlements and validate secure storage on each runner.
- [ ] Install Windows "Desktop development with C++" components and enable Developer Mode for
      plugin symlinks; accept Android SDK licenses before native smoke builds.
- [ ] Verify SQLCipher native assets on Android, iOS, Windows, macOS, and Linux.
- [ ] Configure release signing, obfuscation, and CI artifact signing per platform.

## 2. Secure Key Management

- [x] Add `SecureKeyManager` with a single-flight, write-once 256-bit key lifecycle.
- [x] Generate keys with `Random.secure()` (32 bytes, 64-char hex, no passphrase KDF at rest).
- [x] Fail closed if an existing key is malformed; never silently rotate a live database key.
- [x] Configure platform secure-storage options (Android RSA-OAEP/AES-GCM; macOS keychain mode).
- [x] Document OS-protected key guarantees and platform limitations in source Doxygen/DartDoc.
- [ ] Add migration ceremony for key rotation (`PRAGMA rekey`) behind an explicit admin action.
- [ ] Add backup/restore playbook proving the encrypted file is unusable without the platform key.

## 3. Encrypted Database & Relational Schema

- [x] Add `AppDatabase` Drift schema with `products`, `vehicles`, `product_compatibility`,
      `stock_ledger`, `customers`, `invoices`, and `invoice_lines`.
- [x] Add UUID text primary keys and sync metadata (`updated_at`, `is_synced`, `is_deleted`)
      for every mutable replicated entity.
- [x] Store money as integer minor units (precision-safe offline accounting).
- [x] Add append-only stock ledger (`qty_delta`) with no soft-delete flag.
- [x] Add foreign keys, cascade rules, and idempotent performance indexes.
- [x] Add `AppDatabaseFactory` applying a raw 256-bit SQLCipher key before migrations.
- [x] Set WAL, `foreign_keys`, `synchronous=NORMAL`, in-memory temp store, and SQLCipher 4 compatibility.
- [x] Add Drift schema export + migration tests for version 1 to N (`drift_schema_v3.json`, v1→3 and v2→3).
- [x] Add a background checkpointer and corruption recovery/export-to-plaintext (admin) path.
- [x] Add an implicit `UomConversion` lookup matrix to support structural split-pack deductions (e.g., selling single parts out of wholesale boxes).
- [x] Add a post-shift `PRAGMA wal_checkpoint` + `PRAGMA vacuum` routine triggered by shift close.

## 4. Repositories & Transactional Lookup

- [x] Add `CatalogRepository` with YMM cascading list queries.
- [x] Add an optimized, parameterized, transactional OEM/aftermarket lookup by `vehicle_id`
      that excludes `is_deleted` products and compatibility rows.
- [x] Add escaped, limited catalog search across SKU / OEM number / part name.
- [x] Add `CheckoutRepository` committing invoice, invoice lines, and negative stock-ledger
      movements in one ACID transaction.
- [x] Generate collision-resistant offline invoice numbers per local day.
- [x] Snapshot SKU, description, brand, unit price, tax rate, and line totals on invoice lines.
- [x] Add in-memory Drift integration tests for YMM filtering, soft deletes, exact lookup,
      transaction rollback, invoice sequencing, line snapshots, and stock movements.
- [x] Add repository tests against a keyed in-memory SQLCipher database.
- [x] Add sync outbox drain with retry backoff, server-conflict overwrite, cursor persistence, and failure notifications.
- [ ] Add back-office reconciliation adapters for serving push/pull and resolving conflicts.

- [x] Implement Core Fee Flag handling on invoice items to separate core deposits from base product retail totals.
- [ ] Design a catalog sync ingestion adapter that processes compressed database files rather than heavy JSON text payloads.


## 5. Theme, Shell & Responsive 3-Column POS UI

- [x] Add global Material 3 light theme and a low-strain, high-contrast dark POS theme.
- [x] Add compact visual density and keyboard-first focus styling.
- [x] Add collapsible left module rail (Register, Inventory Registry, Customers, Settings).
- [x] Persist the sidebar as an animated expanded/collapsed rail with overflow-safe labels.
- [x] Add responsive breakpoints: three inline columns on desktop, checkout drawer on tablets,
      and label drawer for the module rail when space is constrained.
- [x] Add center workspace: full-width search, cascading YMM filters, inline virtualized catalog table.
- [x] Add right checkout panel: customer account selector, cart lines, tax math, payment methods,
      atomic sale completion, and receipt dialog.
- [x] Add keyboard affordances: F2 focuses search; Enter submits and adds an unambiguous match.
- [x] Add empty/loading/error states and dense row interaction for touch and mouse.
- [x] Add short-window handling: scrollable checkout below 620 px and a horizontally
      scrollable YMM strip on narrow phones, preventing RenderFlex overflow.
- [x] Replace scaffolded Inventory Registry / Customers / Settings modules with full screens.
- [x] Add barcode scanner wedge tuning, hotkey customization, and cash-drawer/receipt printing.
- [x] Add responsive widget smoke tests for phone portrait/landscape, tablet, 1024, 1280,
      and 1920 px layouts, including the checkout end drawer.
- [x] Add golden snapshots and interaction tests for cart mutation and receipt flows.

## 6. Separate Web Back Office (Online-Only)

- [ ] Define back-office domain: master data, supplier ingestion, accounting periods, global tax rules.
- [ ] Add authenticated admin console (separate web deployment; never bundled in the offline client).
- [ ] Add inventory receiving workflow (PO -> receive -> bin assignment -> stock ledger).
- [ ] Add sync API: push device deltas, pull master changes, resolve conflicts, issue sync cursors.
- [ ] Add accounting exports and immutable audit views.

## 7. Production Hardening & Verification

- [x] Add corporate file-header signature blocks to all authored Dart modules and pubspec.
- [x] Add this tracker and keep checklist flags current.
- [x] Run `flutter analyze` and `flutter test` clean (schema, vault, ledger, audit, auth, notifications, responsive/locale smoke).
- [ ] Run Android, iOS, Windows, macOS, and Linux smoke builds on their native runners.
- [x] Add crash reporting with secret redaction and structured checkout audit logs.
- [ ] Add rate/disk-full handling, database key loss UX, and disaster-recovery runbook.
- [x] Add accessibility pass (contrast audit, large text, screen reader labels).

## 8. Identity, Localization, Notifications & Audit

- [x] Add offline sign-in with PBKDF2-HMAC-SHA256 PIN hashing, forced first-run PIN rotation, and session actor resolution.
- [x] Add role-based access control (admin, manager, cashier) with permission-gated modules and settings tabs.
- [x] Seed three system roles and the first administrator idempotently; protect the last administrator from deactivation.
- [x] Add user administration: create, edit, deactivate/activate, reset PIN, audit every change with actor and before/after.
- [x] Add English, French, and Kinyarwanda localization for register, checkout, inventory, customers, settings, auth, audit, users, and notifications.
- [x] Add Kinyarwanda framework-localization fallbacks so Material/Widgets/Cupertino controls build without a native `rw` bundle.
- [x] Persist language and theme and apply them live without restart.
- [x] Add hash-chained audit events with actor, action, entity, timestamp, and before/after JSON; add chain verification UI.
- [x] Add notification inbox with unread dedupe, severity, mark-read, clear-read, and a reactive shell badge.
- [x] Emit notifications for low stock, shift close, integrity failure, encrypted backup, and plaintext export.
- [x] Emit sync/offline-queue notifications when the outbox drain is implemented.
- [x] Add cash-drawer kick and ESC/POS receipt printing wired to the configured network printer transport.
- [x] Add print preview and paper selection for A4 PDF, 80 mm thermal, and 58 mm mini/mobile printers.
- [x] Add proforma invoice printing from the live cart without deducting stock or writing an invoice.
- [x] Add SMTP email configuration under Settings and send invoices/proformas as a PDF attachment or plain text.
- [x] Persist and restore in-progress cart drafts across sign-out, shutdown, or accidental exit.
- [x] Add runtime hotkey binding from persisted settings for search and checkout.
- [x] Add configurable scanner wedge timing through a dedicated key-burst detector in the register search field.
- [x] Wire the explicit admin key-rotation ceremony to the maintenance UI with restart guidance.
- [x] Add golden snapshots and cart-mutation/receipt interaction tests.
