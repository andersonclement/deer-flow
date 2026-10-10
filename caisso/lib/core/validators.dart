/// Validation des saisies utilisateur (numéro camerounais, code, mot de passe).
library;

/// Normalise un numéro mobile camerounais au format E.164 (`+2376XXXXXXXX`).
///
/// Accepte les espaces, tirets, points et les préfixes `+237`, `00237`
/// ou `237`. Retourne `null` si le numéro n'est pas un mobile valide
/// (9 chiffres commençant par 6).
String? normalizeCameroonMobile(String input) {
  var digits = input.replaceAll(RegExp(r'[\s\-.()]'), '');
  if (digits.startsWith('+237')) {
    digits = digits.substring(4);
  } else if (digits.startsWith('00237')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('237') && digits.length == 12) {
    digits = digits.substring(3);
  }
  if (!RegExp(r'^6\d{8}$').hasMatch(digits)) return null;
  return '+237$digits';
}

/// Masque un numéro E.164 pour l'affichage : `+237 6 77 •• •• 44`.
String maskPhone(String e164) {
  final local = e164.replaceFirst('+237', '');
  if (local.length != 9) return e164;
  return '+237 ${local[0]} ${local.substring(1, 3)} •• •• ${local.substring(7)}';
}

/// Un code de vérification valide contient exactement 6 chiffres.
bool isValidOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);

/// Règles du mot de passe, évaluées une par une pour l'affichage.
class PasswordRules {
  const PasswordRules({
    required this.minLength,
    required this.hasDigit,
    required this.hasUppercase,
  });

  factory PasswordRules.check(String password) => PasswordRules(
        minLength: password.length >= 8,
        hasDigit: RegExp(r'\d').hasMatch(password),
        hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      );

  final bool minLength;
  final bool hasDigit;
  final bool hasUppercase;

  bool get isValid => minLength && hasDigit && hasUppercase;

  /// Nombre de règles respectées (0 à 3), utilisé pour la jauge de force.
  int get score => [minLength, hasDigit, hasUppercase].where((ok) => ok).length;
}
