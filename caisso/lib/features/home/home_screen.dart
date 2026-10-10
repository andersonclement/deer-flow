import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../auth/application/auth_controllers.dart';
import '../auth/presentation/widgets.dart';

/// Accueil : caisse du jour et créances. Les chiffres viendront de la base
/// locale des ventes, branchée à l'étape suivante.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final business = session.business;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.hello, style: Theme.of(context).textTheme.bodySmall),
            Text(business.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          const LanguageToggle(),
          IconButton(
            tooltip: s.logout,
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionProvider.notifier).close();
              context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.todayCash, style: const TextStyle(color: Color(0xFFB9D3C6), fontSize: 13)),
                const SizedBox(height: 8),
                Text(formatXaf(0), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(label: s.sales, value: '0'),
                    _Stat(label: s.expenses, value: formatXaf(0)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(16)),
            child: Text('${s.owedToYou} · ${formatXaf(0)}',
                style: const TextStyle(color: AppColors.warningInk, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          Text(s.noSalesYet, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        // La saisie vocale arrive à l'étape suivante.
        onPressed: null,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.mic_none, size: 32),
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
