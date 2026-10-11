import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/inventory_dao.dart';
import '../../data/inventory_repository.dart';
import '../../domain/models/inventory_models.dart';

/// Provider singleton untuk InventoryRepository
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return InventoryRepository(db: db, notificationService: notif);
});

/// Provider DAO Inventaris
final inventoryDaoProvider = Provider<InventoryDao>((ref) {
  return ref.watch(inventoryRepositoryProvider).dao;
});

/// Stream daftar barang inventaris beserta stok terhitung (STK02)
final inventoryItemsStreamProvider =
    StreamProvider.family<List<InventoryItemWithStock>, String?>((ref, category) {
  return ref.watch(inventoryDaoProvider).watchInventoryItemsWithStock(stockCategory: category);
});

/// Stream daftar rencana belanja (STK01)
final shoppingListsStreamProvider = StreamProvider<List<ShoppingListWithItems>>((ref) {
  return ref.watch(inventoryDaoProvider).watchShoppingLists();
});

/// Stream item belanja untuk daftar tertentu
final shoppingListItemsStreamProvider =
    StreamProvider.family<List<ShoppingListItem>, String>((ref, listId) {
  return ref.watch(inventoryDaoProvider).watchShoppingListItems(listId);
});

/// Stream riwayat observasi harga barang tertentu (STK05)
final priceHistoryStreamProvider =
    StreamProvider.family<List<PriceHistoryData>, String>((ref, itemId) {
  return ref.watch(inventoryDaoProvider).watchPriceHistory(itemId);
});
