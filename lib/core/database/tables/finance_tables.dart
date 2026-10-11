import 'package:drift/drift.dart';
import 'common_columns.dart';

/// Tabel Dompet / Rekening Keuangan (GAMINI.md Bagian 6.2)
class Wallets extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  TextColumn get walletType => text()(); // cash, bank, ewallet, other
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Tabel Kategori Pemasukan / Pengeluaran (GAMINI.md Bagian 6.2)
class Categories extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  TextColumn get direction => text()(); // income, expense
  TextColumn get iconKey => text().withDefault(const Constant('category'))();
  TextColumn get colorKey => text().withDefault(const Constant('indigo'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

/// Header Transaksi Keuangan (GAMINI.md Bagian 6.2)
class Transactions extends Table with CommonDomainColumns {
  TextColumn get kind => text()(); // income, expense, transfer, opening, adjustment, refund
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, void
  IntColumn get amountRp => integer()(); // integer rupiah murni > 0 (int 64-bit Dart)
  TextColumn get categoryId => text().nullable()();
  IntColumn get occurredAt => integer()(); // epoch millis UTC
  TextColumn get localDate => text()(); // YYYY-MM-DD
  TextColumn get timezone => text().withDefault(const Constant('Asia/Jakarta'))();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))(); // manual, receipt, recurring
  TextColumn get refundOfId => text().nullable()();
}

/// Mutasi Ledger Dompet Atomik (GAMINI.md Bagian 6.2)
class WalletEntries extends Table with CommonDomainColumns {
  TextColumn get transactionId => text()();
  TextColumn get walletId => text()();
  IntColumn get amountRp => integer()(); // bernilai positif untuk debet/masuk, negatif untuk kredit/keluar
  TextColumn get entryRole => text()(); // main, source, destination, fee
}

/// Detail Baris Transaksi / Hasil Parse Struk (GAMINI.md Bagian 6.2)
class TransactionItems extends Table with CommonDomainColumns {
  TextColumn get transactionId => text()();
  IntColumn get lineNo => integer()();
  TextColumn get name => text()();
  IntColumn get quantityMilli => integer().nullable()(); // integer milli-unit (1 unit = 1000)
  TextColumn get unit => text().nullable()();
  IntColumn get unitPriceRp => integer().nullable()();
  IntColumn get lineTotalRp => integer().nullable()();
  TextColumn get inventoryItemId => text().nullable()();
}

/// Budget Bulanan per Kategori (GAMINI.md Bagian 6.2)
class Budgets extends Table with CommonDomainColumns {
  TextColumn get categoryId => text()();
  TextColumn get monthStart => text()(); // YYYY-MM-01
  IntColumn get limitRp => integer()();
  IntColumn get warningPercent => integer().withDefault(const Constant(80))();
}

/// Target Tabungan (GAMINI.md Bagian 6.2)
class SavingGoals extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  IntColumn get targetRp => integer()();
  TextColumn get targetDate => text().nullable()(); // YYYY-MM-DD
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

/// Alokasi Tabungan dari Dompet (GAMINI.md Bagian 6.2)
class SavingAllocations extends Table with CommonDomainColumns {
  TextColumn get goalId => text()();
  TextColumn get walletId => text()();
  IntColumn get amountRp => integer()(); // positif = alokasi, negatif = tarik alokasi
  IntColumn get allocatedAt => integer()(); // epoch millis UTC
  TextColumn get reversesId => text().nullable()();
  TextColumn get note => text().nullable()();
}

/// Draf Parse Struk Terenkripsi (GAMINI.md Bagian 6.2)
class ReceiptParses extends Table with CommonDomainColumns {
  TextColumn get attachmentId => text()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get parserVersion => text().withDefault(const Constant('1.0'))();
  TextColumn get state => text().withDefault(const Constant('draft'))(); // draft, confirmed, discarded
  BlobColumn get encryptedPayload => blob()();
  TextColumn get cryptoContextId => text()();
  IntColumn get cryptoVersion => integer().withDefault(const Constant(1))();
  IntColumn get keyVersion => integer().withDefault(const Constant(1))();
  BlobColumn get nonce => blob()();
}
