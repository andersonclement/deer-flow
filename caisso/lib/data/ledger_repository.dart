import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// Totaux d'une journée.
class DaySummary {
  const DaySummary({
    required this.cashIn,
    required this.mobileMoneyIn,
    required this.salesCount,
    required this.salesTotal,
    required this.expensesTotal,
  });

  static const empty = DaySummary(cashIn: 0, mobileMoneyIn: 0, salesCount: 0, salesTotal: 0, expensesTotal: 0);

  /// Argent réellement encaissé dans la journée, tous moyens confondus.
  final int cashIn;

  /// Part de [cashIn] reçue par MTN MoMo, Orange Money ou Wave.
  final int mobileMoneyIn;
  final int salesCount;
  final int salesTotal;
  final int expensesTotal;

  /// Part du mobile money dans les encaissements, de 0 à 100.
  int get mobileMoneyPercent => cashIn == 0 ? 0 : (mobileMoneyIn * 100 / cashIn).round();
}

/// Une vente pas encore entièrement payée.
class Debt {
  const Debt({
    required this.saleId,
    required this.customerName,
    required this.description,
    required this.amount,
    required this.balance,
    required this.createdAt,
    this.customerPhone,
    this.dueDate,
  });

  final String saleId;
  final String customerName;
  final String? customerPhone;
  final String description;
  final int amount;

  /// Reste à payer.
  final int balance;
  final DateTime? dueDate;
  final DateTime createdAt;

  /// Jours de retard à la date [today] (0 si pas en retard).
  int daysLate(DateTime today) {
    final due = dueDate;
    if (due == null) return 0;
    final days = _dateOnly(today).difference(_dateOnly(due)).inDays;
    return days > 0 ? days : 0;
  }
}

enum OperationKind { sale, expense }

/// Ligne de l'historique : une vente ou une dépense.
class Operation {
  const Operation({
    required this.kind,
    required this.id,
    required this.label,
    required this.amount,
    required this.createdAt,
    this.customerName,
    this.method,
    this.balance = 0,
  });

  final OperationKind kind;
  final String id;
  final String label;
  final String? customerName;
  final int amount;
  final DateTime createdAt;

  /// Moyen du premier paiement ; `null` pour une vente à crédit.
  final PaymentMethod? method;

  /// Reste à payer (ventes uniquement).
  final int balance;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Toutes les écritures du commerçant, stockées sur le téléphone.
class LedgerRepository {
  LedgerRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
      : _now = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  /// Enregistre une vente. Avec [method] `null`, la vente est à crédit et
  /// [customerName] est obligatoire.
  Future<String> recordSale({
    required String description,
    required int amount,
    PaymentMethod? method,
    String? customerName,
    String? customerPhone,
    DateTime? dueDate,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'doit être positif');
    final name = customerName?.trim() ?? '';
    if (method == null && name.isEmpty) {
      throw ArgumentError('Une vente à crédit doit avoir un client.');
    }
    return _db.transaction(() async {
      final now = _now();
      final customerId = name.isEmpty ? null : await _findOrCreateCustomer(name, customerPhone, now);
      final saleId = _uuid.v4();
      await _db.into(_db.sales).insert(SalesCompanion.insert(
            id: saleId,
            customerId: Value(customerId),
            description: description.trim(),
            amount: amount,
            dueDate: Value(method == null ? dueDate : null),
            createdAt: now,
          ));
      if (method != null) {
        await _db.into(_db.payments).insert(PaymentsCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              amount: amount,
              method: method,
              createdAt: now,
            ));
      }
      return saleId;
    });
  }

