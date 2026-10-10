import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme.dart';
import '../application/auth_controllers.dart';
import 'widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(loginProvider.notifier).submit(
          phoneInput: _phone.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final phoneError = _error == 'invalid_phone' ? s.authError(_error!) : null;
    final passwordError = _error != null && _error != 'invalid_phone' ? s.authError(_error!) : null;
    return AuthScaffold(
      onBack: () => context.go('/signup'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: s.login, loading: _loading, onPressed: _submit),
          TextButton(
            onPressed: () => context.go('/signup'),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${s.noAccount} ', style: const TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w400)),
              TextSpan(text: s.signup),
            ])),
          ),
        ],
      ),
      children: [
        AuthHeader(title: s.loginTitle, subtitle: s.loginSubtitle),
        AutofillGroup(
          child: Column(
            children: [
              PhoneField(controller: _phone, errorText: phoneError),
              const SizedBox(height: 16),
              PasswordField(
                fieldKey: const Key('loginPassword'),
                controller: _password,
                label: s.password,
                errorText: passwordError,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          // La réinitialisation par SMS sera branchée avec le vrai backend.
          child: TextButton(onPressed: null, child: Text(s.forgotPassword)),
        ),
      ],
    );
  }
}
