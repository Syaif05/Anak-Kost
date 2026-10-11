import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/money.dart';
import '../providers/finance_providers.dart';

class FinanceChartWidget extends ConsumerWidget {
  const FinanceChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    final params = TransactionFilterParams(monthPrefix: monthPrefix);
    final txListAsync = ref.watch(transactionsStreamProvider(params));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(60),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tren Pengeluaran 7 Hari',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Icon(Icons.bar_chart, size: 20, color: Theme.of(context).colorScheme.primary),
                ],
              ),
              const SizedBox(height: 16),
              txListAsync.when(
                data: (transactions) {
                  // Agregasi pengeluaran 7 hari terakhir
                  final days = <String>[];
                  final dailyAmounts = <int>[];

                  for (var i = 6; i >= 0; i--) {
                    final d = now.subtract(Duration(days: i));
                    final dateKey = DateFormat('yyyy-MM-dd').format(d);
                    days.add(DateFormat('dd/MM').format(d));

                    var sum = 0;
                    for (final item in transactions) {
                      if (item.transaction.localDate == dateKey &&
                          item.transaction.kind == 'expense' &&
                          item.transaction.status == 'posted') {
                        sum += item.transaction.amountRp;
                      }
                    }
                    dailyAmounts.add(sum);
                  }

                  final maxAmount = dailyAmounts.fold<int>(0, (max, val) => val > max ? val : max);
                  final maxY = maxAmount == 0 ? 100000.0 : (maxAmount * 1.25);

                  return SizedBox(
                    height: 140,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${days[groupIndex]}\n${Money.format(rod.toY.toInt())}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      days[index],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(7, (index) {
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: dailyAmounts[index].toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => const SizedBox(
                  height: 140,
                  child: Center(child: Text('Gagal memuat tren grafik')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
