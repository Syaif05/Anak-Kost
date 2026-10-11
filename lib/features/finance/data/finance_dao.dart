import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/finance_tables.dart';
import '../domain/models/finance_models.dart';

part 'finance_dao.g.dart';

@DriftAccessor(tables: [
  Wallets,
  Categories,
  Transactions,
  WalletEntries,
  TransactionItems,
  Budgets,
  SavingGoals,
  SavingAllocations,
])
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(super.db);

  /// Menghitung saldo untuk satu dompet tertentu
  /// saldo_dompet = SUM(wallet_entries.amount_rp) dari transaksi aktif (status = 'posted', deleted_at is null)
  Future<int> getWalletBalance(String walletId) async {
    final query = select(walletEntries).join([
      innerJoin(transactions, transactions.id.equalsExp(walletEntries.transactionId)),
    ])
      ..where(walletEntries.walletId.equals(walletId))
      ..where(transactions.status.equals('posted'))
      ..where(transactions.deletedAt.isNull())
      ..where(walletEntries.deletedAt.isNull());

    final amountSum = walletEntries.amountRp.sum();
    query.addColumns([amountSum]);

    final row = await query.getSingleOrNull();
    return row?.read(amountSum) ?? 0;
  }

  /// Menghitung saldo total seluruh dompet aktif
  Stream<int> watchTotalBalance() {
    final query = select(walletEntries).join([
      innerJoin(transactions, transactions.id.equalsExp(walletEntries.transactionId)),
      innerJoin(wallets, wallets.id.equalsExp(walletEntries.walletId)),
    ])
      ..where(wallets.isArchived.equals(false))
      ..where(wallets.deletedAt.isNull())
      ..where(transactions.status.equals('posted'))
      ..where(transactions.deletedAt.isNull())
      ..where(walletEntries.deletedAt.isNull());

    final amountSum = walletEntries.amountRp.sum();
    query.addColumns([amountSum]);

    return query.watchSingleOrNull().map((row) => row?.read(amountSum) ?? 0);
  }

  /// Stream seluruh dompet aktif beserta saldo berjalan masing-masing
  Stream<List<WalletWithBalance>> watchWalletsWithBalances() {
    final walletsQuery = select(wallets)
      ..where((t) => t.isArchived.equals(false) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.name)]);

    return walletsQuery.watch().asyncMap((walletList) async {
      final result = <WalletWithBalance>[];
      for (final w in walletList) {
        final bal = await getWalletBalance(w.id);
        result.add(WalletWithBalance(wallet: w, balanceRp: bal));
      }
      return result;
    });
  }

  /// Stream daftar kategori (opsional filter direction: 'income' / 'expense')
  Stream<List<Category>> watchCategories({String? direction}) {
    final q = select(categories)..where((t) => t.isArchived.equals(false) & t.deletedAt.isNull());
    if (direction != null) {
      q.where((t) => t.direction.equals(direction));
    }
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.watch();
  }

  /// Stream daftar transaksi lengkap dengan detail kategori & dompet
  Stream<List<TransactionWithDetails>> watchTransactions({
    String? walletId,
    String? categoryId,
    String? monthPrefix, // e.g. "2026-10"
    int? limit,
  }) {
    final query = select(transactions).join([
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);

    query.where(transactions.deletedAt.isNull());

    if (categoryId != null) {
      query.where(transactions.categoryId.equals(categoryId));
    }

    if (monthPrefix != null) {
      query.where(transactions.localDate.like('$monthPrefix%'));
    }

    query.orderBy([
      OrderingTerm(expression: transactions.occurredAt, mode: OrderingMode.desc),
    ]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.watch().asyncMap((rows) async {
      final list = <TransactionWithDetails>[];
      for (final row in rows) {
        final tx = row.readTable(transactions);
        final cat = row.readTableOrNull(categories);

        // Ambil entries untuk transaksi ini
        final entries = await (select(walletEntries)
              ..where((t) => t.transactionId.equals(tx.id) & t.deletedAt.isNull()))
            .get();

        // Jika ada filter walletId dan transaksi tidak melibatkan wallet ini, skip
        if (walletId != null && !entries.any((e) => e.walletId == walletId)) {
          continue;
        }

        // Cari dompet utama dan tujuan jika transfer
        Wallet? primaryW;
        Wallet? destW;

        if (entries.isNotEmpty) {
          final mainEntry = entries.firstWhere(
            (e) => e.entryRole == 'main' || e.entryRole == 'source',
            orElse: () => entries.first,
          );
          primaryW = await (select(wallets)..where((t) => t.id.equals(mainEntry.walletId))).getSingleOrNull();

          final destEntry = entries.where((e) => e.entryRole == 'destination').firstOrNull;
          if (destEntry != null) {
            destW = await (select(wallets)..where((t) => t.id.equals(destEntry.walletId))).getSingleOrNull();
          }
        }

        list.add(TransactionWithDetails(
          transaction: tx,
          category: cat,
          entries: entries,
          primaryWallet: primaryW,
          destinationWallet: destW,
        ));
      }
      return list;
    });
  }

  /// Menghitung pengeluaran riil untuk satu kategori dalam bulan berjalan
  /// penggunaan_budget = pengeluaran kategori - refund terkait pada bulan lokal transaksi
  Future<int> getCategoryExpenseForMonth(String categoryId, String monthStart) async {
    // monthStart adalah "YYYY-MM-01", ambil prefix "YYYY-MM"
    final monthPrefix = monthStart.substring(0, 7);

    // 1. Total pengeluaran (expense) kategori ini pada bulan terkait
    final expenseQuery = select(transactions)
      ..where((t) =>
          t.categoryId.equals(categoryId) &
          t.kind.equals('expense') &
          t.status.equals('posted') &
          t.localDate.like('$monthPrefix%') &
          t.deletedAt.isNull());

    final expenseRows = await expenseQuery.get();
    var totalExpense = 0;
    for (final e in expenseRows) {
      totalExpense += e.amountRp;
    }

    // 2. Total refund kategori ini pada bulan terkait
    final refundQuery = select(transactions)
      ..where((t) =>
          t.categoryId.equals(categoryId) &
          t.kind.equals('refund') &
          t.status.equals('posted') &
          t.localDate.like('$monthPrefix%') &
          t.deletedAt.isNull());

    final refundRows = await refundQuery.get();
    var totalRefund = 0;
    for (final r in refundRows) {
      totalRefund += r.amountRp;
    }

    final netSpent = totalExpense - totalRefund;
    return netSpent > 0 ? netSpent : 0;
  }

  /// Stream progres seluruh budget bulan berjalan
  Stream<List<BudgetProgress>> watchBudgetProgress(String monthStart) {
    final query = select(budgets).join([
      innerJoin(categories, categories.id.equalsExp(budgets.categoryId)),
    ])
      ..where(budgets.monthStart.equals(monthStart))
      ..where(budgets.deletedAt.isNull());

    return query.watch().asyncMap((rows) async {
      final result = <BudgetProgress>[];
      for (final row in rows) {
        final b = row.readTable(budgets);
        final c = row.readTable(categories);
        final spent = await getCategoryExpenseForMonth(b.categoryId, monthStart);
        result.add(BudgetProgress(budget: b, category: c, spentRp: spent));
      }
      return result;
    });
  }

  /// Menghitung total alokasi tabungan untuk satu target
  Future<int> getSavingGoalAllocation(String goalId) async {
    final query = select(savingAllocations)
      ..where((t) => t.goalId.equals(goalId) & t.reversesId.isNull() & t.deletedAt.isNull());

    final rows = await query.get();
    var total = 0;
    for (final r in rows) {
      total += r.amountRp; // positif = alokasi, negatif = penarikan
    }
    return total > 0 ? total : 0;
  }

  /// Stream target tabungan beserta progres alokasi
  Stream<List<SavingGoalWithProgress>> watchSavingGoalsWithProgress() {
    final query = select(savingGoals)
      ..where((t) => t.isArchived.equals(false) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);

    return query.watch().asyncMap((goals) async {
      final result = <SavingGoalWithProgress>[];
      for (final g in goals) {
        final alloc = await getSavingGoalAllocation(g.id);
        result.add(SavingGoalWithProgress(goal: g, allocatedRp: alloc));
      }
      return result;
    });
  }
}
