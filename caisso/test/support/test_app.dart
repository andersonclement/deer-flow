import 'package:caisso/app.dart';
import 'package:caisso/data/database.dart';
import 'package:caisso/data/providers.dart';
import 'package:caisso/features/auth/application/auth_controllers.dart';
import 'package:caisso/features/auth/data/auth_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'app avec un faux serveur, une base SQLite en mémoire et une date fixe.
Widget testApp({DateTime? now, AuthRepository? auth, Session? session}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final clock = now ?? DateTime(2026, 10, 10, 11, 42);
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository(latency: Duration.zero)),
      clockProvider.overrideWithValue(() => clock),
      if (session != null) sessionProvider.overrideWith(() => _LoggedIn(session)),
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
        ref.onDispose(db.close);
        return db;
      }),
    ],
    child: const CaissoApp(),
  );
}

class _LoggedIn extends SessionController {
  _LoggedIn(this._session);

  final Session _session;

  @override
  Session? build() => _session;
}

const testSession = Session(
  userId: 'u1',
  phone: '+237677123456',
  business: Business(name: 'Alimentation Nadège', activity: 'food', city: 'Douala'),
);
