import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/app_ui_components.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSectionHeader(
            title: 'Daftar Dompet',
            onSeeAll: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (ctx) => const AddWalletSheet(),
              );
            },
            seeAllText: '+ Tambah',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 114,
          child: walletsAsync.when(
            data: (wallets) {
              if (wallets.isEmpty) {
                return const Center(
                  child: Text(
                    'Belum ada dompet. Tambahkan dompet pertama Anda!',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
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
      width: 172,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceSecondary
                      : AppTheme.primaryTealContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, size: 17, color: AppTheme.primaryTeal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
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
                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isVisible ? Money.format(item.balanceRp) : '••••••',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: -0.2,
                  color: item.balanceRp < 0
                      ? AppTheme.error
                      : isDark
                          ? Colors.white
                          : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
