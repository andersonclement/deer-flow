import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langue de l'interface (français par défaut, anglais pour les régions
/// anglophones).
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('fr');

  void set(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

final stringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(ref.watch(localeProvider).languageCode == 'en'),
);

/// Textes de l'application en français et en anglais.
class AppStrings {
  const AppStrings(this.en);

  final bool en;

  String _t(String fr, String english) => en ? english : fr;

  // Commun
  String get back => _t('Retour', 'Back');
  String stepOf(int step, int total) => _t('Étape $step sur $total', 'Step $step of $total');
  String get genericError => _t('Une erreur est survenue. Réessayez.', 'Something went wrong. Please try again.');

  // Étape 1 : téléphone
  String get welcomeTitle => _t('Gérez votre commerce depuis votre téléphone', 'Run your business from your phone');
  String get welcomeSubtitle => _t(
        'Ventes, factures, créances et paiements MTN MoMo ou Orange Money, au même endroit. Gratuit pour commencer.',
        'Sales, invoices, debts and MTN MoMo or Orange Money payments, all in one place. Free to start.',
      );
  String get phoneLabel => _t('Votre numéro de téléphone', 'Your phone number');
  String get phoneHint => _t('On vous envoie un code pour vérifier ce numéro.', 'We send you a code to verify this number.');
  String get phoneInvalid => _t('Entrez un numéro mobile camerounais (9 chiffres, commence par 6).', 'Enter a Cameroon mobile number (9 digits, starting with 6).');
  String get phoneTaken => _t('Ce numéro a déjà un compte. Connectez-vous.', 'This number already has an account. Please log in.');
  String get getCode => _t('Recevoir le code', 'Get the code');
  String get hasAccount => _t('Déjà un compte ?', 'Already have an account?');
  String get login => _t('Se connecter', 'Log in');
  String get terms => _t(
        'En continuant, vous acceptez les conditions d’utilisation et la politique de confidentialité.',
        'By continuing, you accept the terms of use and the privacy policy.',
      );

  // Étape 2 : code
  String get otpTitle => _t('Entrez le code reçu', 'Enter the code');
  String otpSentTo(String maskedPhone) => _t('Code envoyé par SMS au $maskedPhone.', 'Code sent by SMS to $maskedPhone.');
  String get otpLabel => _t('Code à 6 chiffres', '6-digit code');
  String get otpInvalid => _t('Code incorrect. Vérifiez le SMS.', 'Wrong code. Check the SMS.');
  String resendIn(int seconds) => _t('Renvoyer dans 0:${seconds.toString().padLeft(2, '0')}', 'Resend in 0:${seconds.toString().padLeft(2, '0')}');
  String get resend => _t('Renvoyer le code', 'Resend code');
  String get verify => _t('Vérifier', 'Verify');

  // Étape 3 : mot de passe
  String get passwordTitle => _t('Créez votre mot de passe', 'Create your password');
  String get passwordSubtitle => _t('Vous l’utiliserez avec votre numéro pour vous connecter.', 'You’ll use it with your number to log in.');
  String get password => _t('Mot de passe', 'Password');
  String get confirmPassword => _t('Confirmer le mot de passe', 'Confirm password');
  String get showPassword => _t('Afficher le mot de passe', 'Show password');
  String get hidePassword => _t('Masquer le mot de passe', 'Hide password');
  String get ruleLength => _t('Au moins 8 caractères', 'At least 8 characters');
  String get ruleDigit => _t('Au moins un chiffre', 'At least one number');
  String get ruleUpper => _t('Une majuscule', 'One capital letter');
  String get passwordsDiffer => _t('Les deux mots de passe ne sont pas identiques.', 'The passwords do not match.');
  String get continueLabel => _t('Continuer', 'Continue');

  // Étape 4 : commerce
  String get businessTitle => _t('Votre commerce', 'Your business');
  String get businessSubtitle => _t('Ces infos apparaîtront sur vos factures.', 'This will appear on your invoices.');
  String get businessName => _t('Nom du commerce', 'Business name');
  String get businessNameRequired => _t('Indiquez le nom de votre commerce.', 'Enter your business name.');
  String get activity => _t('Activité', 'Activity');
  String get city => _t('Ville', 'City');
  String get niu => _t('NIU (optionnel)', 'NIU / tax ID (optional)');
  String get niuHint => _t('À ajouter plus tard si besoin', 'Add it later if needed');
  String get start => _t('Commencer', 'Get started');

  // Connexion
  String get loginTitle => _t('Bon retour', 'Welcome back');
  String get loginSubtitle => _t('Connectez-vous avec votre numéro et votre mot de passe.', 'Log in with your number and password.');
  String get forgotPassword => _t('Mot de passe oublié ?', 'Forgot password?');
  String get badCredentials => _t('Numéro ou mot de passe incorrect.', 'Wrong number or password.');
  String get noAccount => _t('Pas encore de compte ?', 'No account yet?');
  String get signup => _t('S’inscrire', 'Sign up');

  // Accueil
  String get hello => _t('Bonjour', 'Hello');
  String get todayCash => _t('Caisse du jour', 'Today’s cash');
  String get sales => _t('Ventes', 'Sales');
  String get expenses => _t('Dépenses', 'Expenses');
  String get owedToYou => _t('On vous doit', 'Owed to you');
  String get noSalesYet => _t('Aucune vente aujourd’hui. Appuyez sur le micro pour dicter votre première vente.', 'No sales today. Tap the mic to dictate your first sale.');
  String get logout => _t('Se déconnecter', 'Log out');

  /// Traduit un code d'erreur des contrôleurs d'authentification.
  String authError(String code) => switch (code) {
        'invalid_phone' => phoneInvalid,
        'phone_taken' => phoneTaken,
        'invalid_otp' => otpInvalid,
        'weak_password' => _t('Le mot de passe ne respecte pas les règles.', 'The password does not meet the rules.'),
        'passwords_differ' => passwordsDiffer,
        'missing_name' => businessNameRequired,
        'bad_credentials' => badCredentials,
        _ => genericError,
      };

  String activityLabel(String key) => switch (key) {
        'food' => _t('Alimentation', 'Grocery'),
        'hardware' => _t('Quincaillerie', 'Hardware'),
        'beauty' => _t('Cosmétique', 'Beauty'),
        'restaurant' => _t('Restaurant', 'Restaurant'),
        'services' => _t('Services', 'Services'),
        _ => _t('Autre', 'Other'),
      };
}
