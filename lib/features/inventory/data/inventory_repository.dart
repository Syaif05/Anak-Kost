import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/models/inventory_models.dart';
import 'inventory_dao.dart';

class InventoryRepository {
  final AppDatabase _db;
  final InventoryDao _dao;
  final NotificationService _notificationService;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  InventoryRepository({
    required AppDatabase db,
    InventoryDao? dao,
    NotificationService? notificationService,
    FlutterSecureStorage? secureStorage,
  })  : _db = db,
        _dao = dao ?? InventoryDao(db),
        _notificationService = notificationService ?? NotificationService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  InventoryDao get dao => _dao;

  Future<String> _getDeviceId() async {
    var id = await _secureStorage.read(key: AppConstants.secKeyDeviceId);
    if (id == null) {
      id = _uuid.v4();
      await _secureStorage.write(key: AppConstants.secKeyDeviceId, value: id);
    }
    return id;
  }

  Future<String> _getUserId() async {
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    return profile?.id ?? '00000000-0000-0000-0000-000000000001';
  }

  /// 1. Tambah Barang Inventaris Baru (STK02)
  Future<String> createItem({
    required String name,
    String? stockCategory,
    String baseUnit = 'pcs',
    int minimumQtyMilli = 0,
    String? locationLabel,
    int initialQtyMilli = 0,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final itemId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.inventoryItems).insert(
            InventoryItemsCompanion.insert(
              id: itemId,
              userId: userId,
              name: name,
              stockCategory: Value(stockCategory),
              baseUnit: Value(baseUnit),
              minimumQtyMilli: Value(minimumQtyMilli),
              locationLabel: Value(locationLabel),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // Jika ada stok awal, catat mutasi pembuka (opening)
      if (initialQtyMilli > 0) {
        final movId = _uuid.v4();
        await _db.into(_db.inventoryMovements).insert(
              InventoryMovementsCompanion.insert(
                id: movId,
                userId: userId,
                inventoryItemId: itemId,
                movementType: 'opening',
                quantityDeltaMilli: initialQtyMilli,
                occurredAt: now,
                reason: const Value('Stok awal saat pencatatan'),
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );
      }

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'inventory_item',
              aggregateId: itemId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'name': name,
                'base_unit': baseUnit,
                'minimum_qty_milli': minimumQtyMilli,
                'initial_qty_milli': initialQtyMilli,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return itemId;
  }

  /// 2. Catat Mutasi Stok Barang (STK03 & Gate Pencegahan Stok Negatif)
  /// Aturan Bisnis: Pemakaian tidak boleh menghasilkan stok negatif (harus koreksi eksplisit jika kenyataan berbeda)
  Future<String> recordMovement({
    required String itemId,
    required String movementType, // 'add', 'use', 'adjust', 'reversal'
    required int quantityDeltaMilli,
    String? reason,
  }) async {
    if (quantityDeltaMilli == 0) {
      throw ArgumentError('Perubahan kuantitas tidak boleh 0');
    }

    final itemWithStock = await _dao.getItemWithStock(itemId);
    if (itemWithStock == null) {
      throw ArgumentError('Barang inventaris tidak ditemukan');
    }

    // Pastikan pemakaian bernilai negatif
    var effectiveDelta = quantityDeltaMilli;
    if (movementType == 'use' && effectiveDelta > 0) {
      effectiveDelta = -effectiveDelta;
    }

    // Gate Kritis: Pencegahan Stok Negatif
    final currentStock = itemWithStock.currentStockMilli;
    final resultingStock = currentStock + effectiveDelta;
    if (resultingStock < 0) {
      throw StateError(
        'Penggunaan stok melebihi stok yang tersedia (sisa: ${itemWithStock.formattedCurrentStock}, pemakaian: ${StockUnit.format(-effectiveDelta, itemWithStock.item.baseUnit)}). Koreksi stok eksplisit diperlukan.',
      );
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final movId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              id: movId,
              userId: userId,
              inventoryItemId: itemId,
              movementType: movementType,
              quantityDeltaMilli: effectiveDelta,
              occurredAt: now,
              reason: Value(reason),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'inventory_movement',
              aggregateId: movId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'inventory_item_id': itemId,
                'movement_type': movementType,
                'quantity_delta_milli': effectiveDelta,
                'reason': reason,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    // Pengingat Stok Minimum (STK04)
    if (resultingStock <= itemWithStock.item.minimumQtyMilli) {
      try {
        final notifId = _notificationService.generateId(itemId);
        await _notificationService.showNotification(
          id: notifId,
          channelId: NotificationService.channelStock,
          title: 'Stok Menipis: ${itemWithStock.item.name}',
          body: 'Sisa stok: ${StockUnit.format(resultingStock, itemWithStock.item.baseUnit)}. Segera tambahkan ke daftar belanja.',
        );
      } catch (_) {}
    }

    return movId;
  }

  /// 3. Buat Daftar Belanja (STK01)
  Future<String> createShoppingList({
    required String name,
    String? plannedDate,
    String? storeHint,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final listId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.shoppingLists).insert(
          ShoppingListsCompanion.insert(
            id: listId,
            userId: userId,
            name: name,
            plannedDate: Value(plannedDate),
            storeHint: Value(storeHint),
            status: const Value('open'),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return listId;
  }

  /// 4. Tambah Item ke Daftar Belanja (STK01)
  Future<String> addShoppingListItem({
    required String shoppingListId,
    String? inventoryItemId,
    required String name,
    required int requestedQtyMilli,
    String unit = 'pcs',
    int? estimatedTotalRp,
    String? note,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final itemId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.shoppingListItems).insert(
          ShoppingListItemsCompanion.insert(
            id: itemId,
            userId: userId,
            shoppingListId: shoppingListId,
            inventoryItemId: Value(inventoryItemId),
            name: name,
            requestedQtyMilli: requestedQtyMilli,
            unit: Value(unit),
            estimatedTotalRp: Value(estimatedTotalRp),
            status: const Value('pending'),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return itemId;
  }

  /// 5. Checkout Pembelian Belanja Terintegrasi (STK06 & Gate Test T04)
  /// Secara ATOMIK dalam 1 transaksi DB:
  /// - Mencatat transaksi pengeluaran keuangan dan mutasi dompet
  /// - Mencatat shopping_purchases & shopping_purchase_items
  /// - Menambah stok barang pada inventory_movements
  /// - Menyimpan riwayat harga barang pada price_history
  /// - Mengupdate status shopping_list_items menjadi 'bought'
  /// - Mencatat seluruh operasi ke sync_outbox
  Future<String> checkoutShoppingList({
    String? shoppingListId,
    required String walletId,
    required String expenseCategoryId,
    required List<CheckoutItemInput> items,
    required String localDate,
    String? storeName,
    String? note,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Daftar item belanja yang dibeli tidak boleh kosong');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final now = DateTime.now().millisecondsSinceEpoch;

    final purchaseId = _uuid.v4();
    final txId = _uuid.v4();
    final opId = _uuid.v4();

    final grandTotalPaidRp = items.fold<int>(0, (sum, i) => sum + i.totalPaidRp);

    await _db.transaction(() async {
      // a. Catat Transaksi Pengeluaran Keuangan (FIN)
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              categoryId: Value(expenseCategoryId),
              amountRp: grandTotalPaidRp,
              kind: 'expense',
              occurredAt: now,
              localDate: localDate,
              status: const Value('posted'),
              note: Value(note ?? 'Belanja ${items.length} barang di ${storeName ?? 'Toko'}'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // b. Catat Mutasi Pengurangan Saldo Dompet
      await _db.into(_db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              walletId: walletId,
              transactionId: txId,
              entryRole: 'main',
              amountRp: -grandTotalPaidRp,
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // c. Catat Header Pembelian Belanja
      await _db.into(_db.shoppingPurchases).insert(
            ShoppingPurchasesCompanion.insert(
              id: purchaseId,
              userId: userId,
              shoppingListId: Value(shoppingListId),
              transactionId: Value(txId),
              purchasedAt: now,
              storeName: Value(storeName),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // d. Catat Tiap Item Pembelian, Tambah Stok & Simpan Histori Harga
      for (final item in items) {
        final purchaseItemId = _uuid.v4();

        await _db.into(_db.shoppingPurchaseItems).insert(
              ShoppingPurchaseItemsCompanion.insert(
                id: purchaseItemId,
                userId: userId,
                purchaseId: purchaseId,
                shoppingListItemId: Value(item.shoppingListItemId),
                inventoryItemId: Value(item.inventoryItemId),
                quantityBaseMilli: item.quantityBaseMilli,
                totalPaidRp: Value(item.totalPaidRp),
                addToStock: Value(item.addToStock),
                note: Value(item.itemName),
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );

        // Tambah Stok Inventaris jika barang terhubung dan addToStock = true
        if (item.addToStock && item.inventoryItemId != null) {
          await _db.into(_db.inventoryMovements).insert(
                InventoryMovementsCompanion.insert(
                  id: _uuid.v4(),
                  userId: userId,
                  inventoryItemId: item.inventoryItemId!,
                  movementType: 'add',
                  quantityDeltaMilli: item.quantityBaseMilli,
                  occurredAt: now,
                  purchaseId: Value(purchaseId),
                  reason: Value('Pembelian dari ${storeName ?? 'Toko'}'),
                  createdAt: now,
                  updatedAt: now,
                  lastOperationId: opId,
                  originDeviceId: deviceId,
                ),
              );
        }

        // Catat Histori Harga Barang jika terhubung ke inventaris
        if (item.inventoryItemId != null && item.totalPaidRp > 0) {
          await _db.into(_db.priceHistory).insert(
                PriceHistoryCompanion.insert(
                  id: _uuid.v4(),
                  userId: userId,
                  inventoryItemId: item.inventoryItemId!,
                  purchaseItemId: Value(purchaseItemId),
                  quantityBaseMilli: item.quantityBaseMilli,
                  totalPriceRp: item.totalPaidRp,
                  storeName: Value(storeName),
                  observedOn: localDate,
                  source: const Value('purchase'),
                  createdAt: now,
                  updatedAt: now,
                  lastOperationId: opId,
                  originDeviceId: deviceId,
                ),
              );
        }

        // Tandai status shopping_list_item menjadi 'bought'
        if (item.shoppingListItemId != null) {
          await (_db.update(_db.shoppingListItems)
                ..where((s) => s.id.equals(item.shoppingListItemId!)))
              .write(
            ShoppingListItemsCompanion(
              status: const Value('bought'),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // e. Jika daftar belanja terhubung, periksa apakah seluruh item sudah selesai
      if (shoppingListId != null) {
        final remainingPending = await (_db.select(_db.shoppingListItems)
              ..where((s) => s.shoppingListId.equals(shoppingListId) & s.status.equals('pending') & s.deletedAt.isNull()))
            .get();

        if (remainingPending.isEmpty) {
          await (_db.update(_db.shoppingLists)..where((s) => s.id.equals(shoppingListId))).write(
            ShoppingListsCompanion(
              status: const Value('completed'),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // f. Simpan Catatan Sinkronisasi Outbox
      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'shopping_purchase',
              aggregateId: purchaseId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'purchase_id': purchaseId,
                'transaction_id': txId,
                'grand_total_rp': grandTotalPaidRp,
                'item_count': items.length,
                'local_date': localDate,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return purchaseId;
  }

  /// 6. Inisialisasi Data Barang Default Kost Jika Kosong
  Future<void> seedDefaultInventoryIfEmpty() async {
    final existing = await (_db.select(_db.inventoryItems)..where((t) => t.deletedAt.isNull())).get();
    if (existing.isEmpty) {
      await createItem(
        name: 'Beras Super',
        stockCategory: 'Makanan Pokok',
        baseUnit: 'g',
        minimumQtyMilli: 1000000, // 1 kg
        initialQtyMilli: 5000000, // 5 kg
      );
      await createItem(
        name: 'Minyak Goreng',
        stockCategory: 'Bahan Masak',
        baseUnit: 'ml',
        minimumQtyMilli: 500000, // 500 ml
        initialQtyMilli: 2000000, // 2 Liter
      );
      await createItem(
        name: 'Sabun Mandi',
        stockCategory: 'Kebersihan',
        baseUnit: 'pcs',
        minimumQtyMilli: 2000, // 2 pcs
        initialQtyMilli: 4000, // 4 pcs
      );
      await createItem(
        name: 'Deterjen Pakaian',
        stockCategory: 'Kebersihan',
        baseUnit: 'g',
        minimumQtyMilli: 800000, // 800 gram
        initialQtyMilli: 1800000, // 1.8 kg
      );
    }
  }
}
