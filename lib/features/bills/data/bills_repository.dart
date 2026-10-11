import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/models/bill_models.dart';
import 'bills_dao.dart';

class BillsRepository {
  final AppDatabase _db;
  final BillsDao _dao;
  final NotificationService _notificationService;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  BillsRepository({
    required AppDatabase db,
    BillsDao? dao,
    NotificationService? notificationService,
    FlutterSecureStorage? secureStorage,
  })  : _db = db,
        _dao = dao ?? BillsDao(db),
        _notificationService = notificationService ?? NotificationService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  BillsDao get dao => _dao;

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

  /// 1. Buat Template Tagihan Rutin (BIL01)
  Future<String> createBillTemplate({
    required String name,
    required String categoryId,
    int? estimatedAmountRp,
    String frequency = 'monthly', // once, weekly, monthly, yearly
    int intervalCount = 1,
    required String anchorDate, // YYYY-MM-DD
    String? endDate,
    String? note,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final templateId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.billTemplates).insert(
            BillTemplatesCompanion.insert(
              id: templateId,
              userId: userId,
              name: name,
              categoryId: categoryId,
              estimatedAmountRp: Value(estimatedAmountRp),
              frequency: frequency,
              intervalCount: Value(intervalCount),
              anchorDate: anchorDate,
              endDate: Value(endDate),
              isActive: const Value(true),
              note: Value(note),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'bill_template',
              aggregateId: templateId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'name': name,
                'frequency': frequency,
                'anchor_date': anchorDate,
                'estimated_amount_rp': estimatedAmountRp,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    // Otomatis buat kejadian untuk bulan berjalan
    final nowDt = DateTime.now();
    await generateOccurrencesForMonth(year: nowDt.year, month: nowDt.month);

    return templateId;
  }

  /// 2. Generate Kejadian Tagihan Deterministik untuk Bulan Tertentu (Gate Test T09)
  /// Menerapkan aturan Anchor 31 secara presisi pada bulan pendek tanpa duplikasi period key
  Future<List<String>> generateOccurrencesForMonth({
    required int year,
    required int month,
  }) async {
    final templates = await (_db.select(_db.billTemplates)
          ..where((t) => t.isActive.equals(true) & t.deletedAt.isNull()))
        .get();

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final periodKey = BillRecurrenceEngine.formatPeriodKey(year, month);
    final now = DateTime.now().millisecondsSinceEpoch;
    final createdIds = <String>[];

    for (final tmpl in templates) {
      // Periksa apakah occurrence untuk template dan periodKey ini sudah ada
      final existing = await (_db.select(_db.billOccurrences)
            ..where((t) =>
                t.templateId.equals(tmpl.id) &
                t.periodKey.equals(periodKey) &
                t.deletedAt.isNull()))
          .getSingleOrNull();

      if (existing != null) continue;

      // Hitung tanggal jatuh tempo sesuai aturan Anchor 31 (Test T09)
      final dueDateDt = BillRecurrenceEngine.computeDueDateForMonth(
        anchorDateStr: tmpl.anchorDate,
        targetYear: year,
        targetMonth: month,
      );
      final dueDateStr = BillRecurrenceEngine.formatDueDateString(dueDateDt);

      final occId = _uuid.v4();
      final opId = _uuid.v4();

      await _db.into(_db.billOccurrences).insert(
            BillOccurrencesCompanion.insert(
              id: occId,
              userId: userId,
              templateId: tmpl.id,
              periodKey: periodKey,
              dueDate: dueDateStr,
              amountDueRp: Value(tmpl.estimatedAmountRp),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      createdIds.add(occId);

      // Jadwalkan notifikasi pengingat jatuh tempo H-3 dan hari H
      try {
        final notifId = _notificationService.generateId(occId);
        await _notificationService.scheduleNotification(
          id: notifId,
          channelId: NotificationService.channelBills,
          title: 'Jatuh Tempo Tagihan: ${tmpl.name}',
          body: 'Jatuh tempo pada $dueDateStr. Segera bayar atau catat pembayaran.',
          scheduledDate: dueDateDt.subtract(const Duration(days: 1)),
        );
      } catch (_) {}
    }

    return createdIds;
  }

  /// Helper untuk generate kejadian tagihan berdasarkan periodKey "YYYY-MM"
  Future<List<String>> generateOccurrencesForPeriod(String periodKey) async {
    final parts = periodKey.split('-');
    if (parts.length != 2) return [];
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    return generateOccurrencesForMonth(year: year, month: month);
  }

  /// 3. Bayar Tagihan Secara Atomik Terintegrasi dengan Modul Keuangan (BIL04 & Gate Test T03)
  /// Membuat transaksi pengeluaran di dompet dan entri bill_payments dalam satu transaksi DB
  Future<String> payBillOccurrence({
    required String occurrenceId,
    required String walletId,
    required int amountRp,
    required String localDate,
    String? note,
  }) async {
    if (amountRp <= 0) {
      throw ArgumentError('Nominal pembayaran tagihan harus lebih besar dari Rp0');
    }

    final occDetail = await _dao.getOccurrenceWithStatus(occurrenceId);
    if (occDetail == null) {
      throw ArgumentError('Kejadian tagihan tidak ditemukan');
    }

    // Validasi tidak melebihi sisa tagihan
    if (amountRp > occDetail.remainingRp) {
      throw ArgumentError('Nominal pembayaran (Rp$amountRp) melebihi sisa tagihan (Rp${occDetail.remainingRp})');
    }

    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final txId = _uuid.v4();
    final paymentId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Simpan Transaksi Pengeluaran Keuangan
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              userId: userId,
              kind: 'expense',
              amountRp: amountRp,
              categoryId: Value(occDetail.template.categoryId),
              occurredAt: now,
              localDate: localDate,
              note: Value(note ?? 'Bayar ${occDetail.template.name} ($amountRp)'),
              source: const Value('bill_payment'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 2. Simpan Mutasi Dompet (Pengurangan Saldo)
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

      // 3. Simpan Entri Pembayaran Tagihan
      await _db.into(_db.billPayments).insert(
            BillPaymentsCompanion.insert(
              id: paymentId,
              userId: userId,
              billOccurrenceId: occurrenceId,
              transactionId: txId,
              amountRp: amountRp,
              paidAt: now,
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // 4. Catat ke Outbox
      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'bill_payment',
              aggregateId: paymentId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'occurrence_id': occurrenceId,
                'transaction_id': txId,
                'amount_rp': amountRp,
                'wallet_id': walletId,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    // Periksa status terbaru setelah pembayaran; jika lunas, batalkan notifikasi pengingat
    final updated = await _dao.getOccurrenceWithStatus(occurrenceId);
    if (updated != null && updated.status == BillStatus.paid) {
      final notifId = _notificationService.generateId(occurrenceId);
      await _notificationService.cancelNotification(notifId);
    }

    return paymentId;
  }
}
