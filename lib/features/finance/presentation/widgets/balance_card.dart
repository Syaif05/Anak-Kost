import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/money.dart';
import '../providers/finance_providers.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalanceAsync = ref.watch(totalBalanceStreamProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: const Color(0xFF134553),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28062F3B),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6ED1B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total Saldo Aktif',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(210),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white.withAlpha(220),
                  size: 20,
                ),
                onPressed: () {
                  ref.read(balanceVisibilityProvider.notifier).toggle();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          totalBalanceAsync.when(
            data: (balance) => Text(
              isVisible ? Money.format(balance) : '••••••••',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            loading: () => const Text(
              'Memuat...',
              style: TextStyle(fontSize: 24, color: Colors.white70),
            ),
            error: (err, stack) => const Text(
              'Rp0',
              style: TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  label: 'Keluar',
                  icon: Icons.arrow_outward_rounded,
                  color: const Color(0xFFFF8A80),
                  onTap: () => context.push('/finance/add?kind=expense'),
                ),
                _ActionButton(
                  label: 'Masuk',
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF6ED1B8),
                  onTap: () => context.push('/finance/add?kind=income'),
                ),
                _ActionButton(
                  label: 'Transfer',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF90CAF9),
                  onTap: () => context.push('/finance/transfer'),
                ),
                _ActionButton(
                  label: 'Tabungan',
                  icon: Icons.savings_outlined,
                  color: const Color(0xFFFFE082),
                  onTap: () => context.push('/finance/savings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
