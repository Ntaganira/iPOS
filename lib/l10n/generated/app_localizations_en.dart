// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'iPOS';

  @override
  String get appTagline => 'Offline parts counter';

  @override
  String get navRegister => 'Register';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navSettings => 'Settings';

  @override
  String get expandSidebar => 'Expand navigation';

  @override
  String get collapseSidebar => 'Collapse navigation';

  @override
  String get switchToLight => 'Switch to light mode';

  @override
  String get switchToDark => 'Switch to dark mode';

  @override
  String loggedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get logout => 'Sign out';

  @override
  String get searchHint => 'Search SKU, OEM number, or description';

  @override
  String get searchHelp => 'Scan a part or type at least one character';

  @override
  String get noParts => 'No matching parts';

  @override
  String get noPartsHint =>
      'Adjust the search or vehicle filters, or add the part in Inventory.';

  @override
  String get loadingCatalog => 'Loading catalog…';

  @override
  String get makeLabel => 'Make';

  @override
  String get allMakes => 'All makes';

  @override
  String get modelLabel => 'Model';

  @override
  String get allModels => 'All models';

  @override
  String get yearLabel => 'Year';

  @override
  String get allYears => 'All years';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get newSale => 'New sale';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get cartEmpty => 'Cart is empty';

  @override
  String get cartHint =>
      'Scan a part, press Enter for an unambiguous match, or tap a catalog row to begin.';

  @override
  String get customerLabel => 'Customer';

  @override
  String get walkInCustomer => 'Walk-in customer';

  @override
  String get subtotal => 'Subtotal';

  @override
  String vatRate(String rate) {
    return 'VAT $rate';
  }

  @override
  String get coreDeposits => 'Core deposits (refundable)';

  @override
  String get total => 'TOTAL';

  @override
  String get paymentMethod => 'PAYMENT';

  @override
  String get cash => 'Cash';

  @override
  String get card => 'Card';

  @override
  String get mobile => 'Mobile';

  @override
  String get charge => 'Charge';

  @override
  String get offlineCommit =>
      'Offline commit · invoice + lines + stock ledger are atomic';

  @override
  String get saleCompleted => 'Sale completed';

  @override
  String get savedLocal =>
      'Saved to the encrypted local ledger. Invoice lines, stock movements, and the audit event were committed together.';

  @override
  String get inventoryTitle => 'Inventory registry';

  @override
  String get inventorySubtitle => 'Products, prices, stock, and selling units';

  @override
  String get addProduct => 'Add product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get searchInventory => 'Search inventory';

  @override
  String get noProducts => 'No products yet';

  @override
  String stockOnHand(int count) {
    return 'On hand: $count';
  }

  @override
  String get lowStock => 'Low stock';

  @override
  String get adjustStock => 'Adjust stock';

  @override
  String get stockAdjustment => 'Stock adjustment';

  @override
  String get adjustmentReason => 'Reason';

  @override
  String get quantityDelta => 'Quantity change';

  @override
  String get binLocation => 'Bin / shelf';

  @override
  String get sku => 'SKU';

  @override
  String get description => 'Description';

  @override
  String get brand => 'Brand';

  @override
  String get retailPrice => 'Retail price';

  @override
  String get tradePrice => 'Trade price';

  @override
  String get coreFee => 'Core / deposit';

  @override
  String get baseUnit => 'Base unit';

  @override
  String get sellingUnits => 'Selling units';

  @override
  String get addUnit => 'Add selling unit';

  @override
  String get unitLabel => 'Unit label';

  @override
  String get conversionFactor => 'Base units per unit';

  @override
  String get initialStock => 'Opening stock';

  @override
  String get movements => 'Stock movements';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersSubtitle => 'Trade accounts and cached balances';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get searchCustomers => 'Search customers';

  @override
  String get noCustomers => 'No customer accounts yet';

  @override
  String get customerName => 'Customer name';

  @override
  String get phone => 'Phone';

  @override
  String get taxId => 'Tax ID';

  @override
  String get balance => 'Balance';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Terminal, security, printing, and sync';

  @override
  String get storeName => 'Store name';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark POS mode';

  @override
  String get taxRate => 'VAT rate (%)';

  @override
  String get scannerSettings => 'Barcode scanner';

  @override
  String get scannerMinLength => 'Minimum scan length';

  @override
  String get scannerTimeout => 'Inter-key timeout (ms)';

  @override
  String get hotkeys => 'Hotkeys';

  @override
  String get searchHotkey => 'Search hotkey';

  @override
  String get checkoutHotkey => 'Checkout hotkey';

  @override
  String get printerSettings => 'Receipt printer';

  @override
  String get printerHost => 'Printer host';

  @override
  String get printerPort => 'Printer port';

  @override
  String get syncSettings => 'Back-office sync';

  @override
  String get syncEndpoint => 'Sync endpoint';

  @override
  String get syncToken => 'Sync token';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get usersTitle => 'Users and roles';

  @override
  String get addUser => 'Add user';

  @override
  String get editUser => 'Edit user';

  @override
  String get roleLabel => 'Role';

  @override
  String get pinLabel => 'PIN';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get mustChangePin => 'Must change PIN';

  @override
  String get resetPin => 'Reset PIN';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleCashier => 'Cashier';

  @override
  String get shiftClose => 'Shift close';

  @override
  String get closeShift => 'Close shift';

  @override
  String get shiftSummary => 'Shift summary';

  @override
  String get invoicesCount => 'Invoices';

  @override
  String get gross => 'Gross';

  @override
  String get tax => 'Tax';

  @override
  String get encryptedBackup => 'Create encrypted backup';

  @override
  String get exportPlaintext => 'Export decrypted copy';

  @override
  String get rotateKey => 'Rotate database key';

  @override
  String get loginTitle => 'Unlock iPOS';

  @override
  String get loginSubtitle => 'Select your account and enter your PIN.';

  @override
  String get selectUser => 'Account';

  @override
  String get pin => 'PIN';

  @override
  String get signIn => 'Unlock';

  @override
  String get invalidCredentials => 'That account and PIN do not match.';

  @override
  String get firstRunHint =>
      'First launch: administrator PIN 1234. Change it immediately.';

  @override
  String get changePin => 'Change PIN';

  @override
  String get currentPin => 'Current PIN';

  @override
  String get newPin => 'New PIN';

  @override
  String get confirmPin => 'Confirm new PIN';

  @override
  String get pinMismatch => 'The new PINs do not match.';

  @override
  String get pinChanged => 'PIN updated';

  @override
  String get permissionDenied => 'You do not have permission for this action.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get printReceipt => 'Print receipt';

  @override
  String get printingUnavailable => 'Configure a receipt printer in Settings.';

  @override
  String get printFailed => 'Receipt could not be printed.';

  @override
  String get receiptPrinted => 'Receipt sent to printer';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncComplete => 'Sync completed';

  @override
  String get syncNotConfigured =>
      'Configure the sync endpoint and token first.';

  @override
  String get shiftClosed => 'Shift closed';

  @override
  String get noSalesInShift => 'No sales in this shift.';

  @override
  String get databaseMaintenance => 'Database maintenance';

  @override
  String get integrityCheck => 'Run integrity check';

  @override
  String get backupCreated => 'Encrypted backup created';

  @override
  String get plaintextWarning =>
      'The decrypted copy is unprotected. Store it securely and delete it after use.';

  @override
  String get keyRotationWarning =>
      'Rotating the key closes the till and requires a restart. A recovery backup is created first.';

  @override
  String get keyRotated => 'Database key rotated. Restart iPOS.';

  @override
  String get restartRequired =>
      'Restart iPOS to open the vault with the new key.';

  @override
  String get loading => 'Loading…';

  @override
  String get errorGeneric =>
      'Something went wrong. Nothing was lost; try again.';

  @override
  String get errorDiskFull => 'Storage is full. Free space before continuing.';

  @override
  String get errorVault =>
      'The encrypted vault is unavailable. Do not clear app data; follow the recovery runbook.';

  @override
  String get errorStorageReadOnly =>
      'Storage is read-only. Check disk permissions or free the volume.';

  @override
  String get errorStorageBusy =>
      'The ledger is busy. Wait a moment and retry; the cart is intact.';

  @override
  String get errorStorageCorrupt =>
      'The local ledger could not be read. Do not clear app data; export a backup or follow the recovery runbook.';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'You\'re all caught up.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get clearRead => 'Clear read';

  @override
  String unreadCount(int count) {
    return '$count unread';
  }

  @override
  String get pinInvalid => 'PIN must be 4 to 8 digits.';

  @override
  String get rolePermissions => 'Permissions';

  @override
  String get noUsers => 'No users';

  @override
  String get userCreated => 'User created';

  @override
  String get userUpdated => 'User updated';

  @override
  String get pinResetDone =>
      'PIN reset. The user must change it at next sign-in.';

  @override
  String get lastSignIn => 'Last sign-in';

  @override
  String get never => 'Never';

  @override
  String get confirmResetPin => 'Reset this user PIN?';

  @override
  String get setTemporaryPin => 'Temporary PIN';

  @override
  String get status => 'Status';

  @override
  String get permissions => 'Permissions';

  @override
  String get passwordPolicy => '4 to 8 digits';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get activate => 'Activate';

  @override
  String get permSell => 'Sell';

  @override
  String get permRefund => 'Refund';

  @override
  String get permInventory => 'Manage inventory';

  @override
  String get permCustomers => 'Manage customers';

  @override
  String get permSettings => 'Manage settings';

  @override
  String get permUsers => 'Manage users';

  @override
  String get permReports => 'View reports';

  @override
  String get permAudit => 'View audit trail';

  @override
  String get permBackup => 'Manage backups';

  @override
  String get permRotate => 'Rotate keys';

  @override
  String get auditTitle => 'Audit trail';

  @override
  String get auditSubtitle =>
      'Every recorded action with actor, before, and after values';

  @override
  String get verifyChain => 'Verify chain';

  @override
  String chainValid(int count) {
    return 'Audit chain valid ($count events)';
  }

  @override
  String chainInvalid(String id) {
    return 'Audit chain broken at $id';
  }

  @override
  String get searchAudit => 'Search actor, action, or entity';

  @override
  String get noAudit => 'No audit events match';

  @override
  String get beforeLabel => 'Before';

  @override
  String get afterLabel => 'After';

  @override
  String get actorLabel => 'Actor';

  @override
  String get actionLabel => 'Action';

  @override
  String get entityLabel => 'Entity';

  @override
  String get systemActor => 'System';

  @override
  String eventsCount(int count) {
    return '$count events';
  }

  @override
  String get maintenanceTitle => 'Database maintenance';

  @override
  String get maintenanceSubtitle =>
      'Backups, integrity, shift close, and plaintext export';

  @override
  String get integrityValid => 'Integrity check passed';

  @override
  String get integrityInvalid =>
      'Integrity check failed. Restore a verified backup.';

  @override
  String get vacuumDone => 'Storage compacted';

  @override
  String get shiftCloseConfirm =>
      'Close the current shift and run post-shift maintenance?';

  @override
  String get plaintextExportConfirm =>
      'This writes an unencrypted copy. Continue only if authorized.';

  @override
  String get refresh => 'Refresh';

  @override
  String get search => 'Search';

  @override
  String get productCreated => 'Product created';

  @override
  String get productUpdated => 'Product updated';

  @override
  String get stockAdjusted => 'Stock adjusted';

  @override
  String get confirmDeleteProduct =>
      'Delete this product? Historical invoices remain.';

  @override
  String get deleted => 'Deleted';

  @override
  String get uomSaved => 'Selling unit saved';

  @override
  String get removeUnit => 'Remove unit';

  @override
  String get unit => 'Unit';

  @override
  String get price => 'Price';

  @override
  String get invalidNumber => 'Enter a valid number.';

  @override
  String get noStock => 'Out of stock';

  @override
  String get customerCreated => 'Customer created';

  @override
  String get customerUpdated => 'Customer updated';

  @override
  String get confirmDeleteCustomer =>
      'Delete this customer? Historical invoices remain.';

  @override
  String get offlineReady => 'Offline-ready';

  @override
  String get encryptedLocalVault => 'Encrypted local vault';

  @override
  String get encryptedVaultActive => 'Encrypted local vault is active';

  @override
  String get scaffoldedPending =>
      'SCAFFOLDED · BACK-OFFICE INTEGRATION PENDING';

  @override
  String get frontCounter => 'Front Counter';

  @override
  String get frontCounterSubtitle =>
      'Offline register · YMM fitment · encrypted local invoices';

  @override
  String get cart => 'Cart';

  @override
  String get viewCart => 'View cart';

  @override
  String addedToCart(String name, String price) {
    return '$name · $price added';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get searchPartsHint => 'Scan or type SKU, OEM number, or part name…';

  @override
  String get searching => 'Searching…';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts',
      one: '1 part',
      zero: 'No parts',
    );
    return '$_temp0';
  }

  @override
  String get localOnly => 'Local';

  @override
  String get searchShortcut => 'F2 search · Enter adds top match';

  @override
  String get catalogUnavailable => 'Catalog unavailable';

  @override
  String get retry => 'Retry';

  @override
  String get noMatchingParts => 'No matching parts';

  @override
  String get noMatchingPartsHint =>
      'Try a shorter SKU/OEM fragment, clear a YMM filter, or confirm the catalog has been ingested for this vehicle.';

  @override
  String get resetFilters => 'Reset search and YMM filters';

  @override
  String get oem => 'OEM';

  @override
  String get part => 'Part';

  @override
  String unitsLines(int units, int lines) {
    return '$units units · $lines lines';
  }

  @override
  String get clearCart => 'Clear cart';

  @override
  String get closeCheckout => 'Close checkout';

  @override
  String get customerAccount => 'Customer account';

  @override
  String get removeLine => 'Remove line';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get sellingUnit => 'Selling unit';

  @override
  String coreIncluded(String amount) {
    return 'Includes $amount refundable core deposit';
  }

  @override
  String get payment => 'Payment';

  @override
  String get saleSaved =>
      'Saved to the encrypted local ledger. Invoice lines and stock movements were committed together.';

  @override
  String get addToCart => 'Add to cart';

  @override
  String searchShortcutKey(String key) {
    return '$key search · Enter adds top match';
  }

  @override
  String get printPreview => 'Print preview';

  @override
  String get paperA4 => 'A4 invoice';

  @override
  String get paper80mm => '80 mm thermal';

  @override
  String get paper58mm => '58 mm mini';

  @override
  String get printNow => 'Print';

  @override
  String get printProforma => 'Proforma';

  @override
  String get proformaPrinted => 'Proforma sent to printer';

  @override
  String get proformaPrintFailed => 'Proforma could not be printed.';

  @override
  String get receiptPaper => 'Receipt paper';

  @override
  String get draftRestored => 'Draft restored. Continue where you left off.';

  @override
  String get emailInvoice => 'Email invoice';

  @override
  String get emailProforma => 'Email proforma';

  @override
  String get emailRecipient => 'Recipient email';

  @override
  String get emailDelivery => 'Delivery';

  @override
  String get emailPdfAttachment => 'PDF attachment';

  @override
  String get emailPlainText => 'Text only';

  @override
  String get sendEmail => 'Send email';

  @override
  String get emailSent => 'Invoice sent';

  @override
  String get emailSentProforma => 'Proforma sent';

  @override
  String get emailFailed => 'Email could not be sent.';

  @override
  String get emailNotConfigured => 'Configure email in Settings first.';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get emailSettings => 'Email';

  @override
  String get emailSubtitle => 'SMTP relay for invoices and proformas';

  @override
  String get emailHost => 'SMTP host';

  @override
  String get emailPort => 'SMTP port';

  @override
  String get emailUsername => 'SMTP username';

  @override
  String get emailPassword => 'SMTP password';

  @override
  String get emailFromAddress => 'From address';

  @override
  String get emailFromName => 'From name';

  @override
  String get emailUseSsl => 'Use implicit SSL (usually port 465)';

  @override
  String get emailConfigNote =>
      'Credentials are stored in the encrypted local database.';
}
