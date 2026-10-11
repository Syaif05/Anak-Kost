import 'package:drift/drift.dart';
import 'common_columns.dart';

/// Barang Inventaris Kebutuhan Kost (GAMINI.md Bagian 6.3)
class InventoryItems extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  TextColumn get stockCategory => text().nullable()();
  TextColumn get baseUnit => text().withDefault(const Constant('pcs'))(); // pcs, g, ml, dll
  IntColumn get minimumQtyMilli => integer().withDefault(const Constant(0))(); // milli-unit (1 unit = 1000)
  TextColumn get locationLabel => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

/// Mutasi Stok Barang Append-Only (GAMINI.md Bagian 6.3)
class InventoryMovements extends Table with CommonDomainColumns {
  TextColumn get inventoryItemId => text()();
  TextColumn get movementType => text()(); // opening, add, use, adjust, reversal
  IntColumn get quantityDeltaMilli => integer()(); // positif untuk tambah, negatif untuk pakai
  IntColumn get occurredAt => integer()(); // epoch millis UTC
  TextColumn get transactionItemId => text().nullable()();
  TextColumn get purchaseId => text().nullable()();
  TextColumn get reversesId => text().nullable()();
  TextColumn get reason => text().nullable()();
}

/// Daftar Rencana Belanja (GAMINI.md Bagian 6.3)
class ShoppingLists extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('open'))(); // open, completed, archived
  TextColumn get plannedDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get storeHint => text().nullable()();
}

/// Item dalam Daftar Belanja (GAMINI.md Bagian 6.3)
class ShoppingListItems extends Table with CommonDomainColumns {
  TextColumn get shoppingListId => text()();
  TextColumn get inventoryItemId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get requestedQtyMilli => integer()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  IntColumn get estimatedTotalRp => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, bought, skipped
  TextColumn get note => text().nullable()();
}

/// Header Checkout Pembelian Belanja (GAMINI.md Bagian 6.3)
class ShoppingPurchases extends Table with CommonDomainColumns {
  TextColumn get shoppingListId => text().nullable()();
  TextColumn get transactionId => text().nullable()();
  IntColumn get purchasedAt => integer()(); // epoch millis UTC
  TextColumn get storeName => text().nullable()();
}

/// Item Aktual Hasil Pembelian Belanja (GAMINI.md Bagian 6.3)
class ShoppingPurchaseItems extends Table with CommonDomainColumns {
  TextColumn get purchaseId => text()();
  TextColumn get shoppingListItemId => text().nullable()();
  TextColumn get inventoryItemId => text().nullable()();
  IntColumn get quantityBaseMilli => integer()();
  IntColumn get totalPaidRp => integer().nullable()();
  BoolColumn get addToStock => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();
}

/// Riwayat Observasi Harga Barang (GAMINI.md Bagian 6.3)
class PriceHistory extends Table with CommonDomainColumns {
  TextColumn get inventoryItemId => text()();
  TextColumn get purchaseItemId => text().nullable()();
  TextColumn get transactionItemId => text().nullable()();
  IntColumn get quantityBaseMilli => integer()();
  IntColumn get totalPriceRp => integer()();
  TextColumn get storeName => text().nullable()();
  TextColumn get observedOn => text()(); // YYYY-MM-DD
  TextColumn get source => text().withDefault(const Constant('purchase'))(); // purchase, manual, receipt
}
