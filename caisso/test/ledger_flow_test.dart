import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Future<void> fill(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  /// Écran de test à la taille d'un téléphone (390 × 844).
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('vente payée, vente à crédit, puis encaissement de la créance', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(testApp(session: testSession));
    await tester.pumpAndSettle();
    expect(find.text('Personne ne vous doit d’argent'), findsOneWidget);

    // Vente payée par MTN MoMo.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await fill(tester, 'amount', '38000');
    expect(find.text('38 000'), findsOneWidget, reason: 'le montant est groupé par milliers');
    await fill(tester, 'description', 'Huile 5 L × 4');
    await tester.tap(find.text('MTN MoMo'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('38 000 F'), findsOneWidget, reason: 'caisse du jour');
    expect(find.text('+38 000 F'), findsOneWidget, reason: 'ligne de l’historique');
    expect(find.text('100 %'), findsOneWidget, reason: 'tout en mobile money');

    // Vente à crédit : le client est obligatoire.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await fill(tester, 'amount', '45000');
    await fill(tester, 'description', 'Riz 25 kg × 3');
    await tester.tap(find.text('À crédit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Pour une vente à crédit, indiquez le client.'), findsOneWidget);
    await fill(tester, 'customer', 'Brigitte Ngono');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('38 000 F'), findsWidgets, reason: 'le crédit n’entre pas dans la caisse');
    expect(find.text('45 000 F'), findsWidgets, reason: 'montant dû');
    expect(find.text('1 client'), findsOneWidget);

    // Encaissement de la créance.
    await tester.tap(find.text('On vous doit'));
    await tester.pumpAndSettle();
    expect(find.text('Brigitte Ngono'), findsOneWidget);
    expect(find.text('Échéance 17 oct.'), findsOneWidget, reason: 'échéance par défaut à 7 jours');
    await tester.tap(find.text('Encaisser'));
    await tester.pumpAndSettle();
    await fill(tester, 'collectAmount', '50000');
    await tester.tap(find.text('Encaisser').last);
    await tester.pumpAndSettle();
    expect(find.text('Le montant dépasse le reste à payer.'), findsOneWidget);
    await fill(tester, 'collectAmount', '45000');
    await tester.tap(find.text('Orange Money'));
    await tester.tap(find.text('Encaisser').last);
    await tester.pumpAndSettle();
    expect(find.text('Aucune créance. Bravo !'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('83 000 F'), findsOneWidget, reason: '38 000 + 45 000 encaissés');
    expect(find.text('Personne ne vous doit d’argent'), findsOneWidget);
  });

  testWidgets('dépense', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(testApp(session: testSession));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dépense'));
    await tester.pumpAndSettle();
    expect(find.text('À crédit'), findsNothing, reason: 'pas de crédit pour une dépense');
    await fill(tester, 'amount', '6000');
    await fill(tester, 'description', 'Transport marchandise');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('6\u202F000 F'), findsOneWidget, reason: 'total des dépenses du jour');
    expect(find.text('−6\u202F000 F'), findsOneWidget, reason: 'ligne de l’historique');
  });
}
