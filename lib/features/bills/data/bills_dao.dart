import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/bills_documents_tables.dart';
import '../../../core/database/tables/finance_tables.dart';
import '../domain/models/bill_models.dart';

part 'bills_dao.g.dart';

@DriftAccessor(tables: [
  BillTemplates,
  BillOccurrences,
  BillPayments,
  Transactions,
  Categories,
])
class BillsDao extends DatabaseAccessor<AppDatabase> with _$BillsDaoMixin {
  BillsDao(super.db);

  /// Stream daftar template tagihan aktif
  Stream<List<BillTemplate>> watchBillTemplates() {
    return (select(billTemplates)
          ..where((t) => t.isActive.equals(true) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Stream kejadian tagihan untuk bulan tertentu (e.g. periodKey "2026-10")
  /// lengkap dengan riwayat pembayaran transaksi aktif dan status dinamis (Test T03)
  Stream<List<BillOccurrenceWithStatus>> watchOccurrencesForPeriod(String periodKey) {
    final query = select(billOccurrences).join([
      innerJoin(billTemplates, billTemplates.id.equalsExp(billOccurrences.templateId)),
    ])
      ..where(billOccurrences.periodKey.equals(periodKey))
      ..where(billOccurrences.cancelledAt.isNull())
      ..where(billOccurrences.deletedAt.isNull());

    return query.watch().asyncMap((rows) async {
      final result = <BillOccurrenceWithStatus>[];
      for (final row in rows) {
        final occ = row.readTable(billOccurrences);
        final tmpl = row.readTable(billTemplates);

        // Ambil pembayaran yang terhubung ke transaksi aktif (status = 'posted')
        final paymentsQuery = select(billPayments).join([
          innerJoin(transactions, transactions.id.equalsExp(billPayments.transactionId)),
        ])
          ..where(billPayments.billOccurrenceId.equals(occ.id))
          ..where(transactions.status.equals('posted'))
          ..where(transactions.deletedAt.isNull())
          ..where(billPayments.deletedAt.isNull());

        final paymentRows = await paymentsQuery.get();
        final paymentsList = paymentRows.map((r) => r.readTable(billPayments)).toList();

        result.add(BillOccurrenceWithStatus(
          template: tmpl,
          occurrence: occ,
          payments: paymentsList,
        ));
      }
      return result;
    });
  }

  /// Mengambil satu occurrence tagihan dengan detail status
  Future<BillOccurrenceWithStatus?> getOccurrenceWithStatus(String occurrenceId) async {
    final occ = await (select(billOccurrences)..where((t) => t.id.equals(occurrenceId))).getSingleOrNull();
    if (occ == null) return null;

    final tmpl = await (select(billTemplates)..where((t) => t.id.equals(occ.templateId))).getSingle();

    final paymentsQuery = select(billPayments).join([
      innerJoin(transactions, transactions.id.equalsExp(billPayments.transactionId)),
    ])
      ..where(billPayments.billOccurrenceId.equals(occ.id))
      ..where(transactions.status.equals('posted'))
      ..where(transactions.deletedAt.isNull())
      ..where(billPayments.deletedAt.isNull());

    final paymentRows = await paymentsQuery.get();
    final paymentsList = paymentRows.map((r) => r.readTable(billPayments)).toList();

    return BillOccurrenceWithStatus(
      template: tmpl,
      occurrence: occ,
      payments: paymentsList,
    );
  }
}
