import 'package:drift/drift.dart';

/// Tabel profil pengguna (GAMINI.md Bagian 6.2)
class Profiles extends Table {
  TextColumn get id => text()(); // UUID FK auth.users
  TextColumn get cryptoContextId => text()(); // UUID immutable context
  TextColumn get displayName => text().nullable()();
  TextColumn get timezone => text().withDefault(const Constant('Asia/Jakarta'))();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Antrean Outbox Sinkronisasi Offline-First (GAMINI.md Bagian 6.7)
class SyncOutbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  IntColumn get baseVersion => integer()();
  TextColumn get payloadJson => text()();
  IntColumn get localRevision => integer()();
  TextColumn get dependsOnJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, inflight, conflict, blocked, done
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Tracking Cursor Sinkronisasi Lokal (GAMINI.md Bagian 6.7)
class SyncCursors extends Table {
  TextColumn get ownerId => text()();
  TextColumn get deviceId => text()();
  IntColumn get lastChangeSeq => integer().withDefault(const Constant(0))();
  IntColumn get datasetGeneration => integer().withDefault(const Constant(1))();
  IntColumn get lastSuccessAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, deviceId};
}

/// Tabel Log Penyelesaian Konflik Sinkronisasi (GAMINI.md Bagian 6.7)
class SyncConflicts extends Table {
  TextColumn get operationId => text()();
  TextColumn get localSnapshot => text()();
  TextColumn get remoteSnapshot => text()();
  IntColumn get remoteVersion => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Antrean Job Unggah / Unduh Berkas Attachment Terenkripsi (GAMINI.md Bagian 6.7)
class AttachmentJobs extends Table {
  TextColumn get attachmentId => text()();
  TextColumn get localCiphertextPath => text()();
  TextColumn get direction => text()(); // upload, download
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, inflight, completed, failed
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {attachmentId};
}

/// Pengaturan Aplikasi Lokal (GAMINI.md Bagian 6.7)
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();

  @override
  Set<Column> get primaryKey => {key};
}
