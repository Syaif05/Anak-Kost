import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'models/sync_models.dart';

/// Layanan Penyelesaian Konflik Sinkronisasi (PRD GAMINI.md Bagian 7.5.5)
/// Menangani konflik Optimistic Concurrency saat dua perangkat mengubah baris yang sama saat offline.
class ConflictResolver {
  final AppDatabase _db;

  ConflictResolver(this._db);

  /// Mengambil seluruh konflik sinkronisasi yang membutuhkan peninjauan pengguna
  Future<List<SyncConflictData>> getPendingConflicts() async {
    final rows = await (_db.select(_db.syncConflicts)
          ..orderBy([(c) => OrderingTerm(expression: c.createdAt, mode: OrderingMode.desc)]))
        .get();

    final result = <SyncConflictData>[];
    for (final row in rows) {
      final outboxItem = await (_db.select(_db.syncOutbox)..where((o) => o.operationId.equals(row.operationId))).getSingleOrNull();

      Map<String, dynamic> local = {};
      Map<String, dynamic> remote = {};
      try {
        local = jsonDecode(row.localSnapshot) as Map<String, dynamic>;
      } catch (_) {}
      try {
        remote = jsonDecode(row.remoteSnapshot) as Map<String, dynamic>;
      } catch (_) {}

      result.add(SyncConflictData(
        operationId: row.operationId,
        aggregateType: outboxItem?.aggregateType ?? 'unknown',
        aggregateId: outboxItem?.aggregateId ?? '',
        localSnapshot: local,
        remoteSnapshot: remote,
        remoteVersion: row.remoteVersion,
        createdAt: row.createdAt,
      ));
    }

    return result;
  }

  /// Opsi A: Pengguna memilih versi lokal (Pertahankan perubahan lokal)
  /// Mengupdate outbox dengan versi dasar server terbaru agar dapat di-apply ulang
  Future<void> resolveWithLocal(String operationId, int newServerVersion) async {
    await _db.transaction(() async {
      await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(operationId))).write(
        SyncOutboxCompanion(
          baseVersion: Value(newServerVersion),
          status: const Value('pending'),
          retryCount: const Value(0),
          nextRetryAt: const Value(null),
          lastErrorCode: const Value(null),
        ),
      );

      await (_db.delete(_db.syncConflicts)..where((c) => c.operationId.equals(operationId))).go();
    });
  }

  /// Opsi B: Pengguna memilih versi server (Terima versi remote dan buang intent lokal)
  Future<void> resolveWithRemote(String operationId) async {
    await _db.transaction(() async {
      await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(operationId))).write(
        const SyncOutboxCompanion(
          status: Value('done'),
          lastErrorCode: Value('RESOLVED_WITH_REMOTE'),
        ),
      );

      await (_db.delete(_db.syncConflicts)..where((c) => c.operationId.equals(operationId))).go();
    });
  }
}
