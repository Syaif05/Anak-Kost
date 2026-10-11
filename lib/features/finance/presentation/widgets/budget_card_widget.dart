import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/money.dart';
import '../../domain/models/finance_models.dart';
import '../providers/finance_providers.dart';
import 'add_budget_sheet.dart';

class BudgetCardWidget extends ConsumerWidget {
  const BudgetCardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonthStart = DateFormat('yyyy-MM-01').format(now);
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(now);

    final budgetListAsync = ref.watch(budgetProgressStreamProvider(currentMonthStart));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pie_chart_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Budget $monthName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Atur'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (ctx) => const AddBudgetSheet(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              budgetListAsync.when(
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Belum ada limit budget bulan ini.\nTekan "Atur" untuk membatasi pengeluaran kategori.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: budgets.map((b) => _BudgetItemRow(progress: b)).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetItemRow extends StatelessWidget {
  final BudgetProgress progress;

  const _BudgetItemRow({required this.progress});

  Color _getStatusColor() {
    if (progress.isOverBudget) return Colors.red;
    if (progress.isWarning80) return Colors.orange;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final clampedRatio = progress.percentage > 1.0 ? 1.0 : progress.percentage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.category.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '${(progress.percentage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedRatio,
              minHeight: 7,
              backgroundColor: Colors.grey.withAlpha(40),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${Money.format(progress.spentRp)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                progress.isOverBudget
                    ? 'Lewat ${Money.format(-progress.remainingRp)}'
                    : 'Sisa ${Money.format(progress.remainingRp)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: progress.isOverBudget ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
