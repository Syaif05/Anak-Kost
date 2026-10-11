import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;

import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/features/finance/data/finance_repository.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late AppDatabase db;
  late MockSecureStorage mockSecureStorage;
  late FinanceRepository repository;
  final Map<String, String> memoryStorage = {};

  setUp(() async {
    db = AppDatabase.inMemory();
    mockSecureStorage = MockSecureStorage();
    memoryStorage.clear();

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      return memoryStorage[key];
    });

    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String;
      memoryStorage[key] = value;
    });

    repository = FinanceRepository(
      db: db,
      dao: db.financeDao,
      secureStorage: mockSecureStorage,
    );

    // Seed dummy user profile
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

  group('Finance Module & Ledger Tests (Fase 2)', () {
    test('Gate Test T01: Transfer atomik dengan biaya transfer dan net expense report', () async {
      // 1. Buat Dompet Bank dengan saldo awal Rp1.000.000
      final bankId = await repository.createWallet(
        name: 'Bank Mandiri',
        walletType: 'bank',
        initialBalanceRp: 1000000,
      );

      // 2. Buat Dompet E-Wallet dengan saldo awal Rp0
      final ewalletId = await repository.createWallet(
        name: 'GoPay',
        walletType: 'ewallet',
        initialBalanceRp: 0,
      );

      // 3. Buat Kategori Biaya Transfer
      final feeCatId = await repository.createCategory(
        name: 'Biaya Transfer',
        direction: 'expense',
        iconKey: 'receipt',
        colorKey: 'deepOrange',
      );

      // Verifikasi saldo awal
      expect(await repository.dao.getWalletBalance(bankId), 1000000);
      expect(await repository.dao.getWalletBalance(ewalletId), 0);

      // 4. Lakukan Transfer Rp200.000 dengan biaya transfer Rp2.500
      final transferTxId = await repository.createTransfer(
        sourceWalletId: bankId,
        destWalletId: ewalletId,
        amountRp: 200000,
        feeRp: 2500,
        feeCategoryId: feeCatId,
        localDate: '2026-10-11',
        note: 'Top up GoPay untuk makan',
      );

      expect(transferTxId, isNotEmpty);

      // 5. Verifikasi Saldo Akhir (Test T01 Acceptance Criteria)
      // Bank = Rp1.000.000 - Rp200.000 - Rp2.500 = Rp797.500
      final bankBalance = await repository.dao.getWalletBalance(bankId);
      expect(bankBalance, 797500);

      // E-Wallet = Rp0 + Rp200.000 = Rp200.000
      final ewalletBalance = await repository.dao.getWalletBalance(ewalletId);
      expect(ewalletBalance, 200000);

      // Total saldo sistem = Rp797.500 + Rp200.000 = Rp997.500
      final totalBalance = await repository.dao.watchTotalBalance().first;
      expect(totalBalance, 997500);

      // 6. Verifikasi Laporan Pengeluaran Kategori: Hanya mencatat pengeluaran Rp2.500
      final feeExpense = await repository.dao.getCategoryExpenseForMonth(feeCatId, '2026-10-01');
      expect(feeExpense, 2500);

      // 7. Verifikasi Outbox Sinkronisasi Atomik
      final outboxItems = await db.select(db.syncOutbox).get();
      final transferOutbox = outboxItems.where((o) => o.aggregateType == 'wallet_transfer').toList();
      expect(transferOutbox, hasLength(1));

      // Payload outbox menyimpan data transfer atomik dan rujukan transaksi fee
      expect(transferOutbox.first.payloadJson, contains('"amount_rp":200000'));
      expect(transferOutbox.first.payloadJson, contains('"fee_rp":2500'));
    });

    test('Gate Test T02: Edit dan void transaksi memutasi ledger & budget secara atomik', () async {
      // 1. Buat Dompet Tunai dengan saldo awal Rp100.000
      final cashId = await repository.createWallet(
        name: 'Dompet Fisik',
        walletType: 'cash',
        initialBalanceRp: 100000,
      );

      // 2. Buat Kategori Makan
      final foodCatId = await repository.createCategory(
        name: 'Makan & Minum',
        direction: 'expense',
      );

      // 3. Buat Budget Bulan Oktober Rp200.000
      await repository.setBudget(
        categoryId: foodCatId,
        monthStart: '2026-10-01',
        limitRp: 200000,
      );

      // 4. Catat Pengeluaran Makan Rp50.000
      final txId = await repository.createExpense(
        walletId: cashId,
        amountRp: 50000,
        categoryId: foodCatId,
        localDate: '2026-10-11',
        note: 'Nasi Padang',
      );

      // Verifikasi saldo dompet berkurang menjadi Rp50.000
      expect(await repository.dao.getWalletBalance(cashId), 50000);

      // Verifikasi budget terpakai menjadi Rp50.000
      var spent = await repository.dao.getCategoryExpenseForMonth(foodCatId, '2026-10-01');
      expect(spent, 50000);

      // 5. Batalkan Transaksi (Void Transaction)
      await repository.voidTransaction(txId);

      // Verifikasi saldo dompet kembali utuh menjadi Rp100.000
      expect(await repository.dao.getWalletBalance(cashId), 100000);

      // Verifikasi pengeluaran budget kembali menjadi Rp0
      spent = await repository.dao.getCategoryExpenseForMonth(foodCatId, '2026-10-01');
      expect(spent, 0);

      // Verifikasi status transaksi di database menjadi 'void'
      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
      expect(tx.status, 'void');

      // Verifikasi tercatat di outbox
      final voidOutbox = await (db.select(db.syncOutbox)..where((o) => o.aggregateType.equals('void_transaction'))).get();
      expect(voidOutbox, hasLength(1));
    });

    test('Budget dengan Refund dan Peringatan 80% / 100%', () async {
      final walletId = await repository.createWallet(
        name: 'Bank BCA',
        walletType: 'bank',
        initialBalanceRp: 1000000,
      );

      final catId = await repository.createCategory(
        name: 'Belanja Bulanan',
        direction: 'expense',
      );

      final budgetId = await repository.setBudget(
        categoryId: catId,
        monthStart: '2026-10-01',
        limitRp: 100000, // Budget 100rb
      );

      expect(budgetId, isNotEmpty);

      // Pengeluaran 1: Rp70.000 (70% - Normal)
      await repository.createExpense(
        walletId: walletId,
        amountRp: 70000,
        categoryId: catId,
        localDate: '2026-10-05',
      );

      var progressList = await repository.dao.watchBudgetProgress('2026-10-01').first;
      var bp = progressList.firstWhere((p) => p.budget.categoryId == catId);
      expect(bp.spentRp, 70000);
      expect(bp.remainingRp, 30000);
      expect(bp.percentValue, 70.0);
      expect(bp.isWarning80, isFalse);
      expect(bp.isOverBudget, isFalse);

      // Pengeluaran 2: Tambah Rp15.000 (Total 85rb = 85% - Warning 80%)
      await repository.createExpense(
        walletId: walletId,
        amountRp: 15000,
        categoryId: catId,
        localDate: '2026-10-06',
      );

      progressList = await repository.dao.watchBudgetProgress('2026-10-01').first;
      bp = progressList.firstWhere((p) => p.budget.categoryId == catId);
      expect(bp.spentRp, 85000);
      expect(bp.isWarning80, isTrue);
      expect(bp.isOverBudget, isFalse);

      // Pengeluaran 3: Tambah Rp25.000 (Total 110rb = 110% - Over Budget)
      await repository.createExpense(
        walletId: walletId,
        amountRp: 25000,
        categoryId: catId,
        localDate: '2026-10-07',
      );

      progressList = await repository.dao.watchBudgetProgress('2026-10-01').first;
      bp = progressList.firstWhere((p) => p.budget.categoryId == catId);
      expect(bp.spentRp, 110000);
      expect(bp.remainingRp, -10000);
      expect(bp.isOverBudget, isTrue);

      // Refund: Rp30.000 dikembalikan (Net spent = 110rb - 30rb = 80rb)
      await repository.createIncome(
        walletId: walletId,
        amountRp: 30000,
        categoryId: catId,
        localDate: '2026-10-08',
        isRefund: true,
      );

      progressList = await repository.dao.watchBudgetProgress('2026-10-01').first;
      bp = progressList.firstWhere((p) => p.budget.categoryId == catId);
      expect(bp.spentRp, 80000);
      expect(bp.remainingRp, 20000);
      expect(bp.isOverBudget, isFalse);
      expect(bp.isWarning80, isTrue);
    });

    test('Saving Goals dan Alokasi Tabungan tidak memutasi saldo real dompet', () async {
      final walletId = await repository.createWallet(
        name: 'Tabungan Utama',
        walletType: 'bank',
        initialBalanceRp: 5000000,
      );

      final goalId = await repository.createSavingGoal(
        name: 'Dana Darurat 6 Bulan',
        targetRp: 10000000,
        targetDate: '2027-10-01',
      );

      // 1. Alokasi Rp1.000.000 ke target tabungan
      await repository.allocateSavings(
        goalId: goalId,
        walletId: walletId,
        amountRp: 1000000,
        note: 'Sisihkan dari gaji',
      );

      var goals = await repository.dao.watchSavingGoalsWithProgress().first;
      var goal = goals.firstWhere((g) => g.goal.id == goalId);
      expect(goal.allocatedRp, 1000000);
      expect(goal.remainingRp, 9000000);
      expect(goal.percentValue, 10.0);

      // Saldo dompet real HARUS tetap Rp5.000.000 (aturan PRD: tabungan adalah alokasi partisi, bukan pengeluaran ganda)
      final walletBalance = await repository.dao.getWalletBalance(walletId);
      expect(walletBalance, 5000000);

      // 2. Tarik kembali alokasi Rp200.000 (penarikan alokasi)
      await repository.withdrawSavings(
        goalId: goalId,
        walletId: walletId,
        amountRp: 200000,
        note: 'Ambil untuk kebutuhan mendesak',
      );

      goals = await repository.dao.watchSavingGoalsWithProgress().first;
      goal = goals.firstWhere((g) => g.goal.id == goalId);
      expect(goal.allocatedRp, 800000);
      expect(goal.remainingRp, 9200000);
      expect(goal.percentValue, 8.0);
    });
  });
}
