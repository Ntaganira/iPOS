// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'iPOS';

  @override
  String get appTagline => 'Comptoir de pièces hors ligne';

  @override
  String get navRegister => 'Caisse';

  @override
  String get navInventory => 'Inventaire';

  @override
  String get navCustomers => 'Clients';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get expandSidebar => 'Développer la navigation';

  @override
  String get collapseSidebar => 'Réduire la navigation';

  @override
  String get switchToLight => 'Passer en mode clair';

  @override
  String get switchToDark => 'Passer en mode sombre';

  @override
  String loggedInAs(String name) {
    return 'Connecté en tant que $name';
  }

  @override
  String get logout => 'Se déconnecter';

  @override
  String get searchHint =>
      'Rechercher un SKU, un numéro OEM ou une description';

  @override
  String get searchHelp =>
      'Scannez une pièce ou saisissez au moins un caractère';

  @override
  String get noParts => 'Aucune pièce correspondante';

  @override
  String get noPartsHint =>
      'Modifiez la recherche ou les filtres véhicule, ou ajoutez la pièce dans l’inventaire.';

  @override
  String get loadingCatalog => 'Chargement du catalogue…';

  @override
  String get makeLabel => 'Marque';

  @override
  String get allMakes => 'Toutes les marques';

  @override
  String get modelLabel => 'Modèle';

  @override
  String get allModels => 'Tous les modèles';

  @override
  String get yearLabel => 'Année';

  @override
  String get allYears => 'Toutes les années';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get checkoutTitle => 'Encaissement';

  @override
  String get newSale => 'Nouvelle vente';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: 'Aucun article',
    );
    return '$_temp0';
  }

  @override
  String get cartEmpty => 'Le panier est vide';

  @override
  String get cartHint =>
      'Scannez une pièce, appuyez sur Entrée pour une correspondance unique ou touchez une ligne du catalogue.';

  @override
  String get customerLabel => 'Client';

  @override
  String get walkInCustomer => 'Client de passage';

  @override
  String get subtotal => 'Sous-total';

  @override
  String vatRate(String rate) {
    return 'TVA $rate';
  }

  @override
  String get coreDeposits => 'Consignes (remboursables)';

  @override
  String get total => 'TOTAL';

  @override
  String get paymentMethod => 'PAIEMENT';

  @override
  String get cash => 'Espèces';

  @override
  String get card => 'Carte';

  @override
  String get mobile => 'Mobile';

  @override
  String get charge => 'Encaisser';

  @override
  String get offlineCommit =>
      'Validation hors ligne · facture + lignes + stock atomiques';

  @override
  String get saleCompleted => 'Vente terminée';

  @override
  String get savedLocal =>
      'Enregistrée dans le registre local chiffré. Les lignes, les mouvements de stock et l’événement d’audit sont validés ensemble.';

  @override
  String get inventoryTitle => 'Registre d’inventaire';

  @override
  String get inventorySubtitle => 'Produits, prix, stock et unités de vente';

  @override
  String get addProduct => 'Ajouter un produit';

  @override
  String get editProduct => 'Modifier le produit';

  @override
  String get searchInventory => 'Rechercher dans l’inventaire';

  @override
  String get noProducts => 'Aucun produit';

  @override
  String stockOnHand(int count) {
    return 'En stock : $count';
  }

  @override
  String get lowStock => 'Stock faible';

  @override
  String get adjustStock => 'Ajuster le stock';

  @override
  String get stockAdjustment => 'Ajustement de stock';

  @override
  String get adjustmentReason => 'Motif';

  @override
  String get quantityDelta => 'Variation de quantité';

  @override
  String get binLocation => 'Emplacement';

  @override
  String get sku => 'SKU';

  @override
  String get description => 'Description';

  @override
  String get brand => 'Marque';

  @override
  String get retailPrice => 'Prix de détail';

  @override
  String get tradePrice => 'Prix professionnel';

  @override
  String get coreFee => 'Consigne';

  @override
  String get baseUnit => 'Unité de base';

  @override
  String get sellingUnits => 'Unités de vente';

  @override
  String get addUnit => 'Ajouter une unité de vente';

  @override
  String get unitLabel => 'Libellé de l’unité';

  @override
  String get conversionFactor => 'Unités de base par unité';

  @override
  String get initialStock => 'Stock initial';

  @override
  String get movements => 'Mouvements de stock';

  @override
  String get customersTitle => 'Clients';

  @override
  String get customersSubtitle => 'Comptes professionnels et soldes en cache';

  @override
  String get addCustomer => 'Ajouter un client';

  @override
  String get editCustomer => 'Modifier le client';

  @override
  String get searchCustomers => 'Rechercher des clients';

  @override
  String get noCustomers => 'Aucun compte client';

  @override
  String get customerName => 'Nom du client';

  @override
  String get phone => 'Téléphone';

  @override
  String get taxId => 'Numéro fiscal';

  @override
  String get balance => 'Solde';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSubtitle =>
      'Terminal, sécurité, impression et synchronisation';

  @override
  String get storeName => 'Nom du magasin';

  @override
  String get language => 'Langue';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String get appearance => 'Apparence';

  @override
  String get darkMode => 'Mode caisse sombre';

  @override
  String get taxRate => 'Taux de TVA (%)';

  @override
  String get scannerSettings => 'Lecteur de codes-barres';

  @override
  String get scannerMinLength => 'Longueur minimale du scan';

  @override
  String get scannerTimeout => 'Délai entre touches (ms)';

  @override
  String get hotkeys => 'Raccourcis';

  @override
  String get searchHotkey => 'Raccourci de recherche';

  @override
  String get checkoutHotkey => 'Raccourci d’encaissement';

  @override
  String get printerSettings => 'Imprimante de reçus';

  @override
  String get printerHost => 'Hôte de l’imprimante';

  @override
  String get printerPort => 'Port de l’imprimante';

  @override
  String get syncSettings => 'Synchronisation arrière-guichet';

  @override
  String get syncEndpoint => 'Point de synchronisation';

  @override
  String get syncToken => 'Jeton de synchronisation';

  @override
  String get saveSettings => 'Enregistrer les paramètres';

  @override
  String get settingsSaved => 'Paramètres enregistrés';

  @override
  String get usersTitle => 'Utilisateurs et rôles';

  @override
  String get addUser => 'Ajouter un utilisateur';

  @override
  String get editUser => 'Modifier l’utilisateur';

  @override
  String get roleLabel => 'Rôle';

  @override
  String get pinLabel => 'PIN';

  @override
  String get active => 'Actif';

  @override
  String get inactive => 'Inactif';

  @override
  String get mustChangePin => 'Doit changer le PIN';

  @override
  String get resetPin => 'Réinitialiser le PIN';

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get roleManager => 'Gestionnaire';

  @override
  String get roleCashier => 'Caissier';

  @override
  String get shiftClose => 'Clôture de poste';

  @override
  String get closeShift => 'Clôturer le poste';

  @override
  String get shiftSummary => 'Résumé du poste';

  @override
  String get invoicesCount => 'Factures';

  @override
  String get gross => 'Brut';

  @override
  String get tax => 'TVA';

  @override
  String get encryptedBackup => 'Créer une sauvegarde chiffrée';

  @override
  String get exportPlaintext => 'Exporter une copie déchiffrée';

  @override
  String get rotateKey => 'Renouveler la clé de la base';

  @override
  String get loginTitle => 'Déverrouiller iPOS';

  @override
  String get loginSubtitle =>
      'Sélectionnez votre compte et saisissez votre PIN.';

  @override
  String get selectUser => 'Compte';

  @override
  String get pin => 'PIN';

  @override
  String get signIn => 'Déverrouiller';

  @override
  String get invalidCredentials => 'Ce compte et ce PIN ne correspondent pas.';

  @override
  String get firstRunHint =>
      'Premier lancement : PIN administrateur 1234. Changez-le immédiatement.';

  @override
  String get changePin => 'Changer le PIN';

  @override
  String get currentPin => 'PIN actuel';

  @override
  String get newPin => 'Nouveau PIN';

  @override
  String get confirmPin => 'Confirmer le nouveau PIN';

  @override
  String get pinMismatch => 'Les nouveaux PIN ne correspondent pas.';

  @override
  String get pinChanged => 'PIN mis à jour';

  @override
  String get permissionDenied =>
      'Vous n’avez pas l’autorisation pour cette action.';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get close => 'Fermer';

  @override
  String get confirm => 'Confirmer';

  @override
  String get printReceipt => 'Imprimer le reçu';

  @override
  String get printingUnavailable =>
      'Configurez une imprimante de reçus dans les paramètres.';

  @override
  String get printFailed => 'Le reçu n’a pas pu être imprimé.';

  @override
  String get receiptPrinted => 'Reçu envoyé à l’imprimante';

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get syncComplete => 'Synchronisation terminée';

  @override
  String get syncNotConfigured =>
      'Configurez d’abord le point de synchronisation et le jeton.';

  @override
  String get shiftClosed => 'Poste clôturé';

  @override
  String get noSalesInShift => 'Aucune vente pendant ce poste.';

  @override
  String get databaseMaintenance => 'Maintenance de la base';

  @override
  String get integrityCheck => 'Vérifier l’intégrité';

  @override
  String get backupCreated => 'Sauvegarde chiffrée créée';

  @override
  String get plaintextWarning =>
      'La copie déchiffrée n’est pas protégée. Conservez-la en lieu sûr et supprimez-la après usage.';

  @override
  String get keyRotationWarning =>
      'Le renouvellement de clé ferme la caisse et nécessite un redémarrage. Une sauvegarde de secours est créée d’abord.';

  @override
  String get keyRotated => 'Clé de la base renouvelée. Redémarrez iPOS.';

  @override
  String get restartRequired =>
      'Redémarrez iPOS pour ouvrir le coffre avec la nouvelle clé.';

  @override
  String get loading => 'Chargement…';

  @override
  String get errorGeneric =>
      'Une erreur est survenue. Rien n’a été perdu ; réessayez.';

  @override
  String get errorDiskFull =>
      'Le stockage est plein. Libérez de l’espace avant de continuer.';

  @override
  String get errorVault =>
      'Le coffre chiffré est indisponible. N’effacez pas les données de l’application ; suivez la procédure de récupération.';

  @override
  String get errorStorageReadOnly =>
      'Le stockage est en lecture seule. Vérifiez les permissions du disque ou libérez de l’espace.';

  @override
  String get errorStorageBusy =>
      'Le registre est occupé. Patientez un instant et réessayez ; le panier est intact.';

  @override
  String get errorStorageCorrupt =>
      'Le registre local est illisible. N’effacez pas les données de l’application ; exportez une sauvegarde ou suivez la procédure de récupération.';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'Vous êtes à jour.';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get clearRead => 'Effacer les lues';

  @override
  String unreadCount(int count) {
    return '$count non lues';
  }

  @override
  String get pinInvalid => 'Le PIN doit comporter 4 à 8 chiffres.';

  @override
  String get rolePermissions => 'Autorisations';

  @override
  String get noUsers => 'Aucun utilisateur';

  @override
  String get userCreated => 'Utilisateur créé';

  @override
  String get userUpdated => 'Utilisateur mis à jour';

  @override
  String get pinResetDone =>
      'PIN réinitialisé. L\'utilisateur devra le changer à la prochaine connexion.';

  @override
  String get lastSignIn => 'Dernière connexion';

  @override
  String get never => 'Jamais';

  @override
  String get confirmResetPin => 'Réinitialiser le PIN de cet utilisateur ?';

  @override
  String get setTemporaryPin => 'PIN temporaire';

  @override
  String get status => 'Statut';

  @override
  String get permissions => 'Autorisations';

  @override
  String get passwordPolicy => '4 à 8 chiffres';

  @override
  String get deactivate => 'Désactiver';

  @override
  String get activate => 'Activer';

  @override
  String get permSell => 'Vendre';

  @override
  String get permRefund => 'Rembourser';

  @override
  String get permInventory => 'Gérer le stock';

  @override
  String get permCustomers => 'Gérer les clients';

  @override
  String get permSettings => 'Gérer les paramètres';

  @override
  String get permUsers => 'Gérer les utilisateurs';

  @override
  String get permReports => 'Voir les rapports';

  @override
  String get permAudit => 'Voir l\'audit';

  @override
  String get permBackup => 'Gérer les sauvegardes';

  @override
  String get permRotate => 'Renouveler les clés';

  @override
  String get auditTitle => 'Piste d\'audit';

  @override
  String get auditSubtitle =>
      'Chaque action enregistrée avec acteur, avant et après';

  @override
  String get verifyChain => 'Vérifier la chaîne';

  @override
  String chainValid(int count) {
    return 'Chaîne d\'audit valide ($count événements)';
  }

  @override
  String chainInvalid(String id) {
    return 'Chaîne d\'audit rompue à $id';
  }

  @override
  String get searchAudit => 'Rechercher acteur, action ou entité';

  @override
  String get noAudit => 'Aucun événement d\'audit';

  @override
  String get beforeLabel => 'Avant';

  @override
  String get afterLabel => 'Après';

  @override
  String get actorLabel => 'Acteur';

  @override
  String get actionLabel => 'Action';

  @override
  String get entityLabel => 'Entité';

  @override
  String get systemActor => 'Système';

  @override
  String eventsCount(int count) {
    return '$count événements';
  }

  @override
  String get maintenanceTitle => 'Maintenance de la base';

  @override
  String get maintenanceSubtitle =>
      'Sauvegardes, intégrité, clôture de shift et export en clair';

  @override
  String get integrityValid => 'Contrôle d\'intégrité réussi';

  @override
  String get integrityInvalid =>
      'Contrôle d\'intégrité échoué. Restaurez une sauvegarde vérifiée.';

  @override
  String get vacuumDone => 'Stockage compacté';

  @override
  String get shiftCloseConfirm =>
      'Clôturer le shift en cours et lancer la maintenance ?';

  @override
  String get plaintextExportConfirm =>
      'Ceci écrit une copie non chiffrée. Continuez uniquement si autorisé.';

  @override
  String get refresh => 'Actualiser';

  @override
  String get search => 'Rechercher';

  @override
  String get productCreated => 'Produit créé';

  @override
  String get productUpdated => 'Produit mis à jour';

  @override
  String get stockAdjusted => 'Stock ajusté';

  @override
  String get confirmDeleteProduct =>
      'Supprimer ce produit ? Les factures historiques restent.';

  @override
  String get deleted => 'Supprimé';

  @override
  String get uomSaved => 'Unité de vente enregistrée';

  @override
  String get removeUnit => 'Retirer l\'unité';

  @override
  String get unit => 'Unité';

  @override
  String get price => 'Prix';

  @override
  String get invalidNumber => 'Saisissez un nombre valide.';

  @override
  String get noStock => 'Rupture de stock';

  @override
  String get customerCreated => 'Client créé';

  @override
  String get customerUpdated => 'Client mis à jour';

  @override
  String get confirmDeleteCustomer =>
      'Supprimer ce client ? Les factures historiques restent.';

  @override
  String get offlineReady => 'Prêt hors ligne';

  @override
  String get encryptedLocalVault => 'Coffre local chiffré';

  @override
  String get encryptedVaultActive => 'Le coffre local chiffré est actif';

  @override
  String get scaffoldedPending =>
      'ÉBAUCHÉ · INTÉGRATION BACK-OFFICE EN ATTENTE';

  @override
  String get frontCounter => 'Comptoir';

  @override
  String get frontCounterSubtitle =>
      'Caisse hors ligne · filtres YMM · factures locales chiffrées';

  @override
  String get cart => 'Panier';

  @override
  String get viewCart => 'Voir le panier';

  @override
  String addedToCart(String name, String price) {
    return '$name · $price ajouté';
  }

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get searchPartsHint =>
      'Scannez ou saisissez un SKU, un numéro OEM ou un nom de pièce…';

  @override
  String get searching => 'Recherche…';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces',
      one: '1 pièce',
      zero: 'Aucune pièce',
    );
    return '$_temp0';
  }

  @override
  String get localOnly => 'Local';

  @override
  String get searchShortcut =>
      'F2 rechercher · Entrée ajoute la meilleure correspondance';

  @override
  String get catalogUnavailable => 'Catalogue indisponible';

  @override
  String get retry => 'Réessayer';

  @override
  String get noMatchingParts => 'Aucune pièce correspondante';

  @override
  String get noMatchingPartsHint =>
      'Essayez un fragment SKU/OEM plus court, effacez un filtre YMM ou confirmez que le catalogue a été importé pour ce véhicule.';

  @override
  String get resetFilters => 'Réinitialiser la recherche et les filtres YMM';

  @override
  String get oem => 'OEM';

  @override
  String get part => 'Pièce';

  @override
  String unitsLines(int units, int lines) {
    return '$units unités · $lines lignes';
  }

  @override
  String get clearCart => 'Vider le panier';

  @override
  String get closeCheckout => 'Fermer la caisse';

  @override
  String get customerAccount => 'Compte client';

  @override
  String get removeLine => 'Retirer la ligne';

  @override
  String get decreaseQuantity => 'Diminuer la quantité';

  @override
  String get increaseQuantity => 'Augmenter la quantité';

  @override
  String get sellingUnit => 'Unité de vente';

  @override
  String coreIncluded(String amount) {
    return 'Comprend $amount de consigne remboursable';
  }

  @override
  String get payment => 'Paiement';

  @override
  String get saleSaved =>
      'Enregistré dans le registre local chiffré. Les lignes de facture et les mouvements de stock ont été validés ensemble.';

  @override
  String get addToCart => 'Ajouter au panier';

  @override
  String searchShortcutKey(String key) {
    return '$key rechercher · Entrée ajoute la meilleure correspondance';
  }

  @override
  String get printPreview => 'Aperçu avant impression';

  @override
  String get paperA4 => 'Facture A4';

  @override
  String get paper80mm => 'Thermique 80 mm';

  @override
  String get paper58mm => 'Mini 58 mm';

  @override
  String get printNow => 'Imprimer';

  @override
  String get printProforma => 'Proforma';

  @override
  String get proformaPrinted => 'Proforma envoyée à l’imprimante';

  @override
  String get proformaPrintFailed => 'La proforma n’a pas pu être imprimée.';

  @override
  String get receiptPaper => 'Papier du reçu';

  @override
  String get draftRestored => 'Brouillon restauré. Reprenez où vous en étiez.';

  @override
  String get emailInvoice => 'Envoyer la facture';

  @override
  String get emailProforma => 'Envoyer la proforma';

  @override
  String get emailRecipient => 'E-mail du destinataire';

  @override
  String get emailDelivery => 'Livraison';

  @override
  String get emailPdfAttachment => 'Pièce jointe PDF';

  @override
  String get emailPlainText => 'Texte seul';

  @override
  String get sendEmail => 'Envoyer';

  @override
  String get emailSent => 'Facture envoyée';

  @override
  String get emailSentProforma => 'Proforma envoyée';

  @override
  String get emailFailed => 'L’e-mail n’a pas pu être envoyé.';

  @override
  String get emailNotConfigured =>
      'Configurez d’abord l’e-mail dans les paramètres.';

  @override
  String get emailInvalid => 'Saisissez une adresse e-mail valide.';

  @override
  String get emailSettings => 'E-mail';

  @override
  String get emailSubtitle => 'Relais SMTP pour factures et proformas';

  @override
  String get emailHost => 'Hôte SMTP';

  @override
  String get emailPort => 'Port SMTP';

  @override
  String get emailUsername => 'Utilisateur SMTP';

  @override
  String get emailPassword => 'Mot de passe SMTP';

  @override
  String get emailFromAddress => 'Adresse d’expédition';

  @override
  String get emailFromName => 'Nom d’expédition';

  @override
  String get emailUseSsl => 'Utiliser SSL implicite (souvent le port 465)';

  @override
  String get emailConfigNote =>
      'Les identifiants sont stockés dans la base locale chiffrée.';
}
