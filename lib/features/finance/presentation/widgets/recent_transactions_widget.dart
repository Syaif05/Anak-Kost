import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/app_ui_components.dart';
import '../../../../core/constants/money.dart';
import '../../domain/models/finance_models.dart';
import '../providers/finance_providers.dart';

class RecentTransactionsWidget extends ConsumerWidget {
  final int limit;

  const RecentTransactionsWidget({
    super.key,
    this.limit = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TransactionFilterParams(limit: limit);
    final txListAsync = ref.watch(transactionsStreamProvider(params));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: AppSectionHeader(
            title: 'Transaksi Terakhir',
            actionTitle: 'Terbaru',
          ),
        ),
        const SizedBox(height: 12),
        txListAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          size: 24,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada transaksi',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Catatan transaksi Anda akan muncul di sini',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 16,
                    color: AppTheme.surfaceSecondary,
                  ),
                  itemBuilder: (context, index) {
                    final item = transactions[index];
                    return _TransactionTile(item: item);
                  },
                ),
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final TransactionWithDetails item;

  const _TransactionTile({required this.item});

  void _confirmVoid(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi?'),
        content: Text(
          'Transaksi sebesar ${Money.format(item.transaction.amountRp)} akan dibatalkan (void). '
          'Saldo dompet dan perhitungan budget terkait akan dikembalikan secara atomik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(financeRepositoryProvider);
                await repo.voidTransaction(item.transaction.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaksi berhasil dibatalkan (void)')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membatalkan transaksi: $e')),
                  );
                }
              }
            },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = item.transaction;
    final isVoid = tx.status == 'void';

    IconData icon;
    Color iconColor;
    String title;
    String amountPrefix = '';
    Color amountColor;

    switch (tx.kind) {
      case 'expense':
        icon = Icons.arrow_outward_rounded;
        iconColor = AppTheme.danger;
        title = item.category?.name ?? 'Pengeluaran';
        amountPrefix = '- ';
        amountColor = AppTheme.danger;
        break;
      case 'income':
        icon = Icons.arrow_downward_rounded;
        iconColor = AppTheme.success;
        title = item.category?.name ?? 'Pemasukan';
        amountPrefix = '+ ';
        amountColor = AppTheme.success;
        break;
      case 'transfer':
        icon = Icons.swap_horiz_rounded;
        iconColor = AppTheme.primaryTeal;
        final src = item.primaryWallet?.name ?? 'Dompet';
        final dst = item.destinationWallet?.name ?? 'Tujuan';
        title = 'Transfer: $src → $dst';
        amountColor = AppTheme.primaryTeal;
        break;
      case 'refund':
        icon = Icons.replay_rounded;
        iconColor = AppTheme.warning;
        title = 'Refund: ${item.category?.name ?? ""}';
        amountPrefix = '+ ';
        amountColor = AppTheme.warning;
        break;
      case 'opening':
        icon = Icons.account_balance_wallet_outlined;
        iconColor = AppTheme.primaryTeal;
        title = 'Saldo Awal (${item.primaryWallet?.name ?? ""})';
        amountPrefix = '+ ';
        amountColor = AppTheme.primaryTeal;
        break;
      default:
        icon = Icons.receipt_outlined;
        iconColor = AppTheme.textSecondary;
        title = tx.kind;
        amountColor = AppTheme.textPrimary;
    }

    final dateStr = DateFormat('d MMM yyyy', 'id_ID').format(
      DateTime.fromMillisecondsSinceEpoch(tx.occurredAt),
    );

    final subtitleParts = <String>[dateStr];
    if (tx.merchant != null && tx.merchant!.isNotEmpty) {
      subtitleParts.add(tx.merchant!);
    }
    if (tx.note != null && tx.note!.isNotEmpty) {
      subtitleParts.add(tx.note!);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          decoration: isVoid ? TextDecoration.lineThrough : null,
          color: isVoid ? AppTheme.textSecondary : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitleParts.join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${Money.format(tx.amountRp)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  decoration: isVoid ? TextDecoration.lineThrough : null,
                  color: isVoid ? AppTheme.textSecondary : amountColor,
                ),
              ),
              if (isVoid)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppStatusBadge.error('Dibatalkan'),
                ),
            ],
          ),
          if (!isVoid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'void') {
                  _confirmVoid(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'void',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: AppTheme.danger, size: 18),
                      SizedBox(width: 8),
                      Text('Batalkan (Void)', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

