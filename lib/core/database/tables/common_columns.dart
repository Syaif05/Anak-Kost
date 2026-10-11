import 'package:drift/drift.dart';

/// Mixin kolom standar untuk seluruh tabel domain Anak Kost
/// Sesuai PRD GAMINI.md Bagian 6.1 (Kolom Umum `C`)
/// Di SQLite, `integer()` adalah 64-bit signed integer dan di Dart dipetakan ke tipe `int` 64-bit native.
mixin CommonDomainColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  IntColumn get createdAt => integer()(); // epoch millis UTC
  IntColumn get updatedAt => integer()(); // epoch millis UTC
  IntColumn get deletedAt => integer().nullable()(); // null jika aktif, epoch jika tombstone
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get lastOperationId => text()();
  TextColumn get originDeviceId => text()();

  // Kolom tracking sinkronisasi lokal (tidak dikirim ke server domain)
  IntColumn get localRevision => integer().withDefault(const Constant(1))();
  IntColumn get ackedLocalRevision => integer().withDefault(const Constant(0))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))(); // pending, inflight, synced, conflict

  @override
  Set<Column> get primaryKey => {id};
}
