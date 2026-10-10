import 'package:flutter/services.dart';

/// Garde uniquement les chiffres et les groupe par milliers pendant la
/// saisie : `45000` s'affiche `45 000`.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.maxDigits = 9});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
