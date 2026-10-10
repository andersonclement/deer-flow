import 'dart:async';

/// Activités proposées à l'inscription. Les libellés sont dans `AppStrings`.
const activityKeys = ['food', 'hardware', 'beauty', 'restaurant', 'services', 'other'];

/// Villes proposées à l'inscription.
const cities = ['Douala', 'Yaoundé', 'Bafoussam', 'Garoua', 'Bamenda', 'Autre'];

class Business {
  const Business({
    required this.name,
    required this.activity,
    required this.city,
    this.niu,
  });

  final String name;
  final String activity;
  final String city;
  final String? niu;
}

class Session {
  const Session({required this.userId, required this.phone, required this.business});

  final String userId;
  final String phone;
  final Business business;
}

class AuthException implements Exception {
  const AuthException(this.code);

  /// `phone_taken`, `invalid_otp`, `bad_credentials`, `otp_not_verified`.
  final String code;

  @override
  String toString() => 'AuthException($code)';
}

/// Contrat avec le backend d'authentification.
///
/// L'implémentation réelle appellera l'API en HTTPS : c'est le serveur qui
/// envoie le SMS, vérifie le code et stocke le mot de passe haché. L'app ne
/// garde jamais le mot de passe en clair.
abstract interface class AuthRepository {
  Future<void> requestOtp(String phone);

  Future<void> verifyOtp(String phone, String code);

  Future<Session> register({
    required String phone,
    required String password,
    required Business business,
  });

  Future<Session> login({required String phone, required String password});
}

/// Implémentation en mémoire pour le développement et les tests.
///
/// Le code de vérification est toujours [devOtp].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 400)});

  static const devOtp = '123456';

  final Duration latency;
  final _accounts = <String, ({String password, Session session})>{};
  final _verifiedPhones = <String>{};

  @override
  Future<void> requestOtp(String phone) async {
    await Future<void>.delayed(latency);
    if (_accounts.containsKey(phone)) throw const AuthException('phone_taken');
  }

  @override
  Future<void> verifyOtp(String phone, String code) async {
    await Future<void>.delayed(latency);
    if (code != devOtp) throw const AuthException('invalid_otp');
    _verifiedPhones.add(phone);
  }

  @override
  Future<Session> register({
    required String phone,
    required String password,
    required Business business,
  }) async {
    await Future<void>.delayed(latency);
    if (!_verifiedPhones.contains(phone)) throw const AuthException('otp_not_verified');
    if (_accounts.containsKey(phone)) throw const AuthException('phone_taken');
    final session = Session(userId: 'u${_accounts.length + 1}', phone: phone, business: business);
    _accounts[phone] = (password: password, session: session);
    return session;
  }

  @override
  Future<Session> login({required String phone, required String password}) async {
    await Future<void>.delayed(latency);
    final account = _accounts[phone];
    if (account == null || account.password != password) {
      throw const AuthException('bad_credentials');
    }
    return account.session;
  }
}
