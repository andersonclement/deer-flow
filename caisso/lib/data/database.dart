import 'package:drift/drift.dart';

part 'database.g.dart';

/// Moyens d'encaissement. Une vente sans paiement est une vente à crédit.
enum PaymentMethod { cash, mtn, orange, wave }

/// Les identifiants sont des UUID générés sur le téléphone : ils restent
/// uniques quand les données de plusieurs appareils seront synchronisées.
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Argent reçu pour une vente : au moment de la vente, ou plus tard pour
/// solder une créance (éventuellement en plusieurs fois).
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  IntColumn get amount => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  IntColumn get amount => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Customers, Sales, Payments, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