  /// Enregistre un paiement sur une vente à crédit. Le montant ne peut pas
  /// dépasser le reste à payer.
  Future<void> recordPayment({required String saleId, required int amount, required PaymentMethod method}) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'doit être positif');
    return _db.transaction(() async {
      final balance = await _balanceOf(saleId);
      if (amount > balance) {
        throw ArgumentError.value(amount, 'amount', 'dépasse le reste à payer ($balance)');
      }
      await _db.into(_db.payments).insert(PaymentsCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            amount: amount,
            method: method,
            createdAt: _now(),
          ));
    });
  }

  Future<String> recordExpense({required String label, required int amount, required PaymentMethod method}) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'doit être positif');
    final id = _uuid.v4();
    await _db.into(_db.expenses).insert(ExpensesCompanion.insert(
          id: id,
          label: label.trim(),
          amount: amount,
          method: method,
          createdAt: _now(),
        ));
    return id;
  }

  Stream<DaySummary> watchDay(DateTime day) {
    final start = _dateOnly(day);
    final end = start.add(const Duration(days: 1));
    final range = [Variable.withDateTime(start), Variable.withDateTime(end)];
    return _db
        .customSelect(
          '''
          SELECT
            (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE created_at >= ?1 AND created_at < ?2) AS cash_in,
            (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE created_at >= ?1 AND created_at < ?2 AND method <> 'cash') AS mobile_in,
            (SELECT COUNT(*) FROM sales WHERE created_at >= ?1 AND created_at < ?2) AS sales_count,
            (SELECT COALESCE(SUM(amount), 0) FROM sales WHERE created_at >= ?1 AND created_at < ?2) AS sales_total,
            (SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE created_at >= ?1 AND created_at < ?2) AS expenses_total
          ''',
          variables: range,
          readsFrom: {_db.payments, _db.sales, _db.expenses},
        )
        .watchSingle()
        .map((row) => DaySummary(
              cashIn: row.read<int>('cash_in'),
              mobileMoneyIn: row.read<int>('mobile_in'),
              salesCount: row.read<int>('sales_count'),
              salesTotal: row.read<int>('sales_total'),
              expensesTotal: row.read<int>('expenses_total'),
            ));
  }

  /// Ventes non soldées, les plus anciennes échéances d'abord.
  Stream<List<Debt>> watchDebts() {
    return _db
        .customSelect(
          '''
          SELECT * FROM (
            SELECT s.id, s.description, s.amount, s.due_date, s.created_at,
                   c.name AS customer_name, c.phone AS customer_phone,
                   s.amount - COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.sale_id = s.id), 0) AS balance
            FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
          )
          WHERE balance > 0
          ORDER BY due_date IS NULL, due_date, created_at
          ''',
          readsFrom: {_db.sales, _db.payments, _db.customers},
        )
        .watch()
        .map((rows) => [
              for (final row in rows)
                Debt(
                  saleId: row.read<String>('id'),
                  customerName: row.read<String?>('customer_name') ?? '',
                  customerPhone: row.read<String?>('customer_phone'),
                  description: row.read<String>('description'),
                  amount: row.read<int>('amount'),
                  balance: row.read<int>('balance'),
                  dueDate: row.read<DateTime?>('due_date'),
                  createdAt: row.read<DateTime>('created_at'),
                ),
            ]);
  }

  /// Ventes et dépenses du jour, les plus récentes d'abord.
  Stream<List<Operation>> watchOperations(DateTime day) {
    final start = _dateOnly(day);
    final end = start.add(const Duration(days: 1));
    return _db
        .customSelect(
          '''
          SELECT 'sale' AS kind, s.id, s.description AS label, c.name AS customer_name, s.amount, s.created_at,
                 (SELECT p.method FROM payments p WHERE p.sale_id = s.id AND p.created_at = s.created_at LIMIT 1) AS method,
                 s.amount - COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.sale_id = s.id), 0) AS balance
          FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
          WHERE s.created_at >= ?1 AND s.created_at < ?2
          UNION ALL
          SELECT 'expense', e.id, e.label, NULL, e.amount, e.created_at, e.method, 0
          FROM expenses e
          WHERE e.created_at >= ?1 AND e.created_at < ?2
          ORDER BY created_at DESC
          ''',
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
          readsFrom: {_db.sales, _db.payments, _db.customers, _db.expenses},
        )
        .watch()
        .map((rows) => [
              for (final row in rows)
                Operation(
                  kind: row.read<String>('kind') == 'sale' ? OperationKind.sale : OperationKind.expense,
                  id: row.read<String>('id'),
                  label: row.read<String>('label'),
                  customerName: row.read<String?>('customer_name'),
                  amount: row.read<int>('amount'),
                  createdAt: row.read<DateTime>('created_at'),
                  method: switch (row.read<String?>('method')) {
                    null => null,
                    final m => PaymentMethod.values.byName(m),
                  },
                  balance: row.read<int>('balance'),
                ),
            ]);
  }

  Future<int> _balanceOf(String saleId) async {
    final row = await _db.customSelect(
      'SELECT s.amount - COALESCE((SELECT SUM(amount) FROM payments WHERE sale_id = s.id), 0) AS balance '
      'FROM sales s WHERE s.id = ?',
      variables: [Variable.withString(saleId)],
    ).getSingleOrNull();
    if (row == null) throw ArgumentError.value(saleId, 'saleId', 'vente introuvable');
    return row.read<int>('balance');
  }

  Future<String> _findOrCreateCustomer(String name, String? phone, DateTime now) async {
    final existing = await (_db.select(_db.customers)
          ..where((c) => c.name.lower().equals(name.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
    final cleanPhone = (phone == null || phone.trim().isEmpty) ? null : phone.trim();
    if (existing != null) {
      if (cleanPhone != null && existing.phone != cleanPhone) {
        await (_db.update(_db.customers)..where((c) => c.id.equals(existing.id)))
            .write(CustomersCompanion(phone: Value(cleanPhone)));
      }
      return existing.id;
    }
    final id = _uuid.v4();
    await _db.into(_db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: name,
          phone: Value(cleanPhone),
          createdAt: now,
        ));
    return id;
  }
}
