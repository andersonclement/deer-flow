import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validators.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => FakeAuthRepository());

/// Session de l'utilisateur connecté, `null` s'il ne l'est pas.
class SessionController extends Notifier<Session?> {
  @override
  Session? build() => null;

  void open(Session session) => state = session;

  void close() => state = null;
}

final sessionProvider = NotifierProvider<SessionController, Session?>(SessionController.new);

/// Données saisies au fil de l'inscription, gardées en mémoire seulement.
class SignupDraft {
  const SignupDraft({this.phone, this.password});

  final String? phone;
  final String? password;
}

/// Pilote les 4 étapes de l'inscription.
///
/// Chaque méthode `submit…` retourne `null` si l'étape est validée, sinon un
/// code d'erreur que l'écran traduit en message.
class SignupController extends Notifier<SignupDraft> {
  @override
  SignupDraft build() => const SignupDraft();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<String?> submitPhone(String input) async {
    final phone = normalizeCameroonMobile(input);
    if (phone == null) return 'invalid_phone';
    try {
      await _repo.requestOtp(phone);
    } on AuthException catch (e) {
      return e.code;
    }
    state = SignupDraft(phone: phone);
    return null;
  }

  Future<String?> resendOtp() async {
    final phone = state.phone;
    if (phone == null) return 'invalid_phone';
    try {
      await _repo.requestOtp(phone);
    } on AuthException catch (e) {
      return e.code;
    }
    return null;
  }

  Future<String?> submitOtp(String code) async {
    final phone = state.phone;
    if (phone == null) return 'invalid_phone';
    if (!isValidOtp(code)) return 'invalid_otp';
    try {
      await _repo.verifyOtp(phone, code);
    } on AuthException catch (e) {
      return e.code;
    }
    return null;
  }

  String? submitPassword(String password, String confirmation) {
    if (!PasswordRules.check(password).isValid) return 'weak_password';
    if (password != confirmation) return 'passwords_differ';
    state = SignupDraft(phone: state.phone, password: password);
    return null;
  }

  Future<String?> submitBusiness(Business business) async {
    final phone = state.phone;
    final password = state.password;
    if (phone == null || password == null) return 'otp_not_verified';
    if (business.name.trim().isEmpty) return 'missing_name';
    try {
      final session = await _repo.register(phone: phone, password: password, business: business);
      ref.read(sessionProvider.notifier).open(session);
    } on AuthException catch (e) {
      return e.code;
    }
    // Le mot de passe ne reste pas en mémoire une fois le compte créé.
    state = const SignupDraft();
    return null;
  }
}

final signupProvider = NotifierProvider<SignupController, SignupDraft>(SignupController.new);

/// Connexion avec numéro et mot de passe.
class LoginController extends Notifier<void> {
  @override
  void build() {}

  /// Retourne `null` si la connexion réussit, sinon un code d'erreur.
  Future<String?> submit({required String phoneInput, required String password}) async {
    final phone = normalizeCameroonMobile(phoneInput);
    if (phone == null) return 'invalid_phone';
    try {
      final session = await ref.read(authRepositoryProvider).login(phone: phone, password: password);
      ref.read(sessionProvider.notifier).open(session);
    } on AuthException catch (e) {
      return e.code;
    }
    return null;
  }
}

final loginProvider = NotifierProvider<LoginController, void>(LoginController.new);
