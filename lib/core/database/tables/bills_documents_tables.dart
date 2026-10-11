import 'package:drift/drift.dart';
import 'common_columns.dart';

/// Template Tagihan Rutin Kost / Utilitas (GAMINI.md Bagian 6.5)
class BillTemplates extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  TextColumn get categoryId => text()();
  IntColumn get estimatedAmountRp => integer().nullable()();
  TextColumn get frequency => text()(); // once, weekly, monthly, yearly
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  TextColumn get anchorDate => text()(); // YYYY-MM-DD (e.g. tgl 31)
  TextColumn get endDate => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();
}

/// Kejadian Tagihan per Periode (GAMINI.md Bagian 6.5)
class BillOccurrences extends Table with CommonDomainColumns {
  TextColumn get templateId => text()();
  TextColumn get periodKey => text()(); // e.g. "2026-10"
  TextColumn get dueDate => text()(); // YYYY-MM-DD
  IntColumn get amountDueRp => integer().nullable()();
  BoolColumn get amountConfirmed => boolean().withDefault(const Constant(false))();
  IntColumn get cancelledAt => integer().nullable()(); // epoch millis
  TextColumn get note => text().nullable()();
}

/// Relasi Pembayaran Tagihan ke Transaksi Keuangan (GAMINI.md Bagian 6.5)
class BillPayments extends Table with CommonDomainColumns {
  TextColumn get billOccurrenceId => text()();
  TextColumn get transactionId => text()();
  IntColumn get amountRp => integer()();
  IntColumn get paidAt => integer()(); // epoch millis UTC
}

/// Dokumen Brankas Terenkripsi (GAMINI.md Bagian 6.5)
class Documents extends Table with CommonDomainColumns {
  TextColumn get documentType => text()(); // ktp, ktm, internship_letter, lease_contract, other
  BlobColumn get encryptedMetadata => blob()(); // judul, catatan, tag terenkripsi
  BlobColumn get nonce => blob()();
  TextColumn get cryptoContextId => text()();
  IntColumn get cryptoVersion => integer().withDefault(const Constant(1))();
  IntColumn get keyVersion => integer().withDefault(const Constant(1))();
  TextColumn get expiresOn => text().nullable()(); // YYYY-MM-DD
  BoolColumn get hasExpiry => boolean().withDefault(const Constant(false))();
}

/// Lampiran Media Fisik Terenkripsi (GAMINI.md Bagian 6.5)
class Attachments extends Table with CommonDomainColumns {
  TextColumn get mediaKind => text()(); // photo, scan, pdf, thumbnail
  TextColumn get mimeType => text()();
  TextColumn get storageBucket => text().withDefault(const Constant('personal-media'))();
  TextColumn get storagePath => text()();
  TextColumn get ciphertextSha256 => text()();
  IntColumn get byteSize => integer()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get cryptoContextId => text()();
  IntColumn get cryptoVersion => integer().withDefault(const Constant(1))();
  IntColumn get keyVersion => integer().withDefault(const Constant(1))();
  BlobColumn get wrappedFileKey => blob()();
  BlobColumn get wrapNonce => blob()();
  BlobColumn get fileNonce => blob()();
  TextColumn get remoteState => text().withDefault(const Constant('pending'))(); // pending, available, failed
}

/// Tautan Lampiran ke Entitas Domain (GAMINI.md Bagian 6.5)
class AttachmentLinks extends Table with CommonDomainColumns {
  TextColumn get attachmentId => text()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get inventoryItemId => text().nullable()();
  TextColumn get documentId => text().nullable()();
  TextColumn get billOccurrenceId => text().nullable()();
  TextColumn get linkRole => text().withDefault(const Constant('evidence'))(); // evidence, primary, page, thumbnail
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Aturan Pengingat Notifikasi (GAMINI.md Bagian 6.5)
class ReminderRules extends Table with CommonDomainColumns {
  TextColumn get targetType => text()(); // task, event, bill_template, inventory_item, document
  TextColumn get taskId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get billTemplateId => text().nullable()();
  TextColumn get inventoryItemId => text().nullable()();
  TextColumn get documentId => text().nullable()();
  IntColumn get offsetMinutes => integer().nullable()();
  TextColumn get localTime => text().nullable()(); // HH:mm
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get quietPolicy => text().withDefault(const Constant('respect'))();
}

/// Amplop Kunci Terenkripsi (GAMINI.md Bagian 6.5)
class UserKeyEnvelopes extends Table with CommonDomainColumns {
  TextColumn get keyPurpose => text()(); // media, vault, recovery
  IntColumn get keyVersion => integer().withDefault(const Constant(1))();
  TextColumn get cryptoContextId => text()();
  BlobColumn get wrappedMasterKey => blob()();
  BlobColumn get wrapNonce => blob()();
  BlobColumn get recoverySalt => blob()();
  IntColumn get cryptoVersion => integer().withDefault(const Constant(1))();
}
