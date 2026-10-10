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
