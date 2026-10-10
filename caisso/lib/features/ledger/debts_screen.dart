import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/amount_formatter.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/ledger_repository.dart';
import '../../data/providers.dart';
import 'widgets.dart';

/// Liste « Qui me doit ? » avec encaissement des créances.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _lateOnly = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final today = ref.watch(clockProvider)();
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final total = debts.fold<int>(0, (sum, d) => sum + d.balance);
    final customers = debts.map((d) => d.customerName.toLowerCase()).toSet().length;
    final lateCount = debts.where((d) => d.daysLate(today) > 0).length;
    final shown = _lateOnly ? debts.where((d) => d.daysLate(today) > 0).toList() : debts;

    return Scaffold(
      appBar: AppBar(title: Text(s.whoOwesMe, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(s.toCollect(formatXaf(total), customers), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('${s.all} · ${debts.length}'),
                selected: !_lateOnly,
                onSelected: (_) => setState(() => _lateOnly = false),
              ),
              ChoiceChip(
                label: Text('${s.late} · $lateCount'),
                selected: _lateOnly,
                onSelected: (_) => setState(() => _lateOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(s.noDebts, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (final (i, debt) in shown.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFE6EAE4)),
                    _DebtTile(debt: debt, today: today),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  const _DebtTile({required this.debt, required this.today});

  final Debt debt;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final late = debt.daysLate(today);
    final due = debt.dueDate;
    final status = late > 0 ? s.daysLate(late) : (due == null ? s.noDueDate : s.dueOn(s.shortDate(due)));
    final initials = debt.customerName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primaryDark,
            child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(debt.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                Text(status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: late > 0 ? AppColors.danger : AppColors.inkMuted,
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatXaf(debt.balance), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => CollectSheet(debt: debt),
                ),
                child: Text(s.collect),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Feuille pour encaisser tout ou partie d'une créance.
class CollectSheet extends ConsumerStatefulWidget {
  const CollectSheet({super.key, required this.debt});

  final Debt debt;

  @override
  ConsumerState<CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends ConsumerState<CollectSheet> {
  late final _amount = TextEditingController(
    text: const AmountInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: '${widget.debt.balance}'))
        .text,
  );
  PaymentMethod _method = PaymentMethod.mtn;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final amount = parseAmount(_amount.text);
    if (amount == null) return setState(() => _error = s.amountRequired);
    if (amount > widget.debt.balance) return setState(() => _error = s.amountTooHigh);
    setState(() => _saving = true);
    await ref.read(ledgerProvider).recordPayment(saleId: widget.debt.saleId, amount: amount, method: _method);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('${s.saved} · ${formatXaf(amount)}')));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.collectFrom(widget.debt.customerName), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.remaining(formatXaf(widget.debt.balance)), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            key: const Key('collectAmount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: const [AmountInputFormatter()],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(suffixText: 'F', errorText: _error),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in PaymentMethod.values)
                MethodChip(method: m, selected: _method == m, onSelected: () => setState(() => _method = m)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: Text(s.collect)),
        ],
      ),
    );
  }
}
