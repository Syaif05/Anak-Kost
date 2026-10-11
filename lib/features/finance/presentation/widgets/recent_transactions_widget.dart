import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaksi Terakhir',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Terbaru',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        txListAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada transaksi.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) {
                final item = transactions[index];
                return _TransactionTile(item: item);
              },
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    Color iconBg;
    String title;
    String amountPrefix = '';
    Color amountColor;

    switch (tx.kind) {
      case 'expense':
        icon = Icons.arrow_upward_rounded;
        iconColor = Colors.red;
        iconBg = Colors.red.withAlpha(25);
        title = item.category?.name ?? 'Pengeluaran';
        amountPrefix = '- ';
        amountColor = Colors.red.shade700;
        break;
      case 'income':
        icon = Icons.arrow_downward_rounded;
        iconColor = Colors.teal;
        iconBg = Colors.teal.withAlpha(25);
        title = item.category?.name ?? 'Pemasukan';
        amountPrefix = '+ ';
        amountColor = Colors.teal.shade700;
        break;
      case 'transfer':
        icon = Icons.swap_horiz_rounded;
        iconColor = Colors.blue;
        iconBg = Colors.blue.withAlpha(25);
        final src = item.primaryWallet?.name ?? 'Dompet';
        final dst = item.destinationWallet?.name ?? 'Tujuan';
        title = 'Transfer: $src → $dst';
        amountColor = Colors.blue.shade700;
        break;
      case 'refund':
        icon = Icons.replay_rounded;
        iconColor = Colors.orange;
        iconBg = Colors.orange.withAlpha(25);
        title = 'Refund: ${item.category?.name ?? ""}';
        amountPrefix = '+ ';
        amountColor = Colors.orange.shade800;
        break;
      case 'opening':
        icon = Icons.account_balance_rounded;
        iconColor = Colors.purple;
        iconBg = Colors.purple.withAlpha(25);
        title = 'Saldo Awal (${item.primaryWallet?.name ?? ""})';
        amountPrefix = '+ ';
        amountColor = Colors.purple.shade700;
        break;
      default:
        icon = Icons.receipt_rounded;
        iconColor = Colors.grey;
        iconBg = Colors.grey.withAlpha(25);
        title = tx.kind;
        amountColor = Colors.black;
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
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          decoration: isVoid ? TextDecoration.lineThrough : null,
          color: isVoid ? Colors.grey : null,
        ),
      ),
      subtitle: Text(
        subtitleParts.join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isVoid ? Colors.grey.shade400 : Colors.grey.shade600,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: isVoid ? TextDecoration.lineThrough : null,
                  color: isVoid ? Colors.grey : amountColor,
                ),
              ),
              if (isVoid)
                const Text(
                  'Dibatalkan',
                  style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          if (!isVoid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
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
                      Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Batalkan (Void)', style: TextStyle(color: Colors.red)),
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
