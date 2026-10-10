import 'package:caisso/data/database.dart';
import 'package:caisso/data/ledger_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LedgerRepository ledger;
  var now = DateTime(2026, 10, 10, 11, 42);

  setUp(() {
    now = DateTime(2026, 10, 10, 11, 42);
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  final today = DateTime(2026, 10, 10);

  test('résumé du jour : encaissé, mobile money, ventes, dépenses', () async {
    await ledger.recordSale(description: 'Huile 5 L × 4', amount: 38000, method: PaymentMethod.mtn, customerName: 'Jean Mbarga');
    await ledger.recordSale(description: 'Savon × 10', amount: 5000, method: PaymentMethod.cash);
    await ledger.recordSale(
      description: 'Riz 25 kg × 3',
      amount: 45000,
      customerName: 'Brigitte Ngono',
      dueDate: DateTime(2026, 10, 11),
    );
    await ledger.recordExpense(label: 'Transport', amount: 6000, method: PaymentMethod.cash);

    final day = await ledger.watchDay(today).first;
    expect(day.salesCount, 3);
    expect(day.salesTotal, 88000);
    expect(day.cashIn, 43000, reason: 'la vente à crédit n’est pas encore encaissée');
    expect(day.mobileMoneyIn, 38000);
    expect(day.mobileMoneyPercent, 88);
    expect(day.expensesTotal, 6000);

    final yesterday = await ledger.watchDay(DateTime(2026, 10, 9)).first;
    expect(yesterday.salesCount, 0);
  });

  test('créance : paiements partiels puis soldée', () async {
    final saleId = await ledger.recordSale(
      description: 'Riz 25 kg × 3',
      amount: 45000,
      customerName: 'Brigitte Ngono',
      customerPhone: '+237677000044',
      dueDate: DateTime(2026, 10, 11),
    );

    var debts = await ledger.watchDebts().first;
    expect(debts, hasLength(1));
    expect(debts.single.balance, 45000);
    expect(debts.single.customerName, 'Brigitte Ngono');
    expect(debts.single.customerPhone, '+237677000044');
    expect(debts.single.daysLate(DateTime(2026, 10, 11)), 0);
    expect(debts.single.daysLate(DateTime(2026, 10, 20)), 9);

    now = DateTime(2026, 10, 12, 9);
    await ledger.recordPayment(saleId: saleId, amount: 20000, method: PaymentMethod.orange);
    debts = await ledger.watchDebts().first;
    expect(debts.single.balance, 25000);

    expect(
      () => ledger.recordPayment(saleId: saleId, amount: 30000, method: PaymentMethod.cash),
      throwsArgumentError,
      reason: 'on ne peut pas encaisser plus que le reste',
    );

    await ledger.recordPayment(saleId: saleId, amount: 25000, method: PaymentMethod.cash);
    expect(await ledger.watchDebts().first, isEmpty);

    // L'argent compte dans la caisse du jour où il est reçu.
    final day12 = await ledger.watchDay(DateTime(2026, 10, 12)).first;
    expect(day12.cashIn, 45000);
    expect(day12.salesCount, 0);
  });

  test('le même client est réutilisé, sans tenir compte des majuscules', () async {
    await ledger.recordSale(description: 'A', amount: 1000, customerName: 'Grace Nkeng');
    await ledger.recordSale(description: 'B', amount: 2000, customerName: 'grace nkeng ');
    final customers = await db.select(db.customers).get();
    expect(customers, hasLength(1));
  });

  test('refuse les saisies invalides', () {
    expect(() => ledger.recordSale(description: 'X', amount: 0, method: PaymentMethod.cash), throwsArgumentError);
    expect(() => ledger.recordSale(description: 'X', amount: 1000), throwsArgumentError,
        reason: 'crédit sans client');
    expect(() => ledger.recordExpense(label: 'X', amount: -5, method: PaymentMethod.cash), throwsArgumentError);
  });

  test('historique du jour mélange ventes et dépenses, du plus récent au plus ancien', () async {
    now = DateTime(2026, 10, 10, 8, 30);
    await ledger.recordExpense(label: 'Transport', amount: 6000, method: PaymentMethod.cash);
    now = DateTime(2026, 10, 10, 10, 15);
    await ledger.recordSale(description: 'Huile', amount: 38000, method: PaymentMethod.wave);
    now = DateTime(2026, 10, 10, 11, 42);
    await ledger.recordSale(description: 'Riz', amount: 45000, customerName: 'Brigitte');

    final ops = await ledger.watchOperations(today).first;
    expect(ops.map((o) => o.label), ['Riz', 'Huile', 'Transport']);
    expect(ops[0].method, isNull);
    expect(ops[0].balance, 45000);
    expect(ops[1].method, PaymentMethod.wave);
    expect(ops[2].kind, OperationKind.expense);
  });

  test('les flux se mettent à jour après une écriture', () async {
    final stream = ledger.watchDay(today);
    final values = <int>[];
    final sub = stream.listen((d) => values.add(d.cashIn));
    await pumpEventQueue();
    await ledger.recordSale(description: 'X', amount: 1500, method: PaymentMethod.cash);
    await pumpEventQueue();
    await sub.cancel();
    expect(values, [0, 1500]);
  });
}
