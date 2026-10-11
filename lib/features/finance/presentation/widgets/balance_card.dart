import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/money.dart';
import '../providers/finance_providers.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalanceAsync = ref.watch(totalBalanceStreamProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withAlpha(210),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Saldo Aktif',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(220),
                ),
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
          const SizedBox(height: 4),
          totalBalanceAsync.when(
            data: (balance) => Text(
              isVisible ? Money.format(balance) : '••••••••',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            loading: () => const Text(
              'Memuat...',
              style: TextStyle(fontSize: 24, color: Colors.white70),
            ),
            error: (err, stack) => const Text(
              'Rp0',
              style: TextStyle(fontSize: 28, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                label: 'Keluar',
                icon: Icons.arrow_upward_rounded,
                color: Colors.redAccent.shade100,
                onTap: () => context.push('/finance/add?kind=expense'),
              ),
              _ActionButton(
                label: 'Masuk',
                icon: Icons.arrow_downward_rounded,
                color: Colors.tealAccent.shade400,
                onTap: () => context.push('/finance/add?kind=income'),
              ),
              _ActionButton(
                label: 'Transfer',
                icon: Icons.swap_horiz_rounded,
                color: Colors.lightBlueAccent.shade200,
                onTap: () => context.push('/finance/transfer'),
              ),
              _ActionButton(
                label: 'Tabungan',
                icon: Icons.savings_outlined,
                color: Colors.amberAccent.shade200,
                onTap: () => context.push('/finance/savings'),
              ),
            ],
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
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
