import '../../../../core/database/app_database.dart';

/// DTO Dompet beserta Saldo Berjalan (berasal dari agregat SUM wallet_entries)
class WalletWithBalance {
  final Wallet wallet;
  final int balanceRp;

  const WalletWithBalance({
    required this.wallet,
    required this.balanceRp,
  });
}

/// DTO Progres Budget Bulanan per Kategori
class BudgetProgress {
  final Budget budget;
  final Category category;
  final int spentRp;

  const BudgetProgress({
    required this.budget,
    required this.category,
    required this.spentRp,
  });

  int get remainingRp => budget.limitRp - spentRp;
  double get percentage => budget.limitRp > 0 ? (spentRp / budget.limitRp) : 0.0;
  double get percentValue => percentage * 100.0;
  bool get isWarning => percentage >= (budget.warningPercent / 100.0) && !isExceeded;
  bool get isExceeded => spentRp > budget.limitRp;
  bool get isWarning80 => isWarning;
  bool get isOverBudget => isExceeded;
}

/// DTO Target Tabungan beserta Akumulasi Alokasi Bersih
class SavingGoalWithProgress {
  final SavingGoal goal;
  final int allocatedRp;

  const SavingGoalWithProgress({
    required this.goal,
    required this.allocatedRp,
  });

  int get remainingRp => (goal.targetRp - allocatedRp) > 0 ? (goal.targetRp - allocatedRp) : 0;
  double get percentage => goal.targetRp > 0 ? (allocatedRp / goal.targetRp) : 0.0;
  double get percentValue => percentage * 100.0;
  bool get isAchieved => allocatedRp >= goal.targetRp;
}

/// DTO Transaksi Lengkap beserta Detail Kategori & Dompet
class TransactionWithDetails {
  final Transaction transaction;
  final Category? category;
  final List<WalletEntry> entries;
  final Wallet? primaryWallet;
  final Wallet? destinationWallet;

  const TransactionWithDetails({
    required this.transaction,
    this.category,
    this.entries = const [],
    this.primaryWallet,
    this.destinationWallet,
  });

  bool get isVoided => transaction.status == 'void';
}
