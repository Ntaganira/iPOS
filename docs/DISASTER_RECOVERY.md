# iPOS Disaster Recovery Runbook

Applies to the offline till ledger (`iPOS/ipos.sqlite3`) and its SQLCipher
database key. Keep this file with the store's operating procedures.

## Non-negotiable facts

- The ledger is a SQLCipher database encrypted with a raw 256-bit key. The key
  lives only in the platform secure store under the alias
  `ipos.sqlcipher.aes256.v1`.
- An encrypted backup is ciphertext. It is **not** usable without the matching
  platform key. Copying only `ipos.sqlite3` off-device does not create a
  recoverable backup.
- iPOS deliberately has no UI to display or export the key. Protect the key by
  protecting the device profile/secure store, not by handling key material.
- Do not uninstall the app, clear app data, delete the database, or delete
  `ipos.sqlite3-wal` / `ipos.sqlite3-shm` during an incident. Those files may
  contain committed sales not yet checkpointed into the main file.
- If the database key and every key-bearing device/profile backup are lost, the
  encrypted ledger cannot be decrypted. No support action can reverse that.
- There is exactly one writer. Stop all other app instances and backup tools
  before restoring files.

## Where the files are

Use the path shown by the startup failure screen or from the diagnostics log.
Under the application-support directory the app owns:

```text
iPOS/
  ipos.sqlite3          encrypted ledger
  ipos.sqlite3-wal      write-ahead log (may exist)
  ipos.sqlite3-shm      shared-memory index (may exist)
  backups/
    ipos-<timestamp>.sqlite3          encrypted backup
    pre-rotate-<timestamp>.sqlite3    pre-key-rotation backup
  diagnostics/
    crash.log
    crash.log.1
```

Platform secure stores:

- Android: Keystore-backed encrypted storage.
- iOS/macOS: Keychain.
- Windows: Windows credential protection tied to the user profile.
- Linux: Secret Service / login keyring.

Normal device backups do not always include non-exportable platform keys.
Verify by restoring onto a clean device before relying on a backup.

## First response

1. Stop entering sales on the affected terminal. Move trade to a second
   terminal or paper receipts if one is available.
2. On the startup failure screen choose **Copy diagnostics**. It includes the
   error, UTC time, diagnostics path, and this runbook's name.
3. Do not rename, delete, or "repair" the ledger yet. Make a copy of
   `ipos.sqlite3`, `-wal`, and `-shm` together to preserve evidence before any
   restore. Keep the copy on encrypted media.
4. Classify the failure with the table below and follow that section.
5. Record the incident: time, operator, symptom, files copied, backup used, and
   verification result.

| Symptom | Likely class | Section |
| --- | --- | --- |
| "database or disk is full", OS no-space errors | Disk full | Disk full |
| "readonly database", "attempt to write a readonly database" | Read-only volume | Read-only storage |
| "database is locked", transient checkout failure | Busy | Busy ledger |
| "database disk image is malformed", failed integrity check | Corruption | Corruption |
| "database key is missing", "invalid iPOS database key" | Key loss | Lost database key |
| "file is not a database" with a known-good key | Corruption or wrong key | Corruption / Lost key |
| Sync HTTP 429 / "rate-limited" notification | Rate limiting | Sync rate limiting |

## Disk full

The checkout cart is preserved when a commit fails; nothing partial is written.
SQLCipher rolls the failed transaction back.

1. Free space at OS level. Delete or move old off-device copies, installers, and
   non-iPOS files. Do not delete iPOS backups until a newer verified backup is
   off-device.
2. Keep headroom for WAL growth: at least several hundred MB beyond current
   usage on a production till.
3. Check that `diagnostics/crash.log` is rotating (512 KB per file, one rotated
   file). Repeated crashes can consume space but should remain bounded.
4. Retry the sale. If the failure repeats, restart the app after freeing space.
5. Run an integrity check and create a fresh encrypted backup, then copy it
   off-device.

Do not run VACUUM on a full disk; it needs temporary free space.

## Read-only storage

1. Confirm the volume/partition is mounted read-write.
2. Check folder permissions for the application-support directory. The app must
   be able to create, rename, and delete files in `iPOS/`.
3. On Windows check Controlled Folder Access and antivirus exclusions for the
   app data directory; on Linux check ownership and the login keyring; on
   Android/iOS do not move the app to restricted external storage.
4. Restart the app. A read-only diagnostics directory does not block startup,
   but a read-only ledger does.

## Busy ledger

`SQLITE_BUSY` is transient. Checkout retries once automatically; the cart stays
intact if both attempts fail.

1. Close any second iPOS instance, DB browser, sync tool, or antivirus scan
   holding the file.
2. Wait for the other operation (backup, VACUUM, key rotation) to finish. Key
   rotation requires the database to be closed.
3. Retry. Do not force-kill the app during a write or delete `-wal`/`-shm` to
   "unlock" it.

## Corruption

1. Stop sales. Preserve a copy of the main file and both sidecars.
2. If the app can open and sign in, run **Maintenance > Verify integrity**.
   Failed integrity creates a critical notification and an audit event.
