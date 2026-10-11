import 'package:drift/drift.dart';

import '../../features/finance/data/finance_dao.dart';
import 'database_connection.dart';
import 'tables/profile_and_sync_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/inventory_tables.dart';
import 'tables/agenda_tables.dart';
import 'tables/bills_documents_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Profile & Infrastruktur Sinkronisasi
    Profiles,
    SyncOutbox,
    SyncCursors,
    SyncConflicts,
    AttachmentJobs,
    LocalSettings,

    // Keuangan & Budgeting
    Wallets,
    Categories,
    Transactions,
    WalletEntries,
    TransactionItems,
    Budgets,
    SavingGoals,
    SavingAllocations,
    ReceiptParses,

    // Inventaris & Belanja
    InventoryItems,
    InventoryMovements,
    ShoppingLists,
    ShoppingListItems,
    ShoppingPurchases,
    ShoppingPurchaseItems,
    PriceHistory,

    // Agenda & Tugas
    ActivityCalendars,
    ActivityEvents,
    ActivityEventExceptions,
    Tasks,
    TaskChecklistItems,
    QuickNotes,

    // Tagihan, Dokumen, Lampiran & Kripto
    BillTemplates,
    BillOccurrences,
    BillPayments,
    Documents,
    Attachments,
    AttachmentLinks,
    ReminderRules,
    UserKeyEnvelopes,
  ],
  daos: [
    FinanceDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openDatabaseConnection());

  factory AppDatabase.inMemory() {
    return AppDatabase(openDatabaseConnection(inMemory: true));
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Upgrade skema masa depan didokumentasikan di sini
        },
      );
}
