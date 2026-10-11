import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import 'finance_dao.dart';

class FinanceRepository {
  final AppDatabase _db;
  final FinanceDao _dao;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  FinanceRepository({
    required AppDatabase db,
    FinanceDao? dao,
    FlutterSecureStorage? secureStorage,
  })  : _db = db,
        _dao = dao ?? FinanceDao(db),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  FinanceDao get dao => _dao;

  /// Mengambil atau membuat ID instalasi perangkat yang stabil
  Future<String> _getDeviceId() async {
    var id = await _secureStorage.read(key: AppConstants.secKeyDeviceId);
    if (id == null) {
      id = _uuid.v4();
      await _secureStorage.write(key: AppConstants.secKeyDeviceId, value: id);
    }
    return id;
  }

  /// Mengambil ID pemilik lokal (default ke user profil atau lokal)
  Future<String> _getUserId() async {
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    return profile?.id ?? '00000000-0000-0000-0000-000000000001';
  }

  /// 1. Catat Pengeluaran (Expense)
  /// Sesuai PRD FIN01 & Aturan Bisnis Uang
  Future<String> createExpense({
    required String walletId,
    required int amountRp,
    required String categoryId,
    required String localDate,
    String? merchant,
    String? note,
    int? occurredAt,
  }) async {
    if (amountRp <= 0) {
      throw ArgumentError('Nominal pengeluaran harus lebih besar dari 0');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final now = occurredAt ?? DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Simpan Header Transaksi
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              kind: 'expense',
              amountRp: amountRp,
              categoryId: Value(categoryId),
              occurredAt: now,
              localDate: localDate,
              merchant: Value(merchant),
              note: Value(note),
              source: const Value('manual'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 2. Simpan Ledger Mutasi Negatif (Kredit)
      await _db.into(_db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              transactionId: txId,
              walletId: walletId,
              amountRp: -amountRp,
              entryRole: 'main',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 3. Masukkan ke Outbox Sinkronisasi
      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'transaction',
              aggregateId: txId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'kind': 'expense',
                'amount_rp': amountRp,
                'wallet_id': walletId,
                'category_id': categoryId,
                'local_date': localDate,
                'merchant': merchant,
                'note': note,
                'occurred_at': now,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return txId;
  }

  /// 2. Catat Pemasukan (Income) atau Pengembalian Dana (Refund)
  Future<String> createIncome({
    required String walletId,
    required int amountRp,
    required String categoryId,
    required String localDate,
    String? merchant,
    String? note,
    bool isRefund = false,
    int? occurredAt,
  }) async {
    if (amountRp <= 0) {
      throw ArgumentError('Nominal pemasukan harus lebih besar dari 0');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final now = occurredAt ?? DateTime.now().millisecondsSinceEpoch;
    final txKind = isRefund ? 'refund' : 'income';

    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              kind: txKind,
              amountRp: amountRp,
              categoryId: Value(categoryId),
              occurredAt: now,
              localDate: localDate,
              merchant: Value(merchant),
              note: Value(note),
              source: const Value('manual'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              transactionId: txId,
              walletId: walletId,
              amountRp: amountRp,
              entryRole: 'main',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'transaction',
              aggregateId: txId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'kind': txKind,
                'amount_rp': amountRp,
                'wallet_id': walletId,
                'category_id': categoryId,
                'local_date': localDate,
                'merchant': merchant,
                'note': note,
                'occurred_at': now,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return txId;
  }

  /// 3. Transfer Antar-Dompet Atomik (FIN03 & Test T01)
  /// Dompet asal dan tujuan berbeda.
  /// Biaya transfer dicatat sebagai pengeluaran terpisah dalam transaksi atomik yang sama.
  Future<String> createTransfer({
    required String sourceWalletId,
    required String destWalletId,
    required int amountRp,
    int feeRp = 0,
    String? feeCategoryId,
    required String localDate,
    String? note,
    int? occurredAt,
  }) async {
    if (sourceWalletId == destWalletId) {
      throw ArgumentError('Dompet asal dan tujuan harus berbeda');
    }
    if (amountRp <= 0) {
      throw ArgumentError('Nominal transfer harus lebih besar dari 0');
    }
    if (feeRp < 0) {
      throw ArgumentError('Biaya transfer tidak boleh negatif');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final now = occurredAt ?? DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Transaksi Transfer Utama
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              kind: 'transfer',
              amountRp: amountRp,
              occurredAt: now,
              localDate: localDate,
              note: Value(note),
              source: const Value('manual'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // Entry Asal (Pengurangan saldo)
      await _db.into(_db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              transactionId: txId,
              walletId: sourceWalletId,
              amountRp: -amountRp,
              entryRole: 'source',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // Entry Tujuan (Penambahan saldo)
      await _db.into(_db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              transactionId: txId,
              walletId: destWalletId,
              amountRp: amountRp,
              entryRole: 'destination',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 2. Jika Ada Biaya Transfer (Fee), catat sebagai transaksi Expense terpisah dalam operasi yang sama
      String? feeTxId;
      if (feeRp > 0) {
        feeTxId = _uuid.v4();
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: feeTxId,
                userId: userId,
                kind: 'expense',
                amountRp: feeRp,
                categoryId: Value(feeCategoryId),
                occurredAt: now,
                localDate: localDate,
                note: const Value('Biaya transfer'),
                source: const Value('manual'),
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );

        await _db.into(_db.walletEntries).insert(
              WalletEntriesCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                transactionId: feeTxId,
                walletId: sourceWalletId,
                amountRp: -feeRp,
                entryRole: 'fee',
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );
      }

      // 3. Masukkan ke Outbox
      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'wallet_transfer',
              aggregateId: txId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'source_wallet_id': sourceWalletId,
                'dest_wallet_id': destWalletId,
                'amount_rp': amountRp,
                'fee_rp': feeRp,
                'fee_tx_id': feeTxId,
                'local_date': localDate,
                'note': note,
                'occurred_at': now,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return txId;
  }

  /// 4. Catat Saldo Awal (Opening Balance)
  /// Menggunakan jenis transaksi 'opening', bukan income
  Future<String> createOpeningBalance({
    required String walletId,
    required int amountRp,
    required String localDate,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              kind: 'opening',
              amountRp: amountRp,
              occurredAt: now,
              localDate: localDate,
              note: const Value('Saldo awal'),
              source: const Value('manual'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.walletEntries).insert(
            WalletEntriesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              transactionId: txId,
              walletId: walletId,
              amountRp: amountRp,
              entryRole: 'main',
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );
    });

    return txId;
  }

  /// 5. Batalkan Transaksi Secara Aman (Void Transaction) (Test T02)
  /// Menandai status='void', mengeluarkan dari perhitungan ledger & budget, dan mencatat outbox
  Future<void> voidTransaction(String transactionId) async {
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      final tx = await (_db.select(_db.transactions)..where((t) => t.id.equals(transactionId))).getSingleOrNull();
      if (tx == null) {
        throw ArgumentError('Transaksi tidak ditemukan');
      }

      final nextVersion = tx.version + 1;
      final nextLocalRev = tx.localRevision + 1;

      // Update status menjadi 'void'
      await (_db.update(_db.transactions)..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          status: const Value('void'),
          updatedAt: Value(now),
          version: Value(nextVersion),
          localRevision: Value(nextLocalRev),
          lastOperationId: Value(opId),
          syncState: const Value('pending'),
        ),
      );

      // Catat ke outbox
      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'void_transaction',
              aggregateId: transactionId,
              baseVersion: tx.version,
              payloadJson: jsonEncode({
                'transaction_id': transactionId,
                'status': 'void',
                'updated_at': now,
              }),
              localRevision: nextLocalRev,
              createdAt: now,
            ),
          );
    });
  }

  /// 6. Buat Dompet Baru
  Future<String> createWallet({
    required String name,
    required String walletType, // cash, bank, ewallet, other
    int initialBalanceRp = 0,
    int sortOrder = 0,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final walletId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.wallets).insert(
            WalletsCompanion.insert(
              id: walletId,
              userId: userId,
              name: name,
              walletType: walletType,
              sortOrder: Value(sortOrder),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      if (initialBalanceRp > 0) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await createOpeningBalance(
          walletId: walletId,
          amountRp: initialBalanceRp,
          localDate: today,
        );
      }
    });

    return walletId;
  }

  /// 7. Buat Kategori Baru
  Future<String> createCategory({
    required String name,
    required String direction, // income, expense
    String iconKey = 'category',
    String colorKey = 'indigo',
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final catId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: catId,
            userId: userId,
            name: name,
            direction: direction,
            iconKey: Value(iconKey),
            colorKey: Value(colorKey),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return catId;
  }

  /// 8. Atur Budget Bulanan per Kategori
  Future<String> setBudget({
    required String categoryId,
    required String monthStart, // YYYY-MM-01
    required int limitRp,
    int warningPercent = 80,
  }) async {
    if (limitRp <= 0) {
      throw ArgumentError('Limit budget harus lebih besar dari 0');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Periksa apakah budget bulan ini untuk kategori ini sudah ada
    final existing = await (_db.select(_db.budgets)
          ..where((t) => t.categoryId.equals(categoryId) & t.monthStart.equals(monthStart)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((t) => t.id.equals(existing.id))).write(
        BudgetsCompanion(
          limitRp: Value(limitRp),
          warningPercent: Value(warningPercent),
          updatedAt: Value(now),
          lastOperationId: Value(opId),
          version: Value(existing.version + 1),
          localRevision: Value(existing.localRevision + 1),
          syncState: const Value('pending'),
        ),
      );
      return existing.id;
    } else {
      final budgetId = _uuid.v4();
      await _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(
              id: budgetId,
              userId: userId,
              categoryId: categoryId,
              monthStart: monthStart,
              limitRp: limitRp,
              warningPercent: Value(warningPercent),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );
      return budgetId;
    }
  }

  /// 9. Buat Target Tabungan (Saving Goal)
  Future<String> createSavingGoal({
    required String name,
    required int targetRp,
    String? targetDate, // YYYY-MM-DD
  }) async {
    if (targetRp <= 0) {
      throw ArgumentError('Target nominal tabungan harus lebih besar dari 0');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final goalId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.savingGoals).insert(
          SavingGoalsCompanion.insert(
            id: goalId,
            userId: userId,
            name: name,
            targetRp: targetRp,
            targetDate: Value(targetDate),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return goalId;
  }

  /// 10. Alokasi Tabungan dari Dompet (FIN06)
  /// Alokasi tidak memindahkan uang riil atau menggandakan saldo, melainkan pembagian tujuan
  Future<String> allocateSavings({
    required String goalId,
    required String walletId,
    required int amountRp,
    String? note,
  }) async {
    if (amountRp <= 0) {
      throw ArgumentError('Nominal alokasi tabungan harus lebih besar dari 0');
    }

    // Periksa saldo dompet saat ini
    final currentBalance = await _dao.getWalletBalance(walletId);
    if (currentBalance < amountRp) {
      throw StateError('Saldo dompet tidak mencukupi untuk dialokasikan');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final allocId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.savingAllocations).insert(
          SavingAllocationsCompanion.insert(
            id: allocId,
            userId: userId,
            goalId: goalId,
            walletId: walletId,
            amountRp: amountRp,
            allocatedAt: now,
            note: Value(note),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return allocId;
  }

  /// 11. Tarik Alokasi Tabungan (Withdraw Allocation)
  Future<String> withdrawSavings({
    required String goalId,
    required String walletId,
    required int amountRp,
    String? note,
  }) async {
    if (amountRp <= 0) {
      throw ArgumentError('Nominal penarikan alokasi harus lebih besar dari 0');
    }

    final currentAlloc = await _dao.getSavingGoalAllocation(goalId);
    if (currentAlloc < amountRp) {
      throw StateError('Total alokasi tabungan tidak mencukupi untuk ditarik');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final allocId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Nilai negatif menandakan penarikan alokasi
    await _db.into(_db.savingAllocations).insert(
          SavingAllocationsCompanion.insert(
            id: allocId,
            userId: userId,
            goalId: goalId,
            walletId: walletId,
            amountRp: -amountRp,
            allocatedAt: now,
            note: Value(note),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return allocId;
  }

  /// 12. Inisialisasi Kategori & Dompet Default Jika Kosong
  Future<void> seedDefaultsIfEmpty() async {
    final existingWallets = await (_db.select(_db.wallets)..where((t) => t.deletedAt.isNull())).get();
    if (existingWallets.isEmpty) {
      await createWallet(name: 'Dompet Tunai', walletType: 'cash', initialBalanceRp: 0, sortOrder: 1);
      await createWallet(name: 'Rekening Bank', walletType: 'bank', initialBalanceRp: 0, sortOrder: 2);
      await createWallet(name: 'E-Wallet', walletType: 'ewallet', initialBalanceRp: 0, sortOrder: 3);
    }

    final existingCats = await (_db.select(_db.categories)..where((t) => t.deletedAt.isNull())).get();
    if (existingCats.isEmpty) {
      // Kategori Pengeluaran
      await createCategory(name: 'Makan & Minum', direction: 'expense', iconKey: 'restaurant', colorKey: 'deepOrange');
      await createCategory(name: 'Kost & Tagihan', direction: 'expense', iconKey: 'home', colorKey: 'indigo');
      await createCategory(name: 'Transportasi', direction: 'expense', iconKey: 'directions_bus', colorKey: 'blue');
      await createCategory(name: 'Belanja Harian', direction: 'expense', iconKey: 'shopping_bag', colorKey: 'teal');
      await createCategory(name: 'Biaya Transfer', direction: 'expense', iconKey: 'swap_horiz', colorKey: 'purple');
      await createCategory(name: 'Lain-lain', direction: 'expense', iconKey: 'more_horiz', colorKey: 'grey');

      // Kategori Pemasukan
      await createCategory(name: 'Gaji / Upah Magang', direction: 'income', iconKey: 'account_balance_wallet', colorKey: 'green');
      await createCategory(name: 'Kiriman Ortu', direction: 'income', iconKey: 'family_restroom', colorKey: 'lightBlue');
      await createCategory(name: 'Bonus / Lainnya', direction: 'income', iconKey: 'card_giftcard', colorKey: 'amber');
    }
  }
}
