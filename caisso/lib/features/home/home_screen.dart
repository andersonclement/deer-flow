import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/ledger_repository.dart';
import '../../data/providers.dart';
import '../auth/application/auth_controllers.dart';
import '../auth/presentation/widgets.dart';

/// Accueil : caisse du jour, créances, actions rapides et opérations du jour.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final today = ref.watch(clockProvider)();
    final day = ref.watch(daySummaryProvider).value ?? DaySummary.empty;
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final operations = ref.watch(todayOperationsProvider).value ?? const <Operation>[];
    final owed = debts.fold<int>(0, (sum, d) => sum + d.balance);
    final debtors = debts.map((d) => d.customerName.toLowerCase()).toSet().length;
    final late = debts.where((d) => d.daysLate(today) > 0).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.hello, style: Theme.of(context).textTheme.bodySmall),
            Text(session.business.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          const LanguageToggle(),
          IconButton(
            tooltip: s.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).close(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _CashCard(day: day, date: s.shortDate(today)),
          const SizedBox(height: 12),
          Material(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/debts'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.owedToYou, style: const TextStyle(color: AppColors.warningInk, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(formatXaf(owed),
                              style: const TextStyle(color: AppColors.warningInk, fontWeight: FontWeight.w700, fontSize: 22)),
                          Text(debtors == 0 ? s.nothingOwed : s.debtSummary(debtors, late),
                              style: const TextStyle(color: AppColors.warningInk, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.warningInk),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _QuickAction(icon: Icons.add, label: s.sale, onTap: () => context.push('/operation/sale')),
              _QuickAction(icon: Icons.remove, label: s.expense, onTap: () => context.push('/operation/expense')),
              _QuickAction(icon: Icons.people_outline, label: s.debts, onTap: () => context.push('/debts')),
            ],
          ),
          const SizedBox(height: 20),
          Text(s.today, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (operations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(s.noSalesYet, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (final (i, op) in operations.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFE6EAE4)),
                    _OperationTile(op: op),
                  ],
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/operation/sale'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(s.sale, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CashCard extends ConsumerWidget {
  const _CashCard({required this.day, required this.date});

  final DaySummary day;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    const muted = Color(0xFFB9D3C6);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s.todayCash} · $date', style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatXaf(day.cashIn),
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: s.sales, value: '${day.salesCount}'),
              _Stat(label: s.mobileMoney, value: '${day.mobileMoneyPercent} %'),
              _Stat(label: s.expenses, value: formatXaf(day.expensesTotal)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFB9D3C6), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationTile extends ConsumerWidget {
  const _OperationTile({required this.op});

  final Operation op;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final isExpense = op.kind == OperationKind.expense;
    final onCredit = !isExpense && op.method == null;
    final title = [if (op.customerName != null) op.customerName!, op.label].join(' · ');
    final subtitle = '${s.time(op.createdAt)} · ${s.methodLabel(op.method?.name ?? 'credit')}';
    final amountText = isExpense ? formatXaf(-op.amount) : (onCredit ? formatXaf(op.amount) : '+${formatXaf(op.amount)}');
    final color = isExpense ? AppColors.ink : (onCredit ? const Color(0xFF8A5A00) : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(amountText, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
