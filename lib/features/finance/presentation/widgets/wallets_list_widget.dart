import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/money.dart';
import '../../domain/models/finance_models.dart';
import '../providers/finance_providers.dart';
import 'add_wallet_sheet.dart';

class WalletsListWidget extends ConsumerWidget {
  const WalletsListWidget({super.key});

  IconData _getWalletIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return Icons.account_balance_outlined;
      case 'ewallet':
        return Icons.account_balance_wallet_outlined;
      case 'cash':
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsStreamProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Dompet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (ctx) => const AddWalletSheet(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: walletsAsync.when(
            data: (wallets) {
              if (wallets.isEmpty) {
                return Center(
                  child: Text(
                    'Belum ada dompet. Tambahkan dompet pertama Anda!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: wallets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = wallets[index];
                  return _WalletCard(
                    item: item,
                    isVisible: isVisible,
                    icon: _getWalletIcon(item.wallet.walletType),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletWithBalance item;
  final bool isVisible;
  final IconData icon;

  const _WalletCard({
    required this.item,
    required this.isVisible,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isVisible ? Money.format(item.balanceRp) : '••••••',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: item.balanceRp < 0 ? Colors.red : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
