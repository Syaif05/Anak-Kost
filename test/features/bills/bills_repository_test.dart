import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;

import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/core/notifications/notification_service.dart';
import 'package:anakkost/features/finance/data/finance_repository.dart';
import 'package:anakkost/features/bills/data/bills_repository.dart';
import 'package:anakkost/features/bills/domain/models/bill_models.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late AppDatabase db;
  late MockSecureStorage mockSecureStorage;
  late MockNotificationService mockNotificationService;
  late FinanceRepository financeRepo;
  late BillsRepository billsRepo;

  setUp(() async {
    db = AppDatabase.inMemory();
    mockSecureStorage = MockSecureStorage();
    mockNotificationService = MockNotificationService();

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'mock-device-id');
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    when(() => mockNotificationService.generateId(any())).thenReturn(12345);
    when(() => mockNotificationService.scheduleNotification(
          id: any(named: 'id'),
          channelId: any(named: 'channelId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationService.cancelNotification(any())).thenAnswer((_) async {});

    financeRepo = FinanceRepository(
      db: db,
      dao: db.financeDao,
      secureStorage: mockSecureStorage,
    );

    billsRepo = BillsRepository(
      db: db,
      dao: db.billsDao,
      notificationService: mockNotificationService,
      secureStorage: mockSecureStorage,
    );

    // Seed profile
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'test-user-001',
            cryptoContextId: 'test-crypto-001',
            displayName: const drift.Value('Anak Kost Test'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Bills Module & Recurrence Tests (Fase 3)', () {
    test('Gate Test T03: Pembayaran sebagian Rp400.000 lalu Rp600.000 mengubah status lunas; void transaksi memulihkan sisa Rp600.000', () async {
      // 1. Buat Dompet Bank dengan saldo Rp2.000.000
      final bankId = await financeRepo.createWallet(
        name: 'Bank Mandiri',
        walletType: 'bank',
        initialBalanceRp: 2000000,
      );

      // 2. Buat Kategori Kost
      final kostCatId = await financeRepo.createCategory(
        name: 'Sewa Kost Bulanan',
        direction: 'expense',
      );

      // 3. Buat Template Tagihan Kost Rp1.000.000 per bulan
      final tmplId = await billsRepo.createBillTemplate(
        name: 'Kost Kamar 204',
        categoryId: kostCatId,
        estimatedAmountRp: 1000000,
        frequency: 'monthly',
        anchorDate: '2026-10-25',
      );

      expect(tmplId, isNotEmpty);

      // 4. Ambil occurrence untuk periode Oktober 2026 ("2026-10")
      final occurrences = await billsRepo.dao.watchOccurrencesForPeriod('2026-10').first;
      expect(occurrences, hasLength(1));

      var occ = occurrences.first;
      expect(occ.effectiveAmountDueRp, 1000000);
      expect(occ.totalPaidRp, 0);
      expect(occ.remainingRp, 1000000);
      expect(occ.status, BillStatus.unpaid);

      // 5. Pembayaran Sebagian 1: Bayar Rp400.000
      final payment1Id = await billsRepo.payBillOccurrence(
        occurrenceId: occ.occurrence.id,
        walletId: bankId,
        amountRp: 400000,
        localDate: '2026-10-05',
        note: 'Cicilan 1 Kost',
      );
      expect(payment1Id, isNotEmpty);

      // Verifikasi status menjadi Sebagian (Sisa Rp600.000)
      occ = (await billsRepo.dao.getOccurrenceWithStatus(occ.occurrence.id))!;
      expect(occ.totalPaidRp, 400000);
      expect(occ.remainingRp, 600000);
      expect(occ.status, BillStatus.partial);

      // Saldo bank berkurang menjadi Rp1.600.000
      expect(await financeRepo.dao.getWalletBalance(bankId), 1600000);

      // 6. Pembayaran 2: Pelunasan sisa Rp600.000
      final payment2Id = await billsRepo.payBillOccurrence(
        occurrenceId: occ.occurrence.id,
        walletId: bankId,
        amountRp: 600000,
        localDate: '2026-10-06',
        note: 'Pelunasan Kost',
      );
      expect(payment2Id, isNotEmpty);

      // Verifikasi status menjadi Lunas (Sisa Rp0)
      occ = (await billsRepo.dao.getOccurrenceWithStatus(occ.occurrence.id))!;
      expect(occ.totalPaidRp, 1000000);
      expect(occ.remainingRp, 0);
      expect(occ.status, BillStatus.paid);

      // Saldo bank berkurang menjadi Rp1.000.000
      expect(await financeRepo.dao.getWalletBalance(bankId), 1000000);

      // 7. Ambil ID Transaksi dari pembayaran kedua lalu BATALKAN (Void)
      final payment2Row = await (db.select(db.billPayments)..where((t) => t.id.equals(payment2Id))).getSingle();
      await financeRepo.voidTransaction(payment2Row.transactionId);

      // Verifikasi status tagihan KEMBALI menjadi Sebagian (Sisa Rp600.000)
      occ = (await billsRepo.dao.getOccurrenceWithStatus(occ.occurrence.id))!;
      expect(occ.totalPaidRp, 400000);
      expect(occ.remainingRp, 600000);
      expect(occ.status, BillStatus.partial);

      // Saldo bank kembali bertambah menjadi Rp1.600.000 secara atomik
      expect(await financeRepo.dao.getWalletBalance(bankId), 1600000);
    });

    test('Gate Test T09: Anchor tanggal 31 dievaluasi tepat di akhir bulan pendek tanpa duplikasi period key', () async {
      // Buat template tagihan dengan anchor date tanggal 31 Januari 2026
      final kostCatId = await financeRepo.createCategory(
        name: 'Listrik & WiFi',
        direction: 'expense',
      );

      final tmplId = await billsRepo.createBillTemplate(
        name: 'Listrik Bulanan',
        categoryId: kostCatId,
        estimatedAmountRp: 300000,
        frequency: 'monthly',
        anchorDate: '2026-01-31',
      );

      // Generate occurrence untuk Jan, Feb, Mar, Apr 2026
      await billsRepo.generateOccurrencesForMonth(year: 2026, month: 1);
      await billsRepo.generateOccurrencesForMonth(year: 2026, month: 2);
      await billsRepo.generateOccurrencesForMonth(year: 2026, month: 3);
      await billsRepo.generateOccurrencesForMonth(year: 2026, month: 4);

      // 1. Januari (31 hari) -> Due date: 2026-01-31
      final janOcc = await (db.select(db.billOccurrences)
            ..where((t) => t.templateId.equals(tmplId) & t.periodKey.equals('2026-01')))
          .getSingle();
      expect(janOcc.dueDate, '2026-01-31');

      // 2. Februari 2026 (28 hari, bulan pendek) -> Clamped ke akhir bulan: 2026-02-28
      final febOcc = await (db.select(db.billOccurrences)
            ..where((t) => t.templateId.equals(tmplId) & t.periodKey.equals('2026-02')))
          .getSingle();
      expect(febOcc.dueDate, '2026-02-28');

      // 3. Maret 2026 (31 hari) -> Kembali ke tanggal 31: 2026-03-31 (Rule T09)
      final marOcc = await (db.select(db.billOccurrences)
            ..where((t) => t.templateId.equals(tmplId) & t.periodKey.equals('2026-03')))
          .getSingle();
      expect(marOcc.dueDate, '2026-03-31');

      // 4. April 2026 (30 hari, bulan pendek) -> Clamped ke akhir bulan: 2026-04-30
      final aprOcc = await (db.select(db.billOccurrences)
            ..where((t) => t.templateId.equals(tmplId) & t.periodKey.equals('2026-04')))
          .getSingle();
      expect(aprOcc.dueDate, '2026-04-30');

      // 5. Panggilan ulang generate tidak membuat duplikasi occurrence pada period key yang sama
      await billsRepo.generateOccurrencesForMonth(year: 2026, month: 2);
      final febList = await (db.select(db.billOccurrences)
            ..where((t) => t.templateId.equals(tmplId) & t.periodKey.equals('2026-02')))
          .get();
      expect(febList, hasLength(1));
    });
  });
}
