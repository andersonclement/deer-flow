import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';
import '../application/auth_controllers.dart';
import '../data/auth_repository.dart';
import 'widgets.dart';

/// Étape 1 : numéro de téléphone.
class SignupPhoneScreen extends ConsumerStatefulWidget {
  const SignupPhoneScreen({super.key});

  @override
  ConsumerState<SignupPhoneScreen> createState() => _SignupPhoneScreenState();
}

class _SignupPhoneScreenState extends ConsumerState<SignupPhoneScreen> {
  final _phone = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(signupProvider.notifier).submitPhone(_phone.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) context.push('/signup/otp');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return AuthScaffold(
      step: 1,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: s.getCode, loading: _loading, onPressed: _submit),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${s.hasAccount} ', style: const TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w400)),
              TextSpan(text: s.login),
            ])),
          ),
          Text(s.terms, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      children: [
        const _Logo(),
        const SizedBox(height: 20),
        AuthHeader(title: s.welcomeTitle, subtitle: s.welcomeSubtitle),
        PhoneField(
          controller: _phone,
          errorText: _error == null ? null : s.authError(_error!),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 6),
        Text(s.phoneHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Étape 2 : code reçu par SMS.
class SignupOtpScreen extends ConsumerStatefulWidget {
  const SignupOtpScreen({super.key});

  @override
  ConsumerState<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends ConsumerState<SignupOtpScreen> {
  static const _resendDelay = 45;

  final _code = TextEditingController();
  String? _error;
  bool _loading = false;
  int _secondsLeft = _resendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(signupProvider.notifier).submitOtp(_code.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) context.push('/signup/password');
  }

  Future<void> _resend() async {
    final error = await ref.read(signupProvider.notifier).resendOtp();
    if (!mounted) return;
    if (error == null) {
      _startTimer();
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final phone = ref.watch(signupProvider).phone;
    return AuthScaffold(
      step: 2,
      onBack: () => context.pop(),
      bottom: PrimaryButton(label: s.verify, loading: _loading, onPressed: _submit),
      children: [
        AuthHeader(title: s.otpTitle, subtitle: s.otpSentTo(phone == null ? '' : maskPhone(phone))),
        Text(s.otpLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          key: const Key('otp'),
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 12),
          onChanged: (v) {
            if (v.length == 6) _submit();
          },
          decoration: InputDecoration(
            hintText: '••••••',
            errorText: _error == null ? null : s.authError(_error!),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _secondsLeft > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(s.resendIn(_secondsLeft), style: Theme.of(context).textTheme.bodySmall),
                )
              : TextButton(onPressed: _resend, child: Text(s.resend)),
        ),
      ],
    );
  }
}

/// Étape 3 : création du mot de passe.
class SignupPasswordScreen extends ConsumerStatefulWidget {
  const SignupPasswordScreen({super.key});

  @override
  ConsumerState<SignupPasswordScreen> createState() => _SignupPasswordScreenState();
}

class _SignupPasswordScreenState extends ConsumerState<SignupPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final error = ref.read(signupProvider.notifier).submitPassword(_password.text, _confirm.text);
    setState(() => _error = error);
    if (error == null) context.push('/signup/business');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final rules = PasswordRules.check(_password.text);
    return AuthScaffold(
      step: 3,
      onBack: () => context.pop(),
      bottom: PrimaryButton(label: s.continueLabel, onPressed: _submit),
      children: [
        AuthHeader(title: s.passwordTitle, subtitle: s.passwordSubtitle),
        PasswordField(
          fieldKey: const Key('password'),
          controller: _password,
          label: s.password,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _StrengthBar(score: rules.score),
        const SizedBox(height: 12),
        _Rule(label: s.ruleLength, ok: rules.minLength),
        _Rule(label: s.ruleDigit, ok: rules.hasDigit),
        _Rule(label: s.ruleUpper, ok: rules.hasUppercase),
        const SizedBox(height: 16),
        PasswordField(
          fieldKey: const Key('confirm'),
          controller: _confirm,
          label: s.confirmPassword,
          autofillHints: const [AutofillHints.newPassword],
          errorText: _error == null ? null : s.authError(_error!),
        ),
      ],
    );
  }
}

/// Étape 4 : informations du commerce, puis création du compte.
class SignupBusinessScreen extends ConsumerStatefulWidget {
  const SignupBusinessScreen({super.key});

  @override
  ConsumerState<SignupBusinessScreen> createState() => _SignupBusinessScreenState();
}

class _SignupBusinessScreenState extends ConsumerState<SignupBusinessScreen> {
  final _name = TextEditingController();
  final _niu = TextEditingController();
  String _activity = activityKeys.first;
  String _city = cities.first;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _niu.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final niu = _niu.text.trim();
    final error = await ref.read(signupProvider.notifier).submitBusiness(Business(
          name: _name.text.trim(),
          activity: _activity,
          city: _city,
          niu: niu.isEmpty ? null : niu,
        ));
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
    final label = Theme.of(context).textTheme.labelLarge;
    return AuthScaffold(
      step: 4,
      onBack: () => context.pop(),
      bottom: PrimaryButton(label: s.start, loading: _loading, onPressed: _submit),
      children: [
        AuthHeader(title: s.businessTitle, subtitle: s.businessSubtitle),
        Text(s.businessName, style: label),
        const SizedBox(height: 6),
        TextField(
          key: const Key('businessName'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Alimentation Nadège',
            errorText: _error == null ? null : s.authError(_error!),
          ),
        ),
        const SizedBox(height: 16),
        Text(s.activity, style: label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in activityKeys)
              ChoiceChip(
                label: Text(s.activityLabel(key)),
                selected: _activity == key,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _activity == key ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _activity = key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(s.city, style: label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _city,
          items: [for (final c in cities) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _city = v ?? _city),
        ),
        const SizedBox(height: 16),
        Text(s.niu, style: label),
        const SizedBox(height: 6),
        TextField(
          controller: _niu,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: s.niuHint),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(18)),
        child: const Text('C', style: TextStyle(color: AppColors.ground, fontSize: 28, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: i < score ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? AppColors.primary : AppColors.border,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: ok ? AppColors.ink : AppColors.inkMuted)),
        ],
      ),
    );
  }
}
