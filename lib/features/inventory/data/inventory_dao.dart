import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/inventory_tables.dart';
import '../domain/models/inventory_models.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [
  InventoryItems,
  InventoryMovements,
  ShoppingLists,
  ShoppingListItems,
  ShoppingPurchases,
  ShoppingPurchaseItems,
  PriceHistory,
])
class InventoryDao extends DatabaseAccessor<AppDatabase> with _$InventoryDaoMixin {
  InventoryDao(super.db);

  /// Stream daftar barang inventaris beserta stok terhitung saat ini (STK02)
  Stream<List<InventoryItemWithStock>> watchInventoryItemsWithStock({String? stockCategory}) {
    final query = select(inventoryItems)
      ..where((t) => t.isArchived.equals(false) & t.deletedAt.isNull());
    if (stockCategory != null) {
      query.where((t) => t.stockCategory.equals(stockCategory));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);

    return query.watch().asyncMap((items) async {
      final result = <InventoryItemWithStock>[];
      for (final item in items) {
        final stock = await getItemStockMilli(item.id);
        result.add(InventoryItemWithStock(item: item, currentStockMilli: stock));
      }
      return result;
    });
  }

  /// Menghitung stok saat ini (dalam integer milli-unit) dari SUM(quantity_delta_milli)
  /// Sesuai Aturan Bisnis GAMINI.md Bagian 3.3 (Append-only Ledger)
  Future<int> getItemStockMilli(String itemId) async {
    final movements = await (select(inventoryMovements)
          ..where((m) => m.inventoryItemId.equals(itemId) & m.deletedAt.isNull()))
        .get();

    return movements.fold<int>(0, (sum, m) => sum + m.quantityDeltaMilli);
  }

  /// Mengambil single item beserta stok
  Future<InventoryItemWithStock?> getItemWithStock(String itemId) async {
    final item = await (select(inventoryItems)
          ..where((t) => t.id.equals(itemId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (item == null) return null;

    final stock = await getItemStockMilli(itemId);
    return InventoryItemWithStock(item: item, currentStockMilli: stock);
  }

  /// Stream daftar rencana belanja beserta seluruh itemnya (STK01)
  Stream<List<ShoppingListWithItems>> watchShoppingLists() {
    return (select(shoppingLists)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch()
        .asyncMap((lists) async {
      final result = <ShoppingListWithItems>[];
      for (final list in lists) {
        final items = await (select(shoppingListItems)
              ..where((i) => i.shoppingListId.equals(list.id) & i.deletedAt.isNull())
              ..orderBy([(i) => OrderingTerm(expression: i.name)]))
            .get();
        result.add(ShoppingListWithItems(list: list, items: items));
      }
      return result;
    });
  }

  /// Stream seluruh item pada suatu daftar belanja
  Stream<List<ShoppingListItem>> watchShoppingListItems(String listId) {
    return (select(shoppingListItems)
          ..where((i) => i.shoppingListId.equals(listId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm(expression: i.name)]))
        .watch();
  }

  /// Stream riwayat observasi harga barang tertentu (STK05)
  Stream<List<PriceHistoryData>> watchPriceHistory(String itemId) {
    return (select(priceHistory)
          ..where((p) => p.inventoryItemId.equals(itemId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm(expression: p.observedOn, mode: OrderingMode.desc)]))
        .watch();
  }
}
