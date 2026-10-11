import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/finance_dao.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/finance_models.dart';

/// Provider singleton untuk FinanceRepository
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FinanceRepository(db: db);
});

/// Provider DAO Keuangan
final financeDaoProvider = Provider<FinanceDao>((ref) {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.dao;
});

/// Stream saldo total seluruh dompet aktif
final totalBalanceStreamProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchTotalBalance();
});

/// Stream daftar dompet aktif beserta saldonya
final walletsStreamProvider = StreamProvider<List<WalletWithBalance>>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchWalletsWithBalances();
});

/// Stream kategori berdasarkan direction ('expense' | 'income' | null)
final categoriesStreamProvider =
    StreamProvider.family<List<Category>, String?>((ref, direction) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchCategories(direction: direction);
});

/// Stream daftar transaksi dengan detail
final transactionsStreamProvider =
    StreamProvider.family<List<TransactionWithDetails>, TransactionFilterParams>(
        (ref, params) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchTransactions(
    walletId: params.walletId,
    categoryId: params.categoryId,
    monthPrefix: params.monthPrefix,
    limit: params.limit,
  );
});

/// Filter parameter helper untuk query transaksi
class TransactionFilterParams {
  final String? walletId;
  final String? categoryId;
  final String? monthPrefix;
  final int? limit;

  const TransactionFilterParams({
    this.walletId,
    this.categoryId,
    this.monthPrefix,
    this.limit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilterParams &&
          runtimeType == other.runtimeType &&
          walletId == other.walletId &&
          categoryId == other.categoryId &&
          monthPrefix == other.monthPrefix &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(walletId, categoryId, monthPrefix, limit);
}

/// Stream progres budget untuk bulan tertentu (format: 'YYYY-MM-01')
final budgetProgressStreamProvider =
    StreamProvider.family<List<BudgetProgress>, String>((ref, monthStart) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchBudgetProgress(monthStart);
});

/// Stream target tabungan dan progres alokasi
final savingGoalsStreamProvider =
    StreamProvider<List<SavingGoalWithProgress>>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchSavingGoalsWithProgress();
});

/// Notifier untuk toggle visibilitas saldo (Eye On / Off)
class BalanceVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final balanceVisibilityProvider =
    NotifierProvider<BalanceVisibilityNotifier, bool>(BalanceVisibilityNotifier.new);
