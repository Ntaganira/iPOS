// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kinyarwanda (`rw`).
class AppLocalizationsRw extends AppLocalizations {
  AppLocalizationsRw([String locale = 'rw']) : super(locale);

  @override
  String get appTitle => 'iPOS';

  @override
  String get appTagline => 'Aho kugurira ibice nta murandasi';

  @override
  String get navRegister => 'Ibyo kugurisha';

  @override
  String get navInventory => 'Ububiko';

  @override
  String get navCustomers => 'Abakiriya';

  @override
  String get navSettings => 'Igenamiterere';

  @override
  String get expandSidebar => 'Gutandukura urutonde';

  @override
  String get collapseSidebar => 'Gukunja urutonde';

  @override
  String get switchToLight => 'Guhindura mu buryo bwumurikirwa';

  @override
  String get switchToDark => 'Guhindura mu buryo bwumwijima';

  @override
  String loggedInAs(String name) {
    return 'Winjiye nka $name';
  }

  @override
  String get logout => 'Gusohoka';

  @override
  String get searchHint => 'Shakisha SKU, nimero ya OEM cyangwa ibisobanuro';

  @override
  String get searchHelp => 'Soma kode cyangwa andika nibura inyuguti imwe';

  @override
  String get noParts => 'Nta bice bihuye';

  @override
  String get noPartsHint =>
      'Hindura ibishakishwa cyangwa amodoka, cyangwa wongere igice mu bubiko.';

  @override
  String get loadingCatalog => 'Gutegura urutonde…';

  @override
  String get makeLabel => 'Ubwoko bw’imodoka';

  @override
  String get allMakes => 'Amoko yose';

  @override
  String get modelLabel => 'Icyitegererezo';

  @override
  String get allModels => 'Icyitegererezo cyose';

  @override
  String get yearLabel => 'Umwaka';

  @override
  String get allYears => 'Imyaka yose';

  @override
  String get clearFilters => 'Gukuraho amashakiro';

  @override
  String get checkoutTitle => 'Kwishyura';

