import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme.dart';

/// Squelette commun aux écrans d'inscription et de connexion : barre du
/// haut (retour, progression, langue), contenu défilant et bouton d'action
/// collé en bas.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    required this.bottom,
    this.step,
    this.totalSteps = 4,
    this.onBack,
  });

  final List<Widget> children;
  final Widget bottom;
  final int? step;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: s.back,
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: onBack,
              ),
        centerTitle: true,
        title: step == null ? null : StepDots(step: step!, total: totalSteps),
        actions: const [LanguageToggle(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: children,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: bottom,
            ),
          ],
        ),
      ),
    );
  }
}

class StepDots extends ConsumerWidget {
  const StepDots({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Semantics(
      label: s.stepOf(step, total),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == step ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}

class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(localeProvider).languageCode;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: AppColors.ink,
        selectedForegroundColor: Colors.white,
      ),
      segments: const [
        ButtonSegment(value: 'fr', label: Text('FR')),
        ButtonSegment(value: 'en', label: Text('EN')),
      ],
      selected: {code},
      onSelectionChanged: (v) => ref.read(localeProvider.notifier).set(Locale(v.first)),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Champ téléphone avec l'indicatif +237 fixe.
class PhoneField extends ConsumerWidget {
  const PhoneField({super.key, required this.controller, this.errorText, this.onSubmitted});

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.phoneLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          key: const Key('phone'),
          controller: controller,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]'))],
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            // Un widget plutôt que prefixText, qui ne s'affiche qu'au focus.
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Text('+237', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: '6 77 12 34 56',
            errorText: errorText,
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// Champ mot de passe avec bouton afficher / masquer.
class PasswordField extends ConsumerStatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
    this.autofillHints = const [AutofillHints.password],
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Iterable<String> autofillHints;
  final Key? fieldKey;

  @override
  ConsumerState<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends ConsumerState<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          obscureText: !_visible,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            errorText: widget.errorText,
            errorMaxLines: 2,
            suffixIcon: IconButton(
              tooltip: _visible ? s.hidePassword : s.showPassword,
              icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton principal qui affiche un indicateur pendant le chargement.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Text(label),
    );
  }
}
