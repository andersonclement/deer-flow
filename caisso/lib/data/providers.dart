import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controllers.dart';
import 'database.dart';
import 'ledger_repository.dart';

/// Base locale de l'utilisateur connecté : un fichier par compte, pour que
/// deux commerçants sur le même téléphone ne voient pas leurs données.
final databaseProvider = Provider<AppDatabase>((ref) {
  final userId = ref.watch(sessionProvider.select((s) => s?.userId)) ?? 'anonyme';
  final db = AppDatabase(driftDatabase(
    name: 'caisso_$userId',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  ));
  ref.onDispose(db.close);
  return db;
});

/// Horloge remplaçable dans les tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final ledgerProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)),
);

final daySummaryProvider = StreamProvider<DaySummary>(
  (ref) => ref.watch(ledgerProvider).watchDay(ref.watch(clockProvider)()),
);

final todayOperationsProvider = StreamProvider<List<Operation>>(
  (ref) => ref.watch(ledgerProvider).watchOperations(ref.watch(clockProvider)()),
);

final debtsProvider = StreamProvider<List<Debt>>((ref) => ref.watch(ledgerProvider).watchDebts());
