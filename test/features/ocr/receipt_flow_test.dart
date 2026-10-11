import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;

import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/core/notifications/notification_service.dart';
import 'package:anakkost/core/security/encryption_service.dart';
import 'package:anakkost/core/security/key_manager.dart';
import 'package:anakkost/core/storage/local_file_storage.dart';
import 'package:anakkost/features/finance/data/finance_repository.dart';
import 'package:anakkost/features/inventory/data/inventory_repository.dart';
import 'package:anakkost/features/inventory/domain/models/inventory_models.dart';
import 'package:anakkost/features/documents/data/documents_repository.dart';
import 'package:anakkost/features/ocr/domain/models/ocr_models.dart';
import 'package:anakkost/features/ocr/domain/services/receipt_parser.dart';

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
  late LocalFileStorage fileStorage;
  late Directory tempDir;
  late DeterministicReceiptParser parser;

  setUp(() async {
    db = AppDatabase.inMemory();
    mockSecureStorage = MockSecureStorage();
    mockNotificationService = MockNotificationService();
    encryptionService = EncryptionService();
    keyManager = KeyManager(
      encryptionService: encryptionService,
      secureStorage: mockSecureStorage,
    );

    tempDir = Directory.systemTemp.createTempSync('ocr_flow_test_');
    fileStorage = LocalFileStorage(customBaseDir: tempDir);

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'mock-device-id');
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    when(() => mockNotificationService.generateId(any())).thenReturn(88888);
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
      fileStorage: fileStorage,
    );
    parser = DeterministicReceiptParser();

    // Inisialisasi profil pengguna
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'user-ocr-test-01',
            cryptoContextId: 'crypto-ctx-ocr',
            displayName: const drift.Value('Anak Kost OCR Test'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Fase 5 End-to-End: OCR Draft -> Gate Dodd Confirmation -> Encrypted Evidence & Inventory Stock Sync', () async {
    // 0. Seed Database (Dompet, Kategori, Barang Inventaris)
    final walletId = await financeRepo.createWallet(
      name: 'BCA Utama',
      walletType: 'bank',
      initialBalanceRp: 500000,
    );

    final categoryId = await financeRepo.createCategory(
      name: 'Belanja Dapur',
      direction: 'expense',
    );

    // Barang awal di inventaris: Indomie Goreng (Stok awal = 5 pcs)
    final indomieId = await inventoryRepo.createItem(
      name: 'Indomie Goreng',
      stockCategory: 'makanan',
      baseUnit: 'pcs',
      minimumQtyMilli: 2000,
      initialQtyMilli: 5000,
    );

    final initialStock = await inventoryRepo.dao.getItemStockMilli(indomieId);
    expect(StockUnit.toBase(initialStock), 5.0);

    // 1. Simulasi Hasil Scan OCR Struk Superindo (Gate Test T11)
    final lines = [
      const OcrTextLine(
        text: 'SUPERINDO SUPERMARKET',
        box: OcrNormalizedBox(x: 0.2, y: 0.05, width: 0.6, height: 0.04),
      ),
      const OcrTextLine(
        text: '12/10/2026 14:30',
        box: OcrNormalizedBox(x: 0.2, y: 0.10, width: 0.6, height: 0.03),
      ),
      const OcrTextLine(
        text: 'INDOMIE GORENG SPESIAL 5 PCS 15.000',
        box: OcrNormalizedBox(x: 0.1, y: 0.20, width: 0.8, height: 0.04),
      ),
      const OcrTextLine(
        text: 'MINYAK GORENG TROPICAL 2L 39.000',
        box: OcrNormalizedBox(x: 0.1, y: 0.25, width: 0.8, height: 0.04),
      ),
      const OcrTextLine(
        text: 'SUBTOTAL 54.000',
        box: OcrNormalizedBox(x: 0.1, y: 0.32, width: 0.8, height: 0.03),
      ),
      const OcrTextLine(
        text: 'TOTAL 54.000',
        box: OcrNormalizedBox(x: 0.1, y: 0.36, width: 0.8, height: 0.04),
      ),
      const OcrTextLine(
        text: 'TUNAI 100.000',
        box: OcrNormalizedBox(x: 0.1, y: 0.40, width: 0.8, height: 0.03),
      ),
      const OcrTextLine(
        text: 'KEMBALIAN 46.000',
        box: OcrNormalizedBox(x: 0.1, y: 0.44, width: 0.8, height: 0.03),
      ),
    ];

    final ocrResult = OcrResult(
      rawText: lines.map((l) => l.text).join('\n'),
      lines: lines,
      blocks: [OcrTextBlock(text: lines.map((l) => l.text).join('\n'), lines: lines)],
      engine: 'mlkit_latin',
    );

    // 2. Deterministic Receipt Parsing
    final draft = parser.parse(ocrResult);
    expect(draft.merchantCandidate, contains('SUPERINDO'));
    expect(draft.localDateCandidate, '2026-10-12');
    expect(draft.totalRpCandidate, 54000); // T11: memisahkan total dari kembalian 46.000
    expect(draft.subtotalRp, 54000);
    expect(draft.changeRp, 46000);
    expect(draft.items.length, 2);

    // 3. ATURAN MUTLAK PRD: Tanpa review & persetujuan user, transaksi pengeluaran belum dibuat
    final initialExpenseList = await (db.select(db.transactions)..where((t) => t.kind.equals('expense'))).get();
    expect(initialExpenseList.isEmpty, isTrue, reason: 'save_without_user_review: forbidden');

    // 4. Simulasi User Konfirmasi & Simpan Draf di Review Screen
    final expenseTxId = await financeRepo.createExpense(
      walletId: walletId,
      amountRp: draft.totalRpCandidate,
      categoryId: categoryId,
      localDate: draft.localDateCandidate ?? '2026-10-12',
      merchant: draft.merchantCandidate ?? 'Toko',
      note: 'Struk OCR: ${draft.items.map((e) => e.name).join(", ")}',
    );
    expect(expenseTxId, isNotEmpty);

    // Saldo dompet berkurang secara tepat (500.000 - 54.000 = 446.000)
    final updatedBalance = await financeRepo.dao.getWalletBalance(walletId);
    expect(updatedBalance, 446000);

    // 5. Lampirkan Foto Struk Asli Terenkripsi AES-256-GCM sebagai Bukti (DOC03 & IMG)
    final dummyPhotoBytes = Uint8List.fromList(List.generate(2048, (i) => (i * 7) % 256));
    final masterKey = keyManager.generateMasterKey();

    final attachmentId = await documentsRepo.attachEvidenceToTransaction(
      transactionId: expenseTxId,
      fileBytes: dummyPhotoBytes,
      masterKey: masterKey,
      mimeType: 'image/jpeg',
    );
    expect(attachmentId, isNotEmpty);

    // Verifikasi attachment tersimpan dengan link_role 'evidence' dan target_id expenseTxId
    final attachmentEntry = await (db.select(db.attachments)..where((a) => a.id.equals(attachmentId))).getSingle();
    final linkEntry = await (db.select(db.attachmentLinks)..where((l) => l.attachmentId.equals(attachmentId))).getSingle();
    expect(linkEntry.linkRole, 'evidence');
    expect(linkEntry.transactionId, expenseTxId);

    // Verifikasi berkas fisik didekripsi dengan akurasi 100% menggunakan masterKey
    final decryptedPhoto = await documentsRepo.loadAndDecryptAttachment(
      attachment: attachmentEntry,
      masterKey: masterKey,
    );
    expect(decryptedPhoto, equals(dummyPhotoBytes));

    // 6. Sinkronisasi Inventaris: Indomie Goreng dicocokkan dan stok bertambah (+5 pcs)
    final existingInventory = await inventoryRepo.dao.watchInventoryItemsWithStock().first;
    for (final draftItem in draft.items) {
      final matched = existingInventory.cast<InventoryItemWithStock?>().firstWhere(
            (it) => it != null && (it.item.name.toLowerCase().contains(draftItem.name.toLowerCase()) ||
                draftItem.name.toLowerCase().contains(it.item.name.toLowerCase())),
            orElse: () => null,
          );

      if (matched != null) {
        final deltaMilli = StockUnit.toMilli(draftItem.quantity);
        await inventoryRepo.recordMovement(
          itemId: matched.item.id,
          movementType: 'add',
          quantityDeltaMilli: deltaMilli,
          reason: 'Penambahan stok dari struk ${draft.merchantCandidate}',
        );
      }
    }

    // Stok Indomie sekarang: 5 + 5 = 10 pcs
    final finalStock = await inventoryRepo.dao.getItemStockMilli(indomieId);
    expect(StockUnit.toBase(finalStock), 10.0);

    // 7. Verifikasi Outbox Sinkronisasi (PRD SYNC01)
    final outboxList = await db.select(db.syncOutbox).get();
    final outboxAggregates = outboxList.map((o) => o.aggregateType).toSet();
    expect(outboxAggregates.contains('transaction'), isTrue);
    expect(outboxAggregates.contains('attachment'), isTrue);
    expect(outboxAggregates.contains('inventory_movement'), isTrue);
  });
}
