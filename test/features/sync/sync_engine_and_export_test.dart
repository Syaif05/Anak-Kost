import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;

import 'package:anakkost/core/contracts/operation_contracts.dart';
import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/core/security/encryption_service.dart';
import 'package:anakkost/core/sync/backup_and_export_service.dart';
import 'package:anakkost/core/sync/models/sync_models.dart';
import 'package:anakkost/core/sync/supabase_sync_service.dart';
import 'package:anakkost/core/sync/sync_engine.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockSupabaseSyncService extends Mock implements ISupabaseSyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockSecureStorage mockSecureStorage;
  late MockSupabaseSyncService mockSupabaseSync;
  late SyncEngine syncEngine;
  late BackupAndExportService exportService;
  late EncryptionService encryptionService;

  setUpAll(() {
    registerFallbackValue(const SyncOperationPayload(
      operationId: 'dummy-op',
      deviceId: 'dummy-device',
      deviceGeneration: 1,
      datasetGeneration: 1,
      aggregateType: 'dummy',
      aggregateId: 'dummy-id',
      baseVersions: {},
      commands: [],
    ));
  });

  setUp(() async {
    db = AppDatabase.inMemory();
    mockSecureStorage = MockSecureStorage();
    mockSupabaseSync = MockSupabaseSyncService();
    encryptionService = EncryptionService();

    when(() => mockSecureStorage.read(key: 'device_id'))
        .thenAnswer((_) async => 's24-test-device');
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    when(() => mockSupabaseSync.isAuthenticated).thenReturn(true);
    when(() => mockSupabaseSync.currentUserId).thenReturn('user-test-kost-01');

    syncEngine = SyncEngine(
      db: db,
      supabaseSync: mockSupabaseSync,
      secureStorage: mockSecureStorage,
    );

    exportService = BackupAndExportService(
      db: db,
      encryptionService: encryptionService,
    );

    // Seed Profile
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'user-test-kost-01',
            cryptoContextId: 'ctx-test-01',
            displayName: const drift.Value('Anak Kost Sync Test'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 6: Offline-First Synchronization & Gate Tests', () {
    test('Gate Test T05: Retry push idempotent menghasilkan efek tunggal tanpa duplikasi', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const opId = 'op-tx-create-001';

      // 1. Tambahkan operasi transaksi ke sync_outbox
      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'transaction',
              aggregateId: 'tx-001',
              baseVersion: 0,
              payloadJson: jsonEncode({
                'amount_rp': 25000,
                'kind': 'expense',
                'merchant': 'Warung Pecel',
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );

      // Server merespons acknowledgement untuk operationId ini
      when(() => mockSupabaseSync.applyOperation(any())).thenAnswer((_) async => const SyncOperationAck(
            operationId: opId,
            status: 'acknowledged',
            serverVersion: 1,
            changeSeq: 101,
          ));

      // 2. Eksekusi Push Pertama
      final results1 = await syncEngine.pushOutbox();
      expect(results1.length, 1);
      expect(results1.first.isAcknowledged, isTrue);

      final outboxRow1 = await (db.select(db.syncOutbox)..where((o) => o.operationId.equals(opId))).getSingle();
      expect(outboxRow1.status, 'done');

      // 3. Simulasi Retry: Jika client mencoba push ulang, tidak ada item pending tersisa
      final results2 = await syncEngine.pushOutbox();
      expect(results2.isEmpty, isTrue, reason: 'Operasi yang sudah done tidak dikirim ulang');

      verify(() => mockSupabaseSync.applyOperation(any())).called(1);
    });

    test('Gate Test T06: Edit lokal ketika push sedang berjalan tidak tertimpa acknowledgement', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const opId1 = 'op-tx-edit-v1';
      const opId2 = 'op-tx-edit-v2';

      // 1. Operasi pertama (revisi 1) dimasukkan ke outbox
      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId1,
              aggregateType: 'transaction',
              aggregateId: 'tx-100',
              baseVersion: 1,
              payloadJson: jsonEncode({'amount_rp': 50000}),
              localRevision: 1,
              createdAt: now,
            ),
          );

      // 2. Mock applyOperation memicu jeda/delay di mana pengguna melakukan edit revisi 2
      when(() => mockSupabaseSync.applyOperation(any())).thenAnswer((_) async {
        // Simulasi pengguna mengedit nominal saat request push masih berjalan
        await db.into(db.syncOutbox).insert(
              SyncOutboxCompanion.insert(
                operationId: opId2,
                aggregateType: 'transaction',
                aggregateId: 'tx-100',
                baseVersion: 1,
                payloadJson: jsonEncode({'amount_rp': 60000}),
                localRevision: 2,
                createdAt: now + 50,
              ),
            );

        return const SyncOperationAck(
          operationId: opId1,
          status: 'acknowledged',
          serverVersion: 2,
          changeSeq: 201,
        );
      });

      // Jalankan push
      await syncEngine.pushOutbox();

      // Verifikasi: opId1 ditandai 'done'
      final row1 = await (db.select(db.syncOutbox)..where((o) => o.operationId.equals(opId1))).getSingle();
      expect(row1.status, 'done');

      // Verifikasi Kritis (Gate T06): opId2 (revisi baru lokal) TETAP berstatus 'pending'!
      final row2 = await (db.select(db.syncOutbox)..where((o) => o.operationId.equals(opId2))).getSingle();
      expect(row2.status, 'pending', reason: 'Revisi baru yang dibuat saat push tidak boleh tertimpa!');
    });

    test('Gate Test T07: Pull tombstone (penghapusan) dan cursor antarhalaman tersinkronisasi atomik', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Buat data transaksi aktif lokal
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-to-delete',
              userId: 'user-test-kost-01',
              kind: 'expense',
              amountRp: 75000,
              localDate: '2026-10-10',
              occurredAt: now,
              createdAt: now,
              updatedAt: now,
              lastOperationId: 'op-init',
              originDeviceId: 's24-test-device',
            ),
          );

      var txLocal = await (db.select(db.transactions)..where((t) => t.id.equals('tx-to-delete'))).getSingle();
      expect(txLocal.deletedAt, isNull);

      // 2. Mock pull_changes mengembalikan TOMBSTONE untuk transaksi ini
      when(() => mockSupabaseSync.pullChanges(afterSeq: 0, limit: any(named: 'limit'))).thenAnswer(
        (_) async => const PullChangesResponse(
          changes: [
            ServerChangeItem(
              changeSeq: 50,
              entityType: 'transaction',
              entityId: 'tx-to-delete',
              rowVersion: 2,
              isTombstone: true, // Penghapusan di Mac
              operationId: 'op-remote-delete',
            ),
          ],
          nextSeq: 50,
          hasMore: false,
        ),
      );

      // 3. Jalankan Pull Changes
      final count = await syncEngine.pullChanges();
      expect(count, 1);

      // 4. Verifikasi Tombstone diterapkan di database lokal (Gate T07)
      txLocal = await (db.select(db.transactions)..where((t) => t.id.equals('tx-to-delete'))).getSingle();
      expect(txLocal.deletedAt, isNotNull, reason: 'Tombstone harus menandai deletedAt secara permanen');

      // 5. Verifikasi Cursor lokal diperbarui ke nextSeq = 50
      final cursor = await (db.select(db.syncCursors)
            ..where((c) => c.ownerId.equals('user-test-kost-01') & c.deviceId.equals('s24-test-device')))
          .getSingle();
      expect(cursor.lastChangeSeq, 50);
    });

    test('Gate Test T18: Ekspor CSV mengamankan sel teks dari formula injection (=, +, -, @)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Buat transaksi dengan teks berawalan formula berbahaya
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-injection-1',
              userId: 'user-test-kost-01',
              kind: 'expense',
              amountRp: 150000,
              localDate: '2026-10-11',
              merchant: const drift.Value('=SUM(A1:A10)'),
              note: const drift.Value('+cmd|\' /C calc\'!A0'),
              occurredAt: now,
              createdAt: now,
              updatedAt: now,
              lastOperationId: 'op-test',
              originDeviceId: 's24-test-device',
            ),
          );

      // Buat barang inventaris dengan awalan formula berbahaya
      await db.into(db.inventoryItems).insert(
            InventoryItemsCompanion.insert(
              id: 'item-injection-1',
              userId: 'user-test-kost-01',
              name: '@MALICIOUS_FUNCTION',
              stockCategory: const drift.Value('-1000'),
              baseUnit: const drift.Value('pcs'),
              minimumQtyMilli: const drift.Value(0),
              createdAt: now,
              updatedAt: now,
              lastOperationId: 'op-test',
              originDeviceId: 's24-test-device',
            ),
          );

      // Ekspor Transaksi CSV
      final txCsv = await exportService.exportTransactionsCsv();
      // Verifikasi T18: Formula disanitasi dengan tanda petik tunggal awalan
      expect(txCsv, contains("'=SUM(A1:A10)"));
      expect(txCsv, contains("'+cmd|' /C calc'!A0"));
      expect(txCsv, contains('150000')); // Nilai numerik tetap bersih

      // Ekspor Inventaris CSV
      final itemCsv = await exportService.exportInventoryCsv();
      expect(itemCsv, contains("'@MALICIOUS_FUNCTION"));
      expect(itemCsv, contains("'-1000"));
    });

    test('Encrypted Full Backup & Restore: Enkripsi AES-256-GCM dengan recovery secret', () async {
      const recoverySecret = 'an4k-k0st-Sup3r-S3cur3-R3c0v3ry-K3y';

      // 1. Buat backup terenkripsi
      final backupEnvelope = await exportService.createEncryptedBackup(recoverySecret: recoverySecret);
      expect(backupEnvelope['format'], 'anakkost_encrypted_backup');
      expect(backupEnvelope['ciphertext_base64'], isNotEmpty);
      expect(backupEnvelope['salt_base64'], isNotEmpty);

      // 2. Dekripsi backup dengan passphrase yang benar
      final restoredData = await exportService.decryptBackup(
        backupEnvelope: backupEnvelope,
        recoverySecret: recoverySecret,
      );
      expect(restoredData['backup_version'], 1);
      expect(restoredData['schema_version'], 1);
      expect(restoredData['data'], isNotNull);

      // 3. Dekripsi dengan passphrase yang salah gagal aman
      expect(
        () async => await exportService.decryptBackup(
          backupEnvelope: backupEnvelope,
          recoverySecret: 'wrong-passphrase-totally-incorrect',
        ),
        throwsA(anything),
      );
    });
  });
}
