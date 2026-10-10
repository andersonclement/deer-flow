/// Formate un montant en francs CFA : `186500` → `186 500 F`.
///
/// Le séparateur de milliers est une espace insécable fine pour éviter
/// qu'un montant soit coupé en fin de ligne.
String formatXaf(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${negative ? '−' : ''}$buffer F';
}

/// Lit un montant saisi (`45 000`, `45.000`) ; `null` si vide ou nul.
int? parseAmount(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  final value = int.tryParse(digits);
  return (value == null || value <= 0) ? null : value;
}
