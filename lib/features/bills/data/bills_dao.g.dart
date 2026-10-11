// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bills_dao.dart';

// ignore_for_file: type=lint
mixin _$BillsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BillTemplatesTable get billTemplates => attachedDatabase.billTemplates;
  $BillOccurrencesTable get billOccurrences => attachedDatabase.billOccurrences;
  $BillPaymentsTable get billPayments => attachedDatabase.billPayments;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $CategoriesTable get categories => attachedDatabase.categories;
  BillsDaoManager get managers => BillsDaoManager(this);
}

class BillsDaoManager {
  final _$BillsDaoMixin _db;
  BillsDaoManager(this._db);
  $$BillTemplatesTableTableManager get billTemplates =>
      $$BillTemplatesTableTableManager(_db.attachedDatabase, _db.billTemplates);
  $$BillOccurrencesTableTableManager get billOccurrences =>
      $$BillOccurrencesTableTableManager(
        _db.attachedDatabase,
        _db.billOccurrences,
      );
  $$BillPaymentsTableTableManager get billPayments =>
      $$BillPaymentsTableTableManager(_db.attachedDatabase, _db.billPayments);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
}
