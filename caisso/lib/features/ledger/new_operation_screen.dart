import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/amount_formatter.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'widgets.dart';

/// Saisie d'une vente ou d'une dépense.
class NewOperationScreen extends ConsumerStatefulWidget {
  const NewOperationScreen({super.key, this.kind = 'sale'});

  /// `sale` ou `expense`.
  final String kind;

  @override
  ConsumerState<NewOperationScreen> createState() => _NewOperationScreenState();
}

class _NewOperationScreenState extends ConsumerState<NewOperationScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _customer = TextEditingController();
  final _phone = TextEditingController();

  late bool _isSale = widget.kind != 'expense';

  /// `null` = à crédit (ventes uniquement).
  PaymentMethod? _method = PaymentMethod.cash;
  late DateTime _dueDate = _defaultDueDate();
  bool _saving = false;
  String? _amountError;
  String? _descriptionError;
  String? _customerError;

  bool get _onCredit => _isSale && _method == null;

  @override
  void initState() {
    super.initState();
    // Le message « Enregistré » de la saisie précédente cacherait le bouton.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  DateTime _defaultDueDate() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _customer.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final amount = parseAmount(_amount.text);
    final description = _description.text.trim();
    final customer = _customer.text.trim();
    setState(() {
      _amountError = amount == null ? s.amountRequired : null;
      _descriptionError = description.isEmpty ? s.descriptionRequired : null;
      _customerError = _onCredit && customer.isEmpty ? s.customerRequired : null;
    });
    if (amount == null || _descriptionError != null || _customerError != null) return;

    setState(() => _saving = true);
    final ledger = ref.read(ledgerProvider);
    if (_isSale) {
      await ledger.recordSale(
        description: description,
        amount: amount,
        method: _method,
        customerName: customer.isEmpty ? null : customer,
        customerPhone: normalizeCameroonMobile(_phone.text) ?? _phone.text,
        dueDate: _onCredit ? _dueDate : null,
      );
    } else {
      await ledger.recordExpense(label: description, amount: amount, method: _method ?? PaymentMethod.cash);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.saved} · ${formatXaf(amount)}')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final label = Theme.of(context).textTheme.labelLarge;
    final methods = <PaymentMethod?>[...PaymentMethod.values, if (_isSale) null];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSale ? s.newSale : s.newExpense, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: true, label: Text(s.sale)),
                      ButtonSegment(value: false, label: Text(s.expense)),
                    ],
                    selected: {_isSale},
                    onSelectionChanged: (v) => setState(() {
                      _isSale = v.first;
                      if (!_isSale && _method == null) _method = PaymentMethod.cash;
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(s.amount, style: label),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('amount'),
                    controller: _amount,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [AmountInputFormatter()],
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'F',
                      suffixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                      errorText: _amountError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_isSale ? s.whatSold : s.whatSpent, style: label),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('description'),
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isSale ? s.whatSoldHint : s.whatSpentHint,
                      errorText: _descriptionError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(s.paidWith, style: label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in methods)
                        MethodChip(
                          method: m,
                          selected: _method == m,
                          onSelected: () => setState(() => _method = m),
                        ),
                    ],
                  ),
                  if (_isSale) ...[
                    const SizedBox(height: 16),
                    Text(_onCredit ? s.customer : s.customerOptional, style: label),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('customer'),
                      controller: _customer,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(hintText: s.customerHint, errorText: _customerError),
                    ),
                  ],
                  if (_onCredit) ...[
                    const SizedBox(height: 16),
                    Text(s.customerPhone, style: label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]'))],
                      decoration: const InputDecoration(hintText: '6 77 12 34 56'),
                    ),
                    const SizedBox(height: 16),
                    Text(s.dueDate, style: label),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(s.shortDate(_dueDate)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        alignment: Alignment.centerLeft,
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.border),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(s.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
