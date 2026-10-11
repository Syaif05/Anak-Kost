// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_dao.dart';

// ignore_for_file: type=lint
mixin _$InventoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $InventoryItemsTable get inventoryItems => attachedDatabase.inventoryItems;
  $InventoryMovementsTable get inventoryMovements =>
      attachedDatabase.inventoryMovements;
  $ShoppingListsTable get shoppingLists => attachedDatabase.shoppingLists;
  $ShoppingListItemsTable get shoppingListItems =>
      attachedDatabase.shoppingListItems;
  $ShoppingPurchasesTable get shoppingPurchases =>
      attachedDatabase.shoppingPurchases;
  $ShoppingPurchaseItemsTable get shoppingPurchaseItems =>
      attachedDatabase.shoppingPurchaseItems;
  $PriceHistoryTable get priceHistory => attachedDatabase.priceHistory;
  InventoryDaoManager get managers => InventoryDaoManager(this);
}

class InventoryDaoManager {
  final _$InventoryDaoMixin _db;
  InventoryDaoManager(this._db);
  $$InventoryItemsTableTableManager get inventoryItems =>
      $$InventoryItemsTableTableManager(
        _db.attachedDatabase,
        _db.inventoryItems,
      );
  $$InventoryMovementsTableTableManager get inventoryMovements =>
      $$InventoryMovementsTableTableManager(
        _db.attachedDatabase,
        _db.inventoryMovements,
      );
  $$ShoppingListsTableTableManager get shoppingLists =>
      $$ShoppingListsTableTableManager(_db.attachedDatabase, _db.shoppingLists);
  $$ShoppingListItemsTableTableManager get shoppingListItems =>
      $$ShoppingListItemsTableTableManager(
        _db.attachedDatabase,
        _db.shoppingListItems,
      );
  $$ShoppingPurchasesTableTableManager get shoppingPurchases =>
      $$ShoppingPurchasesTableTableManager(
        _db.attachedDatabase,
        _db.shoppingPurchases,
      );
  $$ShoppingPurchaseItemsTableTableManager get shoppingPurchaseItems =>
      $$ShoppingPurchaseItemsTableTableManager(
        _db.attachedDatabase,
        _db.shoppingPurchaseItems,
      );
  $$PriceHistoryTableTableManager get priceHistory =>
      $$PriceHistoryTableTableManager(_db.attachedDatabase, _db.priceHistory);
}
