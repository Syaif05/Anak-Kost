import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;

import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/core/notifications/notification_service.dart';
import 'package:anakkost/core/security/encryption_service.dart';
import 'package:anakkost/core/security/key_manager.dart';
import 'package:anakkost/features/finance/data/finance_repository.dart';
import 'package:anakkost/features/inventory/data/inventory_repository.dart';
import 'package:anakkost/features/inventory/domain/models/inventory_models.dart';
import 'package:anakkost/features/documents/data/documents_repository.dart';
import 'package:anakkost/features/documents/domain/models/document_models.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockSecureStorage mockSecureStorage;
  late MockNotificationService mockNotificationService;
  late FinanceRepository financeRepo;
  late InventoryRepository inventoryRepo;
  late DocumentsRepository documentsRepo;
  late EncryptionService encryptionService;
  late KeyManager keyManager;

  setUp(() async {
    db = AppDatabase.inMemory();
    mockSecureStorage = MockSecureStorage();
    mockNotificationService = MockNotificationService();
    encryptionService = EncryptionService();
    keyManager = KeyManager(
      encryptionService: encryptionService,
      secureStorage: mockSecureStorage,
    );

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'mock-device-id');
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    when(() => mockNotificationService.generateId(any())).thenReturn(99999);
    when(() => mockNotificationService.showNotification(
          id: any(named: 'id'),
          channelId: any(named: 'channelId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});

    financeRepo = FinanceRepository(
      db: db,
      dao: db.financeDao,
      secureStorage: mockSecureStorage,
    );

    inventoryRepo = InventoryRepository(
      db: db,
      dao: db.inventoryDao,
      notificationService: mockNotificationService,
      secureStorage: mockSecureStorage,
    );

    documentsRepo = DocumentsRepository(
      db: db,
      dao: db.documentsDao,
      encryptionService: encryptionService,
      keyManager: keyManager,
      secureStorage: mockSecureStorage,
    );

    // Inisialisasi profil pengguna
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'user-fase4-001',
            cryptoContextId: 'crypto-ctx-fase4',
            displayName: const drift.Value('Anak Kost Fase 4'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Inventory & Shopping Module Tests (Fase 4)', () {
    test('Gate Test T04: Checkout belanja 2 barang mencatat pengeluaran, menambah stok, riwayat harga, dan outbox secara atomik', () async {
      // 1. Buat Dompet Fisik dengan saldo Rp500.000
      final walletId = await financeRepo.createWallet(
        name: 'Dompet Fisik',
        walletType: 'cash',
        initialBalanceRp: 500000,
      );

      // 2. Buat Kategori Pengeluaran Kebutuhan
      final categoryId = await financeRepo.createCategory(
        name: 'Kebutuhan Kost',
        direction: 'expense',
      );

      // 3. Buat 2 Barang Inventaris
      // Barang 1: Beras Ramos (unit: gram, stok awal: 0, min: 1.000.000 milli-g / 1 kg)
      final berasId = await inventoryRepo.createItem(
        name: 'Beras Ramos',
        stockCategory: 'Makanan Pokok',
        baseUnit: 'g',
        minimumQtyMilli: 1000000,
        initialQtyMilli: 0,
      );

      // Barang 2: Sabun Mandi (unit: pcs, stok awal: 1.000 milli-pcs / 1 pcs, min: 2.000 milli-pcs / 2 pcs)
      final sabunId = await inventoryRepo.createItem(
        name: 'Sabun Mandi Dettol',
        stockCategory: 'Kebersihan',
        baseUnit: 'pcs',
        minimumQtyMilli: 2000,
        initialQtyMilli: 1000,
      );

      // 4. Buat Rencana Belanja
      final listId = await inventoryRepo.createShoppingList(
        name: 'Belanja Mingguan Kost',
        plannedDate: '2026-10-15',
        storeHint: 'Superindo',
      );

      final listItemBerasId = await inventoryRepo.addShoppingListItem(
        shoppingListId: listId,
        inventoryItemId: berasId,
        name: 'Beras 5 kg',
        requestedQtyMilli: 5000000, // 5 kg
        unit: 'g',
        estimatedTotalRp: 75000,
      );

      final listItemSabunId = await inventoryRepo.addShoppingListItem(
        shoppingListId: listId,
        inventoryItemId: sabunId,
        name: 'Sabun Mandi 3 pcs',
        requestedQtyMilli: 3000, // 3 pcs
        unit: 'pcs',
        estimatedTotalRp: 25000,
      );

      // 5. Eksekusi Checkout Belanja Selesai (Gate Test T04)
      final purchaseId = await inventoryRepo.checkoutShoppingList(
        shoppingListId: listId,
        walletId: walletId,
        expenseCategoryId: categoryId,
        localDate: '2026-10-15',
        storeName: 'Superindo Kaliurang',
        items: [
          CheckoutItemInput(
            inventoryItemId: berasId,
            shoppingListItemId: listItemBerasId,
            itemName: 'Beras Ramos 5 kg',
            quantityBaseMilli: 5000000, // 5 kg
            totalPaidRp: 75000,
            addToStock: true,
            storeName: 'Superindo Kaliurang',
          ),
          CheckoutItemInput(
            inventoryItemId: sabunId,
            shoppingListItemId: listItemSabunId,
            itemName: 'Sabun Mandi 3 pcs',
            quantityBaseMilli: 3000, // 3 pcs
            totalPaidRp: 25000,
            addToStock: true,
            storeName: 'Superindo Kaliurang',
          ),
        ],
      );

      expect(purchaseId, isNotEmpty);

      // Verifikasi A: Saldo Dompet berkurang Rp100.000 (dari Rp500.000 menjadi Rp400.000)
      final balanceAfter = await financeRepo.dao.getWalletBalance(walletId);
      expect(balanceAfter, 400000);

      // Verifikasi B: Stok Beras bertambah dari 0 menjadi 5.000.000 milli-g (5 kg)
      final stockBeras = await inventoryRepo.dao.getItemStockMilli(berasId);
      expect(stockBeras, 5000000);

      // Verifikasi C: Stok Sabun bertambah dari 1.000 menjadi 4.000 milli-pcs (4 pcs)
      final stockSabun = await inventoryRepo.dao.getItemStockMilli(sabunId);
      expect(stockSabun, 4000);

      // Verifikasi D: Riwayat observasi harga (price_history) tercatat untuk kedua barang
      final priceHistoryBeras = await inventoryRepo.dao.watchPriceHistory(berasId).first;
      expect(priceHistoryBeras, hasLength(1));
      expect(priceHistoryBeras.first.totalPriceRp, 75000);
      expect(priceHistoryBeras.first.quantityBaseMilli, 5000000);
      expect(priceHistoryBeras.first.storeName, 'Superindo Kaliurang');

      final priceHistorySabun = await inventoryRepo.dao.watchPriceHistory(sabunId).first;
      expect(priceHistorySabun, hasLength(1));
      expect(priceHistorySabun.first.totalPriceRp, 25000);
      expect(priceHistorySabun.first.quantityBaseMilli, 3000);

      // Verifikasi E: Status Shopping List menjadi 'completed'
      final lists = await inventoryRepo.dao.watchShoppingLists().first;
      expect(lists.first.list.status, 'completed');

      // Verifikasi F: Sync outbox memuat operasi aggregate 'shopping_purchase'
      final outbox = await db.select(db.syncOutbox).get();
      final purchaseOutbox = outbox.where((o) => o.aggregateType == 'shopping_purchase').toList();
      expect(purchaseOutbox, hasLength(1));
    });

    test('Pencegahan Stok Negatif: Pemakaian melebihi stok yang ada diblokir dan meminta koreksi', () async {
      // 1. Buat Barang dengan stok awal 3.000 milli-pcs (3 pcs)
      final sabunId = await inventoryRepo.createItem(
        name: 'Sabun Cuci Piring',
        baseUnit: 'pcs',
        minimumQtyMilli: 2000, // 2 pcs
        initialQtyMilli: 3000, // 3 pcs
      );

      // 2. Pemakaian 4 pcs (melebihi stok 3 pcs) -> Harus melempar StateError
      expect(
        () => inventoryRepo.recordMovement(
          itemId: sabunId,
          movementType: 'use',
          quantityDeltaMilli: -4000,
          reason: 'Pemakaian berlebih',
        ),
        throwsA(isA<StateError>()),
      );

      // Pastikan stok tidak berubah (tetap 3.000 milli-pcs)
      expect(await inventoryRepo.dao.getItemStockMilli(sabunId), 3000);

      // 3. Pemakaian sah 2 pcs (2.000 milli-pcs) -> Sukses, sisa stok 1.000 milli-pcs
      final movId = await inventoryRepo.recordMovement(
        itemId: sabunId,
        movementType: 'use',
        quantityDeltaMilli: -2000,
        reason: 'Pakai 2 pcs untuk dapur',
      );
      expect(movId, isNotEmpty);
      expect(await inventoryRepo.dao.getItemStockMilli(sabunId), 1000);

      // Karena sisa stok 1.000 <= ambang minimum 2.000, notifikasi stok menipis terpicu
      verify(() => mockNotificationService.showNotification(
            id: any(named: 'id'),
            channelId: NotificationService.channelStock,
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).called(1);
    });
  });

  group('Encrypted Document Vault Tests (Fase 4)', () {
    test('Gate Test T13 & T14: Metadata tersimpan ciphertext; salah kunci gagal aman; unwrap recovery berhasil didekripsi', () async {
      // 1. Inisialisasi Master Key
      final masterKey = keyManager.generateMasterKey();
      expect(masterKey.length, 32);

      // 2. Simpan Dokumen KTP dengan metadata sensitif
      final metadata = const DocumentMetadata(
        title: 'KTP Asli Pemilik Kost',
        documentNumber: '3171012345678901',
        notes: 'Dokumen identitas resmi untuk registrasi magang',
        tags: ['identitas', 'pribadi'],
        expiryDate: '2030-12-31',
      );

      final docId = await documentsRepo.createEncryptedDocument(
        documentType: 'ktp',
        metadata: metadata,
        masterKey: masterKey,
        fileBytes: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]), // dummy image bytes
        mediaKind: 'photo',
        mimeType: 'image/jpeg',
      );
      expect(docId, isNotEmpty);

      // 3. Verifikasi di DB: Metadata tersimpan dalam bentuk ciphertext (bukan plaintext!)
      final docRow = await (db.select(db.documents)..where((d) => d.id.equals(docId))).getSingle();
      final rawMetaString = String.fromCharCodes(docRow.encryptedMetadata);
      expect(rawMetaString.contains('3171012345678901'), isFalse);
      expect(rawMetaString.contains('KTP Asli'), isFalse);

      // 4. Dekripsi dengan Master Key yang benar -> Berhasil memulihkan metadata asli
      final decrypted = await documentsRepo.decryptDocumentMetadata(
        document: docRow,
        masterKey: masterKey,
      );
      expect(decrypted.title, 'KTP Asli Pemilik Kost');
      expect(decrypted.documentNumber, '3171012345678901');
      expect(decrypted.notes, 'Dokumen identitas resmi untuk registrasi magang');
      expect(decrypted.tags, contains('identitas'));

      // 5. Gate Test T13: Kunci salah atau ciphertext dimodifikasi -> Dekripsi gagal aman
      final wrongMasterKey = keyManager.generateMasterKey();
      expect(
        () => documentsRepo.decryptDocumentMetadata(
          document: docRow,
          masterKey: wrongMasterKey,
        ),
        throwsA(anything),
      );

      // Modifikasi 1 byte pada ciphertext
      final corruptedCiphertext = Uint8List.fromList(docRow.encryptedMetadata);
      corruptedCiphertext[0] ^= 0xFF; // Flip bit
      final corruptedDocRow = docRow.copyWith(encryptedMetadata: corruptedCiphertext);

      expect(
        () => documentsRepo.decryptDocumentMetadata(
          document: corruptedDocRow,
          masterKey: masterKey,
        ),
        throwsA(anything),
      );

      // 6. Gate Test T14: Wrap Master Key dengan Recovery Secret, lalu unwrap dan dekripsi
      const recoverySecret = 'secret-recovery-phrase-2026-anak-kost';
      final envelope = await keyManager.wrapMasterKeyWithRecoverySecret(
        masterKey: masterKey,
        recoverySecret: recoverySecret,
        cryptoContextId: 'crypto-ctx-fase4',
        keyPurpose: 'vault',
      );

      // Buka kembali master key menggunakan recovery secret
      final recoveredMasterKey = await keyManager.unwrapMasterKeyWithRecoverySecret(
        envelope: envelope,
        recoverySecret: recoverySecret,
      );
      expect(recoveredMasterKey, masterKey);

      // Dekripsi dokumen menggunakan recovered key -> Berhasil!
      final decryptedWithRecoveredKey = await documentsRepo.decryptDocumentMetadata(
        document: docRow,
        masterKey: recoveredMasterKey,
      );
      expect(decryptedWithRecoveredKey.documentNumber, '3171012345678901');
    });
  });
}
