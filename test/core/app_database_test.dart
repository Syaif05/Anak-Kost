import 'package:flutter_test/flutter_test.dart';
import 'package:anakkost/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift AppDatabase In-Memory Tests', () {
    test('Inisialisasi tabel Profil & query', () async {
      final userId = uuid.v4();
      final cryptoContextId = uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              id: userId,
              cryptoContextId: cryptoContextId,
              displayName: const Value('Pengguna Kost'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final profile = await (db.select(db.profiles)..where((t) => t.id.equals(userId))).getSingle();
      expect(profile.displayName, 'Pengguna Kost');
      expect(profile.currency, 'IDR');
      expect(profile.timezone, 'Asia/Jakarta');
    });

    test('Inisialisasi Dompet & Ledger Entries (Double-Entry Model)', () async {
      final userId = uuid.v4();
      final walletId = uuid.v4();
      final txId = uuid.v4();
      final opId = uuid.v4();
      final deviceId = uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Simpan Dompet Tunai
      await db.into(db.wallets).insert(
            WalletsCompanion.insert(
              id: walletId,
              userId: userId,
              name: 'Dompet Tunai',
              walletType: 'cash',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 2. Simpan Transaksi Pemasukan Rp500.000
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              kind: 'income',
              amountRp: 500000,
              occurredAt: now,
              localDate: '2026-10-10',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 3. Simpan Entry Ledger Positif
      await db.into(db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: uuid.v4(),
              userId: userId,
              transactionId: txId,
              walletId: walletId,
              amountRp: 500000,
              entryRole: 'main',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      final wallets = await db.select(db.wallets).get();
      expect(wallets.length, 1);
      expect(wallets.first.name, 'Dompet Tunai');

      final entries = await (db.select(db.walletEntries)..where((t) => t.walletId.equals(walletId))).get();
      expect(entries.length, 1);
      expect(entries.first.amountRp, 500000);
    });

    test('Antrean Outbox Sinkronisasi Tersimpan Bersama State Pending', () async {
      final opId = uuid.v4();
      final aggId = uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'transaction',
              aggregateId: aggId,
              baseVersion: 0,
              payloadJson: '{"amount_rp": 15000}',
              localRevision: 1,
              createdAt: now,
            ),
          );

      final outboxList = await db.select(db.syncOutbox).get();
      expect(outboxList.length, 1);
      expect(outboxList.first.status, 'pending');
      expect(outboxList.first.aggregateType, 'transaction');
    });
  });
}
