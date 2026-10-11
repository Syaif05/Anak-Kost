import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/finance_providers.dart';
import 'widgets/balance_card.dart';
import 'widgets/budget_card_widget.dart';
import 'widgets/finance_chart_widget.dart';
import 'widgets/recent_transactions_widget.dart';
import 'widgets/wallets_list_widget.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  @override
  void initState() {
    super.initState();
    // Inisialisasi wallet dan kategori default jika baru pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financeRepositoryProvider).seedDefaultsIfEmpty();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Keuangan & Budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Target Tabungan',
            onPressed: () => context.push('/finance/savings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/finance/add?kind=expense'),
        tooltip: 'Catat Pengeluaran',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Riverpod watch-based streams auto-refresh
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: const [
            BalanceCard(),
            SizedBox(height: 12),
            WalletsListWidget(),
            SizedBox(height: 16),
            BudgetCardWidget(),
            SizedBox(height: 16),
            FinanceChartWidget(),
            SizedBox(height: 16),
            RecentTransactionsWidget(),
          ],
        ),
      ),
    );
  }
}
