import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/bills_dao.dart';
import '../../data/bills_repository.dart';
import '../../domain/models/bill_models.dart';

/// Provider singleton untuk BillsRepository
final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return BillsRepository(db: db, notificationService: notif);
});

/// Provider DAO Tagihan
final billsDaoProvider = Provider<BillsDao>((ref) {
  return ref.watch(billsRepositoryProvider).dao;
});

/// Stream daftar template tagihan aktif
final billTemplatesStreamProvider = StreamProvider<List<BillTemplate>>((ref) {
  return ref.watch(billsDaoProvider).watchBillTemplates();
});

/// Stream kejadian tagihan untuk bulan tertentu (format periodKey: "YYYY-MM")
final billOccurrencesForPeriodProvider =
    StreamProvider.family<List<BillOccurrenceWithStatus>, String>((ref, periodKey) {
  return ref.watch(billsDaoProvider).watchOccurrencesForPeriod(periodKey);
});
