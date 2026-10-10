import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/database.dart';

/// Pastille de choix du moyen de paiement ; `method` `null` = à crédit.
class MethodChip extends ConsumerWidget {
  const MethodChip({super.key, required this.method, required this.selected, required this.onSelected});

  final PaymentMethod? method;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final credit = method == null;
    final selectedColor = credit ? AppColors.warningInk : AppColors.primary;
    return ChoiceChip(
      label: Text(s.methodLabel(method?.name ?? 'credit')),
      selected: selected,
      showCheckmark: false,
      selectedColor: selectedColor,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
      onSelected: (_) => onSelected(),
    );
  }
}
