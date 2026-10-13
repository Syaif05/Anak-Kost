import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/app_ui_components.dart';
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
    final occurrencesAsync = ref.watch(billOccurrencesForPeriodProvider(_periodKey));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Tagihan Kost',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppSquareIconButton(
              icon: Icons.sync_rounded,
              tooltip: 'Sinkronkan Tagihan Bulan Ini',
              onPressed: _generateCurrentMonthOccurrences,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: _openAddTemplateSheet,
          backgroundColor: AppTheme.primaryTeal,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Tambah Tagihan', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: Column(
        children: [
          // Month Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSquareIconButton(
                  icon: Icons.chevron_left_rounded,
                  size: 38,
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                AppSquareIconButton(
                  icon: Icons.chevron_right_rounded,
                  size: 38,
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: occurrencesAsync.when(
              data: (occurrences) {
                // Calculate Totals
                final totalDue = occurrences.fold(0, (sum, o) => sum + o.effectiveAmountDueRp);
                final totalPaid = occurrences.fold(0, (sum, o) => sum + o.totalPaidRp);
                final totalRemaining = occurrences.fold(0, (sum, o) => sum + o.remainingRp);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Tagihan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Money.format(totalDue),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Sisa Belum Bayar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Money.format(totalRemaining),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: totalRemaining > 0 ? AppTheme.error : AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: totalDue > 0 ? (totalPaid / totalDue) : 1.0,
                              minHeight: 8,
                              backgroundColor: AppTheme.surfaceSecondary,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                totalRemaining == 0 ? AppTheme.success : AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Terbayar: ${Money.format(totalPaid)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                totalDue > 0 ? '${((totalPaid / totalDue) * 100).toInt()}%' : '100%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryTeal,
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
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSecondary,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 28,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum Ada Tagihan di Bulan Ini',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Buat template tagihan baru dengan tombol di bawah',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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

  Widget _buildStatusBadge(BillStatus status) {
    switch (status) {
      case BillStatus.paid:
        return AppStatusBadge.success('Lunas Penuh', icon: Icons.check_circle_rounded);
      case BillStatus.partial:
        return AppStatusBadge.warning('Sebagian (${Money.format(occurrence.remainingRp)})', icon: Icons.timelapse_rounded);
      case BillStatus.overdue:
        return AppStatusBadge.error('Terlambat', icon: Icons.warning_amber_rounded);
      case BillStatus.unpaid:
        return AppStatusBadge.neutral('Belum Dibayar', icon: Icons.radio_button_unchecked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = occurrence.status;
    final isPaid = occurrence.isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == BillStatus.overdue ? AppTheme.error.withAlpha(120) : AppTheme.borderColor,
          width: status == BillStatus.overdue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    occurrence.template.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),

            // Due Date
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Jatuh Tempo: ${occurrence.occurrence.dueDate}',
                  style: TextStyle(
                    fontSize: 13,
                    color: status == BillStatus.overdue ? AppTheme.error : AppTheme.textSecondary,
                    fontWeight: status == BillStatus.overdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Financial Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${Money.format(occurrence.effectiveAmountDueRp)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                ),
                Text(
                  'Terbayar: ${Money.format(occurrence.totalPaidRp)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppTheme.success : AppTheme.textSecondary,
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
                  backgroundColor: AppTheme.surfaceSecondary,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warning),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isPaid) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Bayar Tagihan'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      color: AppTheme.successContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 16, color: AppTheme.success),
                        SizedBox(width: 6),
                        Text(
                          'Lunas Penuh',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success),
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