3. If it cannot open, compare with the latest encrypted backup:
   - create a fresh copy of the failed ledger;
   - replace `ipos.sqlite3` with the chosen backup;
   - remove the target directory's stale `-wal` and `-shm` files (they belong to
     the failed file, not the backup);
   - launch with the same secure-store key and run an integrity check.
4. Verify business state after restore: today's invoices, shift totals, stock
   movements, customer balances, and the audit chain. Sales made after the
   backup timestamp are not recoverable from that backup; re-enter them only
   from signed paper receipts or exported reports and mark them clearly.
5. Record the data-loss window in the incident log.

## Lost database key

This is the failure mode that makes ciphertext permanently unreadable.

1. Do not clear app data or reinstall. If the database exists and the key is
   missing, iPOS now fails closed instead of generating a replacement key.
2. Check whether the user profile, OS keychain/credential store, or full-device
   backup was restored or migrated incorrectly. Restore the original profile or
   secure-store entry if a verified device/profile backup exists.
3. Android Keystore keys are normally non-exportable and may not be present in
   Android Auto Backup. Restoring only app files to a new device can therefore
   produce this state.
4. If the original key cannot be recovered, the ledger is unrecoverable. Start a
   new ledger only after an authorized administrator accepts the loss, preserve
   the failed files for the record, and re-enter outstanding business data from
   external evidence.
5. Never guess or overwrite the secure-store entry with a newly generated key:
   it cannot decrypt the existing file.

## Key rotation failure

Rotation keeps `backups/pre-rotate-<timestamp>.sqlite3` encrypted with the old
key and only replaces the secure-store key after SQLCipher verifies the new key.

- If rotation fails before the rekey completes, the live ledger and old key are
  unchanged. Resolve the error and retry.
- If the secure-store write fails after the rekey, the app attempts to copy the
  pre-rotation backup back over the live ledger so the still-persisted old key
  opens it. If that copy also fails, keep the app closed and restore
  `pre-rotate-*.sqlite3` over `ipos.sqlite3`, remove stale `-wal`/`-shm`, and
  start with the old key.
- Never delete the pre-rotation backup until the new key has opened the ledger,
  an integrity check passes, and a fresh backup is stored off-device.

## Sync rate limiting

Sales are local-first; a 429 never blocks checkout.

- The outbox and cursor are preserved. `Retry-After` is honored from 1 second to
  1 hour; without a header a 429 waits at least 120 seconds. Other transport
  failures use exponential backoff from 30 seconds up to 1 hour.
- Do not clear the outbox, sync token, or cursor to "fix" a rate limit. That can
  duplicate or lose work.
- Confirm the endpoint and token, then let the scheduled retry run. If the
  server operator changed the limit, update the sync configuration and retry
  manually from Settings.
- Repeated failures create one deduplicated `sync_failed` notification per
  condition.

## Backup policy

1. Before a backup, run an integrity check and checkpoint the WAL (the backup
   action does this automatically). Record the resulting file name.
2. Create the backup from **Maintenance > Encrypted backup**. Copy it
   off-device to encrypted storage. A backup left only on the till is not a
   disaster-recovery copy.
3. Keep multiple generations and at least one copy outside the store. Verify
   that the backup medium is readable.
4. Test a restore quarterly on a non-production profile/device using a copy of
   the backup. Confirm the key is available to that profile. Record the restore
   time (RTO) and the backup age (RPO) actually achieved.
5. A plaintext export is a break-glass administrator action. It is gated by an
   explicit acknowledgement, audited, and notified. Move it to protected
   storage and delete it from the till immediately after use.
6. Encrypted backups are only as recoverable as the secure-store key. Include
   the secure store/profile in the device backup strategy or accept that a lost
   key means a lost backup.

## Restore procedure

1. Stop iPOS completely. Confirm no process has the database open.
2. Copy the current `ipos.sqlite3`, `-wal`, and `-shm` to an incident folder.
3. Select the newest backup that predates the incident and is known to match the
   current secure-store key. If the key was rotated after that backup, use the
   matching pre-rotation key only through the rotation recovery procedure.
4. Copy the backup to `iPOS/ipos.sqlite3` (not alongside it).
5. Remove stale `ipos.sqlite3-wal` and `ipos.sqlite3-shm` from the target
   directory. Never copy WAL/SHM files from a different database generation.
6. Start iPOS. Sign in, run **Maintenance > Verify integrity**, and check the
   audit-chain verification.
7. Reconcile invoices, shift, stock, customers, and pending sync outbox against
   the last known state. Do not start a sync storm until the ledger is verified.
8. Create a new encrypted backup and store it off-device. Close the incident
   record with the verified RPO/RTO and any re-entered sales.

## Evidence that a backup needs its key

Repository tests prove the property this runbook depends on:

- `test/data/encrypted_vault_test.dart` shows SQLCipher rejects a wrong key.
- `test/data/database_maintenance_test.dart` opens a created encrypted backup
  with a different key and asserts the read fails, then opens the same file with
  the correct key and reads the seeded customer.
- `test/core/secure_key_manager_test.dart` proves an existing ledger with a
  missing secure-store key fails closed without writing a replacement key.

Run them with:

```powershell
flutter test test/data/encrypted_vault_test.dart test/data/database_maintenance_test.dart test/core/secure_key_manager_test.dart
```
