import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/money.dart';
import '../domain/models/bill_models.dart';
import 'providers/bills_providers.dart';
import 'widgets/add_bill_template_sheet.dart';
import 'widgets/pay_bill_dialog.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    // Auto-generate occurrences for current period on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateCurrentMonthOccurrences();
    });
  }

  String get _periodKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _generateCurrentMonthOccurrences() {
    ref.read(billsRepositoryProvider).generateOccurrencesForPeriod(_periodKey);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _generateCurrentMonthOccurrences();
  }

  void _openAddTemplateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddBillTemplateSheet(),
    ).then((_) {
      _generateCurrentMonthOccurrences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrencesAsync = ref.watch(billOccurrencesForPeriodProvider(_periodKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tagihan Kost',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sinkronkan Tagihan Bulan Ini',
            onPressed: _generateCurrentMonthOccurrences,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTemplateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tagihan'),
      ),
      body: Column(
        children: [
          // Month Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Area
          Expanded(
            child: occurrencesAsync.when(
              data: (occurrences) {
                // Calculate Totals
                final totalDue = occurrences.fold(0, (sum, o) => sum + o.effectiveAmountDueRp);
                final totalPaid = occurrences.fold(0, (sum, o) => sum + o.totalPaidRp);
                final totalRemaining = occurrences.fold(0, (sum, o) => sum + o.remainingRp);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    // Summary Banner Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withAlpha(180),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Tagihan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onPrimaryContainer.withAlpha(200),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Money.format(totalDue),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Sisa Belum Bayar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onPrimaryContainer.withAlpha(200),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Money.format(totalRemaining),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: totalRemaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalDue > 0 ? (totalPaid / totalDue) : 1.0,
                              minHeight: 8,
                              backgroundColor: Colors.white38,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Terbayar: ${Money.format(totalPaid)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                totalDue > 0 ? '${((totalPaid / totalDue) * 100).toInt()}%' : '100%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (occurrences.isEmpty) ...[
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'Belum Ada Tagihan di Bulan Ini',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Buat template tagihan baru dengan tombol di bawah',
                              style: TextStyle(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...occurrences.map((occ) => _BillOccurrenceCard(occurrence: occ)),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Gagal memuat tagihan: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillOccurrenceCard extends ConsumerWidget {
  final BillOccurrenceWithStatus occurrence;

  const _BillOccurrenceCard({required this.occurrence});

  Color _statusColor(BillStatus status) {
    switch (status) {
      case BillStatus.paid:
        return Colors.green;
      case BillStatus.partial:
        return Colors.orange;
      case BillStatus.overdue:
        return Colors.red;
      case BillStatus.unpaid:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(BillStatus status) {
    switch (status) {
      case BillStatus.paid:
        return Icons.check_circle;
      case BillStatus.partial:
        return Icons.timelapse;
      case BillStatus.overdue:
        return Icons.warning_rounded;
      case BillStatus.unpaid:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = occurrence.status;
    final statusColor = _statusColor(status);
    final isPaid = occurrence.isPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: status == BillStatus.overdue
              ? Colors.red.shade300
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: status == BillStatus.overdue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    occurrence.template.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status == BillStatus.partial
                            ? 'Sebagian (${Money.format(occurrence.remainingRp)})'
                            : status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Due Date & Effective Amount
            Row(
              children: [
                Icon(Icons.calendar_month, size: 15, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Jatuh Tempo: ${occurrence.occurrence.dueDate}',
                  style: TextStyle(
                    fontSize: 13,
                    color: status == BillStatus.overdue ? Colors.red : theme.colorScheme.outline,
                    fontWeight: status == BillStatus.overdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Financial Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${Money.format(occurrence.effectiveAmountDueRp)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Terbayar: ${Money.format(occurrence.totalPaidRp)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? Colors.green : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (occurrence.totalPaidRp > 0 && !isPaid) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: occurrence.effectiveAmountDueRp > 0
                      ? (occurrence.totalPaidRp / occurrence.effectiveAmountDueRp)
                      : 0.0,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: Colors.orange,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isPaid) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Bayar Tagihan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => PayBillDialog(occurrenceWithStatus: occurrence),
                      );
                    },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          'Lunas Penuh',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
