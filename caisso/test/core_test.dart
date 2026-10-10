import 'package:caisso/core/format.dart';
import 'package:caisso/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeCameroonMobile', () {
    test('accepte les formats courants', () {
      for (final input in ['677123456', '6 77 12 34 56', '+237 677 12 34 56', '00237677123456', '237677123456', '677-12-34-56']) {
        expect(normalizeCameroonMobile(input), '+237677123456', reason: input);
      }
    });

    test('refuse les numéros invalides', () {
      for (final input in ['', '77123456', '577123456', '6771234567', '+33612345678', 'abc']) {
        expect(normalizeCameroonMobile(input), isNull, reason: input);
      }
    });
  });

  test('maskPhone cache le milieu du numéro', () {
    expect(maskPhone('+237677123456'), '+237 6 77 •• •• 56');
  });

  test('isValidOtp exige 6 chiffres', () {
    expect(isValidOtp('123456'), isTrue);
    expect(isValidOtp('12345'), isFalse);
    expect(isValidOtp('12a456'), isFalse);
  });

  group('PasswordRules', () {
    test('mot de passe valide', () {
      final rules = PasswordRules.check('Mboppi2026');
      expect(rules.isValid, isTrue);
      expect(rules.score, 3);
    });

    test('signale chaque règle manquante', () {
      final rules = PasswordRules.check('abc');
      expect(rules.minLength, isFalse);
      expect(rules.hasDigit, isFalse);
      expect(rules.hasUppercase, isFalse);
      expect(rules.score, 0);
      expect(PasswordRules.check('abcdefgh1').hasUppercase, isFalse);
    });
  });

  test('formatXaf groupe les milliers', () {
    expect(formatXaf(0), '0 F');
    expect(formatXaf(950), '950 F');
    expect(formatXaf(186500), '186 500 F');
    expect(formatXaf(1000000), '1 000 000 F');
    expect(formatXaf(-6000), '−6 000 F');
  });
}
