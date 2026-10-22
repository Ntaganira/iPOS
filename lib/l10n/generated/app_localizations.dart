import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_rw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'iPOS'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Offline parts counter'**
  String get appTagline;

  /// No description provided for @navRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get navRegister;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand navigation'**
  String get expandSidebar;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse navigation'**
  String get collapseSidebar;

  /// No description provided for @switchToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchToLight;

  /// No description provided for @switchToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchToDark;

  /// No description provided for @loggedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String loggedInAs(String name);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search SKU, OEM number, or description'**
  String get searchHint;

  /// No description provided for @searchHelp.
  ///
  /// In en, this message translates to:
  /// **'Scan a part or type at least one character'**
  String get searchHelp;

  /// No description provided for @noParts.
  ///
  /// In en, this message translates to:
  /// **'No matching parts'**
  String get noParts;

  /// No description provided for @noPartsHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust the search or vehicle filters, or add the part in Inventory.'**
  String get noPartsHint;

  /// No description provided for @loadingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Loading catalog…'**
  String get loadingCatalog;

  /// No description provided for @makeLabel.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get makeLabel;

  /// No description provided for @allMakes.
  ///
  /// In en, this message translates to:
  /// **'All makes'**
  String get allMakes;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @allModels.
  ///
  /// In en, this message translates to:
  /// **'All models'**
  String get allModels;

  /// No description provided for @yearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearLabel;

  /// No description provided for @allYears.
  ///
  /// In en, this message translates to:
  /// **'All years'**
  String get allYears;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get newSale;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a part, press Enter for an unambiguous match, or tap a catalog row to begin.'**
  String get cartHint;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerLabel;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get walkInCustomer;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @vatRate.
  ///
  /// In en, this message translates to:
  /// **'VAT {rate}'**
  String vatRate(String rate);

  /// No description provided for @coreDeposits.
  ///
  /// In en, this message translates to:
  /// **'Core deposits (refundable)'**
  String get coreDeposits;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT'**
  String get paymentMethod;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @charge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get charge;

  /// No description provided for @offlineCommit.
  ///
  /// In en, this message translates to:
  /// **'Offline commit · invoice + lines + stock ledger are atomic'**
  String get offlineCommit;

  /// No description provided for @saleCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sale completed'**
  String get saleCompleted;

  /// No description provided for @savedLocal.
  ///
  /// In en, this message translates to:
  /// **'Saved to the encrypted local ledger. Invoice lines, stock movements, and the audit event were committed together.'**
  String get savedLocal;

  /// No description provided for @inventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory registry'**
  String get inventoryTitle;

  /// No description provided for @inventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Products, prices, stock, and selling units'**
  String get inventorySubtitle;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @searchInventory.
  ///
  /// In en, this message translates to:
  /// **'Search inventory'**
  String get searchInventory;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProducts;

  /// No description provided for @stockOnHand.
  ///
  /// In en, this message translates to:
  /// **'On hand: {count}'**
  String stockOnHand(int count);

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStock;

  /// No description provided for @adjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust stock'**
  String get adjustStock;

  /// No description provided for @stockAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Stock adjustment'**
  String get stockAdjustment;

  /// No description provided for @adjustmentReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adjustmentReason;

  /// No description provided for @quantityDelta.
  ///
  /// In en, this message translates to:
  /// **'Quantity change'**
  String get quantityDelta;

  /// No description provided for @binLocation.
  ///
  /// In en, this message translates to:
  /// **'Bin / shelf'**
  String get binLocation;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get sku;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @retailPrice.
  ///
  /// In en, this message translates to:
  /// **'Retail price'**
  String get retailPrice;

  /// No description provided for @tradePrice.
  ///
  /// In en, this message translates to:
  /// **'Trade price'**
  String get tradePrice;

  /// No description provided for @coreFee.
  ///
  /// In en, this message translates to:
  /// **'Core / deposit'**
  String get coreFee;

  /// No description provided for @baseUnit.
  ///
  /// In en, this message translates to:
  /// **'Base unit'**
  String get baseUnit;

  /// No description provided for @sellingUnits.
  ///
  /// In en, this message translates to:
  /// **'Selling units'**
  String get sellingUnits;

  /// No description provided for @addUnit.
  ///
  /// In en, this message translates to:
  /// **'Add selling unit'**
  String get addUnit;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit label'**
  String get unitLabel;

  /// No description provided for @conversionFactor.
  ///
  /// In en, this message translates to:
  /// **'Base units per unit'**
  String get conversionFactor;

  /// No description provided for @initialStock.
  ///
  /// In en, this message translates to:
  /// **'Opening stock'**
  String get initialStock;

  /// No description provided for @movements.
  ///
  /// In en, this message translates to:
  /// **'Stock movements'**
  String get movements;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trade accounts and cached balances'**
  String get customersSubtitle;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomer;

  /// No description provided for @searchCustomers.
  ///
  /// In en, this message translates to:
  /// **'Search customers'**
  String get searchCustomers;

  /// No description provided for @noCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customer accounts yet'**
  String get noCustomers;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @taxId.
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get taxId;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal, security, printing, and sync'**
  String get settingsSubtitle;

  /// No description provided for @storeName.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get storeName;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageKinyarwanda.
  ///
  /// In en, this message translates to:
  /// **'Kinyarwanda'**
  String get languageKinyarwanda;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark POS mode'**
  String get darkMode;

  /// No description provided for @taxRate.
  ///
  /// In en, this message translates to:
  /// **'VAT rate (%)'**
  String get taxRate;

  /// No description provided for @scannerSettings.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanner'**
  String get scannerSettings;

  /// No description provided for @scannerMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum scan length'**
  String get scannerMinLength;

  /// No description provided for @scannerTimeout.
  ///
  /// In en, this message translates to:
  /// **'Inter-key timeout (ms)'**
  String get scannerTimeout;

  /// No description provided for @hotkeys.
  ///
  /// In en, this message translates to:
  /// **'Hotkeys'**
  String get hotkeys;

  /// No description provided for @searchHotkey.
  ///
  /// In en, this message translates to:
  /// **'Search hotkey'**
  String get searchHotkey;

  /// No description provided for @checkoutHotkey.
  ///
  /// In en, this message translates to:
  /// **'Checkout hotkey'**
  String get checkoutHotkey;

  /// No description provided for @printerSettings.
  ///
  /// In en, this message translates to:
  /// **'Receipt printer'**
  String get printerSettings;

  /// No description provided for @printerHost.
  ///
  /// In en, this message translates to:
  /// **'Printer host'**
  String get printerHost;

  /// No description provided for @printerPort.
  ///
  /// In en, this message translates to:
  /// **'Printer port'**
  String get printerPort;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Back-office sync'**
  String get syncSettings;

  /// No description provided for @syncEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Sync endpoint'**
  String get syncEndpoint;

  /// No description provided for @syncToken.
  ///
  /// In en, this message translates to:
  /// **'Sync token'**
  String get syncToken;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @usersTitle.
  ///
  /// In en, this message translates to:
  /// **'Users and roles'**
  String get usersTitle;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get editUser;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @mustChangePin.
  ///
  /// In en, this message translates to:
  /// **'Must change PIN'**
  String get mustChangePin;

  /// No description provided for @resetPin.
  ///
  /// In en, this message translates to:
  /// **'Reset PIN'**
  String get resetPin;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get roleCashier;

  /// No description provided for @shiftClose.
  ///
  /// In en, this message translates to:
  /// **'Shift close'**
  String get shiftClose;

  /// No description provided for @closeShift.
  ///
  /// In en, this message translates to:
  /// **'Close shift'**
  String get closeShift;

  /// No description provided for @shiftSummary.
  ///
  /// In en, this message translates to:
  /// **'Shift summary'**
  String get shiftSummary;

  /// No description provided for @invoicesCount.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesCount;

  /// No description provided for @gross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get gross;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @encryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted backup'**
  String get encryptedBackup;

  /// No description provided for @exportPlaintext.
  ///
  /// In en, this message translates to:
  /// **'Export decrypted copy'**
  String get exportPlaintext;

  /// No description provided for @rotateKey.
  ///
  /// In en, this message translates to:
  /// **'Rotate database key'**
  String get rotateKey;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock iPOS'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your account and enter your PIN.'**
  String get loginSubtitle;

  /// No description provided for @selectUser.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get selectUser;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get signIn;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That account and PIN do not match.'**
  String get invalidCredentials;

  /// No description provided for @firstRunHint.
  ///
  /// In en, this message translates to:
  /// **'First launch: administrator PIN 1234. Change it immediately.'**
  String get firstRunHint;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @currentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentPin;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN'**
  String get confirmPin;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The new PINs do not match.'**
  String get pinMismatch;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN updated'**
  String get pinChanged;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get permissionDenied;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print receipt'**
  String get printReceipt;

  /// No description provided for @printingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Configure a receipt printer in Settings.'**
  String get printingUnavailable;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Receipt could not be printed.'**
  String get printFailed;

  /// No description provided for @receiptPrinted.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to printer'**
  String get receiptPrinted;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get syncComplete;

  /// No description provided for @syncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configure the sync endpoint and token first.'**
  String get syncNotConfigured;

  /// No description provided for @shiftClosed.
  ///
  /// In en, this message translates to:
  /// **'Shift closed'**
  String get shiftClosed;

  /// No description provided for @noSalesInShift.
  ///
  /// In en, this message translates to:
  /// **'No sales in this shift.'**
  String get noSalesInShift;

  /// No description provided for @databaseMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Database maintenance'**
  String get databaseMaintenance;

  /// No description provided for @integrityCheck.
  ///
  /// In en, this message translates to:
  /// **'Run integrity check'**
  String get integrityCheck;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup created'**
  String get backupCreated;

  /// No description provided for @plaintextWarning.
  ///
  /// In en, this message translates to:
  /// **'The decrypted copy is unprotected. Store it securely and delete it after use.'**
  String get plaintextWarning;

  /// No description provided for @keyRotationWarning.
  ///
  /// In en, this message translates to:
  /// **'Rotating the key closes the till and requires a restart. A recovery backup is created first.'**
  String get keyRotationWarning;

  /// No description provided for @keyRotated.
  ///
  /// In en, this message translates to:
  /// **'Database key rotated. Restart iPOS.'**
  String get keyRotated;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart iPOS to open the vault with the new key.'**
  String get restartRequired;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Nothing was lost; try again.'**
  String get errorGeneric;

  /// No description provided for @errorDiskFull.
  ///
  /// In en, this message translates to:
  /// **'Storage is full. Free space before continuing.'**
  String get errorDiskFull;

  /// No description provided for @errorVault.
  ///
  /// In en, this message translates to:
  /// **'The encrypted vault is unavailable. Do not clear app data; follow the recovery runbook.'**
  String get errorVault;

  /// No description provided for @errorStorageReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Storage is read-only. Check disk permissions or free the volume.'**
  String get errorStorageReadOnly;

  /// No description provided for @errorStorageBusy.
  ///
  /// In en, this message translates to:
  /// **'The ledger is busy. Wait a moment and retry; the cart is intact.'**
  String get errorStorageBusy;

  /// No description provided for @errorStorageCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The local ledger could not be read. Do not clear app data; export a backup or follow the recovery runbook.'**
  String get errorStorageCorrupt;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @clearRead.
  ///
  /// In en, this message translates to:
  /// **'Clear read'**
  String get clearRead;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @pinInvalid.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4 to 8 digits.'**
  String get pinInvalid;

  /// No description provided for @rolePermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get rolePermissions;

  /// No description provided for @noUsers.
  ///
  /// In en, this message translates to:
  /// **'No users'**
  String get noUsers;

  /// No description provided for @userCreated.
  ///
  /// In en, this message translates to:
  /// **'User created'**
  String get userCreated;

  /// No description provided for @userUpdated.
  ///
  /// In en, this message translates to:
  /// **'User updated'**
  String get userUpdated;

  /// No description provided for @pinResetDone.
  ///
  /// In en, this message translates to:
  /// **'PIN reset. The user must change it at next sign-in.'**
  String get pinResetDone;

  /// No description provided for @lastSignIn.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in'**
  String get lastSignIn;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @confirmResetPin.
  ///
  /// In en, this message translates to:
  /// **'Reset this user PIN?'**
  String get confirmResetPin;

  /// No description provided for @setTemporaryPin.
  ///
  /// In en, this message translates to:
  /// **'Temporary PIN'**
  String get setTemporaryPin;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @passwordPolicy.
  ///
  /// In en, this message translates to:
  /// **'4 to 8 digits'**
  String get passwordPolicy;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @permSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get permSell;

  /// No description provided for @permRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get permRefund;

  /// No description provided for @permInventory.
  ///
  /// In en, this message translates to:
  /// **'Manage inventory'**
  String get permInventory;

  /// No description provided for @permCustomers.
  ///
  /// In en, this message translates to:
  /// **'Manage customers'**
  String get permCustomers;

  /// No description provided for @permSettings.
  ///
  /// In en, this message translates to:
  /// **'Manage settings'**
  String get permSettings;

  /// No description provided for @permUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage users'**
  String get permUsers;

  /// No description provided for @permReports.
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get permReports;

  /// No description provided for @permAudit.
  ///
  /// In en, this message translates to:
  /// **'View audit trail'**
  String get permAudit;

  /// No description provided for @permBackup.
  ///
  /// In en, this message translates to:
  /// **'Manage backups'**
  String get permBackup;

  /// No description provided for @permRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate keys'**
  String get permRotate;

  /// No description provided for @auditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit trail'**
  String get auditTitle;

  /// No description provided for @auditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every recorded action with actor, before, and after values'**
  String get auditSubtitle;

  /// No description provided for @verifyChain.
  ///
  /// In en, this message translates to:
  /// **'Verify chain'**
  String get verifyChain;

  /// No description provided for @chainValid.
  ///
  /// In en, this message translates to:
  /// **'Audit chain valid ({count} events)'**
  String chainValid(int count);

  /// No description provided for @chainInvalid.
  ///
  /// In en, this message translates to:
  /// **'Audit chain broken at {id}'**
  String chainInvalid(String id);

  /// No description provided for @searchAudit.
  ///
  /// In en, this message translates to:
  /// **'Search actor, action, or entity'**
  String get searchAudit;

  /// No description provided for @noAudit.
  ///
  /// In en, this message translates to:
  /// **'No audit events match'**
  String get noAudit;

  /// No description provided for @beforeLabel.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get beforeLabel;

  /// No description provided for @afterLabel.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get afterLabel;

  /// No description provided for @actorLabel.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get actorLabel;

  /// No description provided for @actionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionLabel;

  /// No description provided for @entityLabel.
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get entityLabel;

  /// No description provided for @systemActor.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemActor;

  /// No description provided for @eventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String eventsCount(int count);

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Database maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backups, integrity, shift close, and plaintext export'**
  String get maintenanceSubtitle;

  /// No description provided for @integrityValid.
  ///
  /// In en, this message translates to:
  /// **'Integrity check passed'**
  String get integrityValid;

  /// No description provided for @integrityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Integrity check failed. Restore a verified backup.'**
  String get integrityInvalid;

  /// No description provided for @vacuumDone.
  ///
  /// In en, this message translates to:
  /// **'Storage compacted'**
  String get vacuumDone;

  /// No description provided for @shiftCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close the current shift and run post-shift maintenance?'**
  String get shiftCloseConfirm;

  /// No description provided for @plaintextExportConfirm.
  ///
  /// In en, this message translates to:
  /// **'This writes an unencrypted copy. Continue only if authorized.'**
  String get plaintextExportConfirm;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @productCreated.
  ///
  /// In en, this message translates to:
  /// **'Product created'**
  String get productCreated;

  /// No description provided for @productUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated'**
  String get productUpdated;

  /// No description provided for @stockAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Stock adjusted'**
  String get stockAdjusted;

  /// No description provided for @confirmDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete this product? Historical invoices remain.'**
  String get confirmDeleteProduct;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @uomSaved.
  ///
  /// In en, this message translates to:
  /// **'Selling unit saved'**
  String get uomSaved;

  /// No description provided for @removeUnit.
  ///
  /// In en, this message translates to:
  /// **'Remove unit'**
  String get removeUnit;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number.'**
  String get invalidNumber;

  /// No description provided for @noStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get noStock;

  /// No description provided for @customerCreated.
  ///
  /// In en, this message translates to:
  /// **'Customer created'**
  String get customerCreated;

  /// No description provided for @customerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer updated'**
  String get customerUpdated;

  /// No description provided for @confirmDeleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Delete this customer? Historical invoices remain.'**
  String get confirmDeleteCustomer;

  /// No description provided for @offlineReady.
  ///
  /// In en, this message translates to:
  /// **'Offline-ready'**
  String get offlineReady;

  /// No description provided for @encryptedLocalVault.
  ///
  /// In en, this message translates to:
  /// **'Encrypted local vault'**
  String get encryptedLocalVault;

  /// No description provided for @encryptedVaultActive.
  ///
  /// In en, this message translates to:
  /// **'Encrypted local vault is active'**
  String get encryptedVaultActive;

  /// No description provided for @scaffoldedPending.
  ///
  /// In en, this message translates to:
  /// **'SCAFFOLDED · BACK-OFFICE INTEGRATION PENDING'**
  String get scaffoldedPending;

  /// No description provided for @frontCounter.
  ///
  /// In en, this message translates to:
  /// **'Front Counter'**
  String get frontCounter;

  /// No description provided for @frontCounterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline register · YMM fitment · encrypted local invoices'**
  String get frontCounterSubtitle;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get viewCart;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{name} · {price} added'**
  String addedToCart(String name, String price);

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @searchPartsHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or type SKU, OEM number, or part name…'**
  String get searchPartsHint;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// No description provided for @resultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No parts} =1{1 part} other{{count} parts}}'**
  String resultsCount(int count);

  /// No description provided for @localOnly.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localOnly;

  /// No description provided for @searchShortcut.
  ///
  /// In en, this message translates to:
  /// **'F2 search · Enter adds top match'**
  String get searchShortcut;

  /// No description provided for @catalogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Catalog unavailable'**
  String get catalogUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noMatchingParts.
  ///
  /// In en, this message translates to:
  /// **'No matching parts'**
  String get noMatchingParts;

  /// No description provided for @noMatchingPartsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter SKU/OEM fragment, clear a YMM filter, or confirm the catalog has been ingested for this vehicle.'**
  String get noMatchingPartsHint;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset search and YMM filters'**
  String get resetFilters;

  /// No description provided for @oem.
  ///
  /// In en, this message translates to:
  /// **'OEM'**
  String get oem;

  /// No description provided for @part.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get part;

  /// No description provided for @unitsLines.
  ///
  /// In en, this message translates to:
  /// **'{units} units · {lines} lines'**
  String unitsLines(int units, int lines);

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get clearCart;

  /// No description provided for @closeCheckout.
  ///
  /// In en, this message translates to:
  /// **'Close checkout'**
  String get closeCheckout;

  /// No description provided for @customerAccount.
  ///
  /// In en, this message translates to:
  /// **'Customer account'**
  String get customerAccount;

  /// No description provided for @removeLine.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get removeLine;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @sellingUnit.
  ///
  /// In en, this message translates to:
  /// **'Selling unit'**
  String get sellingUnit;

  /// No description provided for @coreIncluded.
  ///
  /// In en, this message translates to:
  /// **'Includes {amount} refundable core deposit'**
  String coreIncluded(String amount);

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @saleSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to the encrypted local ledger. Invoice lines and stock movements were committed together.'**
  String get saleSaved;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @searchShortcutKey.
  ///
  /// In en, this message translates to:
  /// **'{key} search · Enter adds top match'**
  String searchShortcutKey(String key);

  /// No description provided for @printPreview.
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get printPreview;

  /// No description provided for @paperA4.
  ///
  /// In en, this message translates to:
  /// **'A4 invoice'**
  String get paperA4;

  /// No description provided for @paper80mm.
  ///
  /// In en, this message translates to:
  /// **'80 mm thermal'**
  String get paper80mm;

  /// No description provided for @paper58mm.
  ///
  /// In en, this message translates to:
  /// **'58 mm mini'**
  String get paper58mm;

  /// No description provided for @printNow.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printNow;

  /// No description provided for @printProforma.
  ///
  /// In en, this message translates to:
  /// **'Proforma'**
  String get printProforma;

  /// No description provided for @proformaPrinted.
  ///
  /// In en, this message translates to:
  /// **'Proforma sent to printer'**
  String get proformaPrinted;

  /// No description provided for @proformaPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Proforma could not be printed.'**
  String get proformaPrintFailed;

  /// No description provided for @receiptPaper.
  ///
  /// In en, this message translates to:
  /// **'Receipt paper'**
  String get receiptPaper;

  /// No description provided for @draftRestored.
  ///
  /// In en, this message translates to:
  /// **'Draft restored. Continue where you left off.'**
  String get draftRestored;

  /// No description provided for @emailInvoice.
  ///
  /// In en, this message translates to:
  /// **'Email invoice'**
  String get emailInvoice;

  /// No description provided for @emailProforma.
  ///
  /// In en, this message translates to:
  /// **'Email proforma'**
  String get emailProforma;

  /// No description provided for @emailRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient email'**
  String get emailRecipient;

  /// No description provided for @emailDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get emailDelivery;

  /// No description provided for @emailPdfAttachment.
  ///
  /// In en, this message translates to:
  /// **'PDF attachment'**
  String get emailPdfAttachment;

  /// No description provided for @emailPlainText.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get emailPlainText;

  /// No description provided for @sendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send email'**
  String get sendEmail;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Invoice sent'**
  String get emailSent;

  /// No description provided for @emailSentProforma.
  ///
  /// In en, this message translates to:
  /// **'Proforma sent'**
  String get emailSentProforma;

  /// No description provided for @emailFailed.
  ///
  /// In en, this message translates to:
  /// **'Email could not be sent.'**
  String get emailFailed;

  /// No description provided for @emailNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configure email in Settings first.'**
  String get emailNotConfigured;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @emailSettings.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailSettings;

  /// No description provided for @emailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SMTP relay for invoices and proformas'**
  String get emailSubtitle;

  /// No description provided for @emailHost.
  ///
  /// In en, this message translates to:
  /// **'SMTP host'**
  String get emailHost;

  /// No description provided for @emailPort.
  ///
  /// In en, this message translates to:
  /// **'SMTP port'**
  String get emailPort;

  /// No description provided for @emailUsername.
  ///
  /// In en, this message translates to:
  /// **'SMTP username'**
  String get emailUsername;

  /// No description provided for @emailPassword.
  ///
  /// In en, this message translates to:
  /// **'SMTP password'**
  String get emailPassword;

  /// No description provided for @emailFromAddress.
  ///
  /// In en, this message translates to:
  /// **'From address'**
  String get emailFromAddress;

  /// No description provided for @emailFromName.
  ///
  /// In en, this message translates to:
  /// **'From name'**
  String get emailFromName;

  /// No description provided for @emailUseSsl.
  ///
  /// In en, this message translates to:
  /// **'Use implicit SSL (usually port 465)'**
  String get emailUseSsl;

  /// No description provided for @emailConfigNote.
  ///
  /// In en, this message translates to:
  /// **'Credentials are stored in the encrypted local database.'**
  String get emailConfigNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'rw':
      return AppLocalizationsRw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
