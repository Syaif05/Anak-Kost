// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_dao.dart';

// ignore_for_file: type=lint
mixin _$FinanceDaoMixin on DatabaseAccessor<AppDatabase> {
  $WalletsTable get wallets => attachedDatabase.wallets;
  $CategoriesTable get categories => attachedDatabase.categories;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $WalletEntriesTable get walletEntries => attachedDatabase.walletEntries;
  $TransactionItemsTable get transactionItems =>
      attachedDatabase.transactionItems;
  $BudgetsTable get budgets => attachedDatabase.budgets;
  $SavingGoalsTable get savingGoals => attachedDatabase.savingGoals;
  $SavingAllocationsTable get savingAllocations =>
      attachedDatabase.savingAllocations;
  FinanceDaoManager get managers => FinanceDaoManager(this);
}

class FinanceDaoManager {
  final _$FinanceDaoMixin _db;
  FinanceDaoManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db.attachedDatabase, _db.wallets);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$WalletEntriesTableTableManager get walletEntries =>
      $$WalletEntriesTableTableManager(_db.attachedDatabase, _db.walletEntries);
  $$TransactionItemsTableTableManager get transactionItems =>
      $$TransactionItemsTableTableManager(
        _db.attachedDatabase,
        _db.transactionItems,
      );
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db.attachedDatabase, _db.budgets);
  $$SavingGoalsTableTableManager get savingGoals =>
      $$SavingGoalsTableTableManager(_db.attachedDatabase, _db.savingGoals);
  $$SavingAllocationsTableTableManager get savingAllocations =>
      $$SavingAllocationsTableTableManager(
        _db.attachedDatabase,
        _db.savingAllocations,
      );
}