  @override
  String get newSale => 'Igurisha rishya';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ibintu $count',
      one: 'ikintu 1',
    );
    return '$_temp0';
  }

  @override
  String get cartEmpty => 'Agatebo karimo ubusa';

  @override
  String get cartHint =>
      'Sikana igice, kanda Enter ku gice kimwe cyihariye, cyangwa kanda umurongo wa kataloge.';

  @override
  String get customerLabel => 'Umukiriya';

  @override
  String get walkInCustomer => 'Umukiriya udafite konti';

  @override
  String get subtotal => 'Igiteranyo';

  @override
  String vatRate(String rate) {
    return 'TVAR $rate';
  }

  @override
  String get coreDeposits => 'Ingwate zisubizwa';

  @override
  String get total => 'IGITERANYO CYOSE';

  @override
  String get paymentMethod => 'UBWISHYU';

  @override
  String get cash => 'Amafaranga';

  @override
  String get card => 'Ikarita';

  @override
  String get mobile => 'Telefone';

  @override
  String get charge => 'Kwishyura';

  @override
  String get offlineCommit =>
      'Kwemeza nta murandasi · fagitire + imirongo + stock bikorwa rimwe';

  @override
  String get saleCompleted => 'Igurisha ryarangiye';

  @override
  String get savedLocal =>
      'Byabitswe mu bubiko bw’ibanze bufunguye. Imirongo, ingendo z’ububiko n’icyemezo cy’igenzura byabitswe icyarimwe.';

  @override
  String get inventoryTitle => 'Urutonde rw’ububiko';

  @override
  String get inventorySubtitle =>
      'Ibyagurishwa, ibiciro, ububiko n’ibice byo kugurisha';

  @override
  String get addProduct => 'Ongeraho igicuruzwa';

  @override
  String get editProduct => 'Hindura igicuruzwa';

  @override
  String get searchInventory => 'Shakisha mu bubiko';

  @override
  String get noProducts => 'Nta bicuruzwa';

  @override
  String stockOnHand(int count) {
    return 'Ubu: $count';
  }

  @override
  String get lowStock => 'Ububiko buke';

  @override
  String get adjustStock => 'Guhindura ububiko';

  @override
  String get stockAdjustment => 'Ihinduka ry’ububiko';

  @override
  String get adjustmentReason => 'Impamvu';

  @override
  String get quantityDelta => 'Ihinduka ry’umubare';

  @override
  String get binLocation => 'Aho kubika';

  @override
  String get sku => 'SKU';

  @override
  String get description => 'Ibisobanuro';

  @override
  String get brand => 'Ikimenyetso';

  @override
  String get retailPrice => 'Igiciro cy’umukiriya';

  @override
  String get tradePrice => 'Igiciro cy’ubucuruzi';

  @override
  String get coreFee => 'Ingwate';

  @override
  String get baseUnit => 'Igice shingiro';

  @override
  String get sellingUnits => 'Ibice byo kugurisha';

  @override
  String get addUnit => 'Ongeraho igice cyo kugurisha';

  @override
  String get unitLabel => 'Izina ry’igice';

  @override
  String get conversionFactor => 'Ibice shingiro ku gice';

  @override
  String get initialStock => 'Ububiko bwa mbere';

  @override
  String get movements => 'Ingendo z’ububiko';

  @override
  String get customersTitle => 'Abakiriya';

  @override
  String get customersSubtitle => 'Konti z’ubucuruzi n’amafaranga asigaye';

  @override
  String get addCustomer => 'Ongeraho umukiriya';

  @override
  String get editCustomer => 'Hindura umukiriya';

  @override
  String get searchCustomers => 'Shakisha abakiriya';

  @override
  String get noCustomers => 'Nta konti z’abakiriya';

  @override
  String get customerName => 'Izina ry’umukiriya';

  @override
  String get phone => 'Telefone';

  @override
  String get taxId => 'Nimero y’imisoro';

  @override
  String get balance => 'Asigaye';

  @override
  String get settingsTitle => 'Igenamiterere';

  @override
  String get settingsSubtitle => 'Icyuma, umutekano, icapa n’itumanaho';

  @override
  String get storeName => 'Izina ry’iduka';

  @override
  String get language => 'Ururimi';

  @override
  String get languageEnglish => 'Icyongereza';

  @override
  String get languageFrench => 'Igifaransa';

  @override
  String get languageKinyarwanda => 'Ikinyarwanda';

  @override
  String get appearance => 'Isura';

  @override
  String get darkMode => 'Uburyo bwumwijima bw’iduka';

  @override
  String get taxRate => 'Igipimo cya TVA (%)';

  @override
  String get scannerSettings => 'Isoma kode';

  @override
  String get scannerMinLength => 'Uburebure buke bwo gusoma';

  @override
  String get scannerTimeout => 'Igihe hagati y’inyuguti (ms)';

  @override
  String get hotkeys => 'Urufunguzo rwihuse';

  @override
  String get searchHotkey => 'Urufunguzo rwo gushakisha';

  @override
  String get checkoutHotkey => 'Urufunguzo rwo kwishyura';

  @override
  String get printerSettings => 'Imashini icapa inyemezabwishyu';

  @override
  String get printerHost => 'Aho imashini iherereye';

  @override
  String get printerPort => 'Umuyoboro w’imashini';

  @override
  String get syncSettings => 'Itumanaho n’ibiro';

  @override
  String get syncEndpoint => 'Aho itumanaho rijya';

  @override
  String get syncToken => 'Urufunguzo rw’itumanaho';

  @override
  String get saveSettings => 'Bika igenamiterere';

  @override
  String get settingsSaved => 'Igenamiterere ryabitswe';

  @override
  String get usersTitle => 'Abakoresha n’inshingano';

  @override
  String get addUser => 'Ongeraho umukoresha';

  @override
  String get editUser => 'Hindura umukoresha';

  @override
  String get roleLabel => 'Inshingano';

  @override
  String get pinLabel => 'PIN';

  @override
  String get active => 'Arakora';

  @override
  String get inactive => 'Ntakora';

  @override
  String get mustChangePin => 'Agomba guhindura PIN';

  @override
  String get resetPin => 'Guhindura PIN';

  @override
  String get roleAdmin => 'Umuyobozi';

  @override
  String get roleManager => 'Umugenzuzi';

  @override
  String get roleCashier => 'Uwishyura';

  @override
  String get shiftClose => 'Gufunga akazi';

  @override
  String get closeShift => 'Funga akazi';

  @override
  String get shiftSummary => 'Incamake y’akazi';

  @override
  String get invoicesCount => 'Fagitire';

  @override
  String get gross => 'Igiteranyo';

  @override
  String get tax => 'Umusoro';

  @override
  String get encryptedBackup => 'Kora kopi ifunze';

  @override
  String get exportPlaintext => 'Sohora kopi ifunguye';

  @override
  String get rotateKey => 'Hindura urufunguzo rw’ububiko';

  @override
  String get loginTitle => 'Fungura iPOS';

  @override
  String get loginSubtitle => 'Hitamo konti yawe wandike PIN.';

  @override
  String get selectUser => 'Konti';

  @override
  String get pin => 'PIN';

  @override
  String get signIn => 'Fungura';

  @override
  String get invalidCredentials => 'Konti na PIN ntibihuye.';

  @override
  String get firstRunHint =>
      'Gutangira: PIN y’umuyobozi ni 1234. Yihindure ako kanya.';

  @override
  String get changePin => 'Hindura PIN';

  @override
  String get currentPin => 'PIN isanzwe';

  @override
  String get newPin => 'PIN nshya';

  @override
  String get confirmPin => 'Emeza PIN nshya';

  @override
  String get pinMismatch => 'PIN nshya ntizihuye.';

  @override
  String get pinChanged => 'PIN yahinduwe';

  @override
  String get permissionDenied => 'Nta uruhushya ufite ku gikorwa nk’iki.';

  @override
  String get save => 'Bika';

  @override
  String get cancel => 'Hagarika';

  @override
  String get delete => 'Siba';

  @override
  String get close => 'Funga';

  @override
  String get confirm => 'Emeza';

  @override
  String get printReceipt => 'Capa inyemezabwishyu';

  @override
  String get printingUnavailable =>
      'Banza ushyireho imashini icapa mu igenamiterere.';

  @override
  String get printFailed => 'Inyemezabwishyu ntiyacapwe.';

  @override
  String get receiptPrinted => 'Inyemezabwishyu yoherejwe ku mashini';

  @override
  String get syncNow => 'Tumanaho ubu';

  @override
  String get syncComplete => 'Itumanaho ryarangiye';

  @override
  String get syncNotConfigured =>
      'Banza ushyireho aho itumanaho rijya n’urufunguzo.';

  @override
  String get shiftClosed => 'Akazi karafunze';

  @override
  String get noSalesInShift => 'Nta gurisha muri aka kazi.';

  @override
  String get databaseMaintenance => 'Isukura ry’ububiko';

  @override
  String get integrityCheck => 'Genzura ubutungane';

  @override
  String get backupCreated => 'Kopi ifunze yarakozwe';

  @override
  String get plaintextWarning =>
      'Kopi ifunguye nta mutekano ifite. Yibike neza kandi uyisibe nyuma yo kuyikoresha.';

  @override
  String get keyRotationWarning =>
      'Guhindura urufunguzo bifunga iduka kandi bisaba kongera gutangiza. Kopi yo gutabara ikorwa mbere.';

  @override
  String get keyRotated => 'Urufunguzo rwahinduwe. Ongera utangize iPOS.';

  @override
  String get restartRequired =>
      'Ongera utangize iPOS kugira ngo ububiko bufunguke n’urufunguzo rushya.';

  @override
  String get loading => 'Gutegura…';

  @override
  String get errorGeneric =>
      'Hari ikibazo. Nta kintu cyatakaye; ongera ugerageze.';

  @override
  String get errorDiskFull => 'Ahantu ho kubika huzuye. Banza urekure umwanya.';

  @override
  String get errorVault =>
      'Ububiko bufunze ntibuboneka. Ntukureho amakuru y’porogaramu; kurikiza uburyo bwo gutabara.';

  @override
  String get errorStorageReadOnly =>
      'Ububiko burahindurwa gusa. Reba uburenganzira bwa disiki cyangwa urekure umwanya.';

  @override
  String get errorStorageBusy =>
      'Ububiko burakora. Tegereza akanya maze ugerageze; ibiri mu kagari ntibyatakaye.';

  @override
  String get errorStorageCorrupt =>
      'Ububiko bwo mu muduga ntibushobora gusomwa. Ntukureho amakuru y’aporogaramu; ohereza kopi y’ububiko cyangwa ukurikize uburyo bwo gutabara.';

  @override
  String get notifications => 'Amakuru';

  @override
  String get noNotifications => 'Nta makuru mashya.';

  @override
  String get markAllRead => 'Menyekanisha byose nk\'ibisomwe';

  @override
  String get clearRead => 'Siba ibisomwe';

  @override
  String unreadCount(int count) {
    return '$count bitarasomwa';
  }

  @override
  String get pinInvalid => 'PIN igomba kuba imibare 4 kugeza kuri 8.';

  @override
  String get rolePermissions => 'Uburenganzira';

  @override
  String get noUsers => 'Nta bakoresha';

  @override
  String get userCreated => 'Umukoresha yashyizweho';

  @override
  String get userUpdated => 'Umukoresha yavuguruwe';

  @override
  String get pinResetDone =>
      'PIN yasubiwemo. Umukoresha agomba kuyihindura bwite.';

  @override
  String get lastSignIn => 'Igihe cyanyuma yinjiye';

  @override
  String get never => 'Nta na rimwe';

  @override
  String get confirmResetPin => 'Gusubiza PIN y\'uyu mukoresha?';

  @override
  String get setTemporaryPin => 'PIN y\'agateganyo';

  @override
  String get status => 'Imiterere';

  @override
  String get permissions => 'Uburenganzira';

  @override
  String get passwordPolicy => 'Imibare 4 kugeza kuri 8';

  @override
  String get deactivate => 'Hagarika';

  @override
  String get activate => 'Kora';

  @override
  String get permSell => 'Gurisha';

  @override
  String get permRefund => 'Subiza';

  @override
  String get permInventory => 'Gucunga ububiko';

  @override
  String get permCustomers => 'Gucunga abakiriya';

  @override
  String get permSettings => 'Gucunga igenamiterere';

  @override
  String get permUsers => 'Gucunga abakoresha';

  @override
  String get permReports => 'Reba raporo';

  @override
  String get permAudit => 'Reba ubugenzuzi';

  @override
  String get permBackup => 'Gucunga ibitswe mu bubiko';

  @override
  String get permRotate => 'Hindura urufunguzo';

  @override
  String get auditTitle => 'Inzira y\'ubugenzuzi';

  @override
  String get auditSubtitle =>
      'Buri gikorwa cyanditswe n\'uwagikoze, mbere na nyuma';

  @override
  String get verifyChain => 'Genzura urunigi';

  @override
  String chainValid(int count) {
    return 'Urunigi rw\'ubugenzuzi rufite agaciro ($count ibyakozwe)';
  }

  @override
  String chainInvalid(String id) {
    return 'Urunigi rw\'ubugenzuzi rwacitse kuri $id';
  }

  @override
  String get searchAudit => 'Shakisha uwakoze, igikorwa cyangwa ikintu';

  @override
  String get noAudit => 'Nta byakozwe by\'ubugenzuzi bihuye';

  @override
  String get beforeLabel => 'Mbere';

  @override
  String get afterLabel => 'Nyuma';

  @override
  String get actorLabel => 'Uwakoze';

  @override
  String get actionLabel => 'Igikorwa';

  @override
  String get entityLabel => 'Ikintu';

  @override
  String get systemActor => 'Sisitemu';

  @override
  String eventsCount(int count) {
    return '$count ibyakozwe';
  }

  @override
  String get maintenanceTitle => 'Gucunga ububiko';

  @override
  String get maintenanceSubtitle =>
      'Ibitswe, ubugororangingo, gusoza shift no kohereza mu buryo butafunze';

  @override
  String get integrityValid => 'Igenzura ry\'ubugororangingo ryagenze neza';

  @override
  String get integrityInvalid =>
      'Igenzura ry\'ubugororangingo ryanze. Subiza ububiko bwemejwe.';

  @override
  String get vacuumDone => 'Ububiko bwagabanyijwe';

  @override
  String get shiftCloseConfirm =>
      'Gusoza shift ikora no gukora gucunga ububiko?';

  @override
  String get plaintextExportConfirm =>
      'Ibi byandika kopi itafunze. Komeza gusa niba wemerewe.';

  @override
  String get refresh => 'Rekomerezaho';

  @override
  String get search => 'Shakisha';

  @override
  String get productCreated => 'Igicuruzwa cyashyizweho';

  @override
  String get productUpdated => 'Igicuruzwa cyavuguruwe';

  @override
  String get stockAdjusted => 'Ububiko bwahinduwe';

  @override
  String get confirmDeleteProduct =>
      'Gusiba iki gicuruzwa? Fagitire za kera zizaguma.';

  @override
  String get deleted => 'Byasibwe';

  @override
  String get uomSaved => 'Igipimo cyo kugurisha cyabitswe';

  @override
  String get removeUnit => 'Kuraho igipimo';

  @override
  String get unit => 'Igipimo';

  @override
  String get price => 'Igiciro';

  @override
  String get invalidNumber => 'Andika umubare wemewe.';

  @override
  String get noStock => 'Nta bubiko';

  @override
  String get customerCreated => 'Umukiriya yashyizweho';

  @override
  String get customerUpdated => 'Umukiriya yavuguruwe';

  @override
  String get confirmDeleteCustomer =>
      'Gusiba uyu mukiriya? Fagitire za kera zizaguma.';

  @override
  String get offlineReady => 'Yiteguye nta murandasi';

  @override
  String get encryptedLocalVault =>
      'Ububiko bwo mu mudasobwa bwashyizwe mu ibanga';

  @override
  String get encryptedVaultActive =>
      'Ububiko bw\'ibanze bwashyizwe mu ibanga burakora';

  @override
  String get scaffoldedPending => 'URWUBATSO · GUHURIZA NA BIRO BIRATEGEREJE';

  @override
  String get frontCounter => 'Ibiro byo kwakira abakiriya';

  @override
  String get frontCounterSubtitle =>
      'Ibyo kwakira abakiriya nta murandasi · YMM · fagitire z\'ibanze';

  @override
  String get cart => 'Agatebo';

  @override
  String get viewCart => 'Reba agatebo';

  @override
  String addedToCart(String name, String price) {
    return '$name · $price yongewe';
  }

  @override
  String get clearSearch => 'Siba ibishakishwa';

  @override
  String get searchPartsHint =>
      'Sikana cyangwa wandike SKU, nimero ya OEM, cyangwa izina ry\'igice…';

  @override
  String get searching => 'Bishakishwa…';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ibice $count',
      one: 'Igice 1',
      zero: 'Nta gice',
    );
    return '$_temp0';
  }

  @override
  String get localOnly => 'Aha';

  @override
  String get searchShortcut => 'F2 shakisha · Enter yongeraho ihuye mbere';

  @override
  String get catalogUnavailable => 'Kataloge ntiboneka';

  @override
  String get retry => 'Gerageza';

  @override
  String get noMatchingParts => 'Nta gice gihuye';

  @override
  String get noMatchingPartsHint =>
      'Gerageza igice gito cya SKU/OEM, siba filtre ya YMM, cyangwa wemeze ko kataloge yinjiwe kuri iyi modoka.';

  @override
  String get resetFilters => 'Subiza ibishakishwa na filtre za YMM';

  @override
  String get oem => 'OEM';

  @override
  String get part => 'Igice';

  @override
  String unitsLines(int units, int lines) {
    return 'Ibitengo $units · imirongo $lines';
  }

  @override
  String get clearCart => 'Siba agatebo';

  @override
  String get closeCheckout => 'Funga kwishyura';

  @override
  String get customerAccount => 'Konti y\'umukiriya';

  @override
  String get removeLine => 'Kuraho umurongo';

  @override
  String get decreaseQuantity => 'Gabanya ingano';

  @override
  String get increaseQuantity => 'Ongera ingano';

  @override
  String get sellingUnit => 'Igipimo cyo kugurisha';

  @override
  String coreIncluded(String amount) {
    return 'Harimo $amount y\'ingwate isubizwa';
  }

  @override
  String get payment => 'Kwishyura';

  @override
  String get saleSaved =>
      'Byabitswe mu bubiko bw\'ibanze. Imirongo ya fagitire n\'iminyururu y\'ububiko byemejwe hamwe.';

  @override
  String get addToCart => 'Ongera mu gatebo';

  @override
  String searchShortcutKey(String key) {
    return '$key shakisha · Enter yongeraho ihuye mbere';
  }

  @override
  String get printPreview => 'Reba mbere yo gucapa';

  @override
  String get paperA4 => 'Faktura A4';

  @override
  String get paper80mm => 'Icyuma 80 mm';

  @override
  String get paper58mm => 'Nto 58 mm';

  @override
  String get printNow => 'Capa';

  @override
  String get printProforma => 'Proforma';

  @override
  String get proformaPrinted => 'Proforma yoherejwe mu icapiro';

  @override
  String get proformaPrintFailed => 'Proforma ntiyashoboye gucapwa.';

  @override
  String get receiptPaper => 'Impapuro y’inyemezabwishyu';

  @override
  String get draftRestored => 'Umushinga wagarutswe. Komeza aho wari ugeze.';

  @override
  String get emailInvoice => 'Ohereza faktura';

  @override
  String get emailProforma => 'Ohereza proforma';

  @override
  String get emailRecipient => 'Imeyili y’uwakira';

  @override
  String get emailDelivery => 'Uburyo bwo kohereza';

  @override
  String get emailPdfAttachment => 'Umugereka PDF';

  @override
  String get emailPlainText => 'Inyandiko gusa';

  @override
  String get sendEmail => 'Ohereza imeyili';

  @override
  String get emailSent => 'Faktura yoherejwe';

  @override
  String get emailSentProforma => 'Proforma yoherejwe';

  @override
  String get emailFailed => 'Imeyili ntiyashoboye koherezwa.';

  @override
  String get emailNotConfigured => 'Banza ushyireho imeyili mu igenamiterere.';

  @override
  String get emailInvalid => 'Andika aderesi y’imeyili yemewe.';

  @override
  String get emailSettings => 'Imeyili';

  @override
  String get emailSubtitle => 'SMTP yo kohereza fakitura na proforma';

  @override
  String get emailHost => 'SMTP host';

  @override
  String get emailPort => 'SMTP port';

  @override
  String get emailUsername => 'Izina ry’ukoresha SMTP';

  @override
  String get emailPassword => 'Ijambo ry’ibanga SMTP';

  @override
  String get emailFromAddress => 'Aderesi itumira';

  @override
  String get emailFromName => 'Izina ritumira';

  @override
  String get emailUseSsl => 'Koresha SSL (akenshi port 465)';

  @override
  String get emailConfigNote =>
      'Urufunguzo n’ijambo ry’ibanga bibikwa mu bubiko bw’ibanze bwashifuriwe.';
}
