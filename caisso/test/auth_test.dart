import 'package:caisso/app.dart';
import 'package:caisso/features/auth/application/auth_controllers.dart';
import 'package:caisso/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
  ]);
  addTearDown(container.dispose);
  return container;
}

const _business = Business(name: 'Alimentation Nadège', activity: 'food', city: 'Douala');

void main() {
  group('SignupController', () {
    test('inscription complète puis connexion', () async {
      final c = _container();
      final signup = c.read(signupProvider.notifier);

      expect(await signup.submitPhone('6 77 12 34 56'), isNull);
      expect(c.read(signupProvider).phone, '+237677123456');
      expect(await signup.submitOtp('000000'), 'invalid_otp');
      expect(await signup.submitOtp(FakeAuthRepository.devOtp), isNull);
      expect(signup.submitPassword('faible', 'faible'), 'weak_password');
      expect(signup.submitPassword('Mboppi2026', 'Mboppi2025'), 'passwords_differ');
      expect(signup.submitPassword('Mboppi2026', 'Mboppi2026'), isNull);
      expect(await signup.submitBusiness(_business), isNull);

      expect(c.read(sessionProvider)?.business.name, 'Alimentation Nadège');
      expect(c.read(signupProvider).password, isNull, reason: 'le mot de passe est oublié après inscription');

      c.read(sessionProvider.notifier).close();
      final login = c.read(loginProvider.notifier);
      expect(await login.submit(phoneInput: '677123456', password: 'mauvais'), 'bad_credentials');
      expect(await login.submit(phoneInput: '+237 677 12 34 56', password: 'Mboppi2026'), isNull);
      expect(c.read(sessionProvider)?.phone, '+237677123456');
    });

    test('refuse un numéro invalide sans appeler le serveur', () async {
      final c = _container();
      expect(await c.read(signupProvider.notifier).submitPhone('12345'), 'invalid_phone');
    });

    test('impossible de créer le compte sans code vérifié', () async {
      final c = _container();
      final signup = c.read(signupProvider.notifier);
      await signup.submitPhone('677123456');
      signup.submitPassword('Mboppi2026', 'Mboppi2026');
      expect(await signup.submitBusiness(_business), 'otp_not_verified');
    });

    test('un numéro déjà inscrit est renvoyé vers la connexion', () async {
      final c = _container();
      final signup = c.read(signupProvider.notifier);
      await signup.submitPhone('677123456');
      await signup.submitOtp(FakeAuthRepository.devOtp);
      signup.submitPassword('Mboppi2026', 'Mboppi2026');
      await signup.submitBusiness(_business);
      expect(await signup.submitPhone('677123456'), 'phone_taken');
    });
  });

  testWidgets('parcours d’inscription à l’écran jusqu’à l’accueil', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero))],
      child: const CaissoApp(),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('phone')), '677123456');
    await tester.tap(find.text('Recevoir le code'));
    await tester.pumpAndSettle();
    expect(find.text('Entrez le code reçu'), findsOneWidget);
    expect(find.textContaining('+237 6 77 •• •• 56'), findsOneWidget);

    // Saisir les 6 chiffres valide automatiquement.
    await tester.enterText(find.byKey(const Key('otp')), FakeAuthRepository.devOtp);
    await tester.pumpAndSettle();
    expect(find.text('Créez votre mot de passe'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('password')), 'Mboppi2026');
    await tester.enterText(find.byKey(const Key('confirm')), 'Mboppi2026');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Votre commerce'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('businessName')), 'Alimentation Nadège');
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Caisse du jour'), findsOneWidget);
    expect(find.text('Alimentation Nadège'), findsOneWidget);
  });

  testWidgets('le bouton EN traduit l’écran', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CaissoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Recevoir le code'), findsOneWidget);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Get the code'), findsOneWidget);
  });
}
