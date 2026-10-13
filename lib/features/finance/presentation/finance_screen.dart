import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/app_ui_components.dart';
import '../../ocr/presentation/widgets/receipt_scanner_sheet.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Keuangan & Budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          AppSquareIconButton(
            icon: Icons.document_scanner_outlined,
            tooltip: 'Pindai Struk Belanja (OCR)',
            onPressed: () => ReceiptScannerSheet.show(context),
          ),
          const SizedBox(width: 8),
          AppSquareIconButton(
            icon: Icons.savings_outlined,
            tooltip: 'Target Tabungan',
            onPressed: () => context.push('/finance/savings'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton(
          backgroundColor: AppTheme.primaryTeal,
          foregroundColor: Colors.white,
          onPressed: () => context.push('/finance/add?kind=expense'),
          tooltip: 'Catat Pengeluaran',
          child: const Icon(Icons.add),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryTeal,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: const [
            BalanceCard(),
            SizedBox(height: 16),
            WalletsListWidget(),
            SizedBox(height: 20),
            BudgetCardWidget(),
            SizedBox(height: 20),
            FinanceChartWidget(),
            SizedBox(height: 20),
            RecentTransactionsWidget(),
          ],
        ),
      ),
    );
  }
}
