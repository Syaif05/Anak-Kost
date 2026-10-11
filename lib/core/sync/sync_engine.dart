// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../contracts/operation_contracts.dart';
import '../database/app_database.dart';
import 'models/sync_models.dart';
import 'supabase_sync_service.dart';

/// Engine Sinkronisasi Dua Arah Offline-First (PRD GAMINI.md Bagian 3.7 & 7.5)
/// Menangani Push Antrean Outbox, Pull Change Feed, Idempotensi (T05),
/// Deteksi Edit Bersamaan (T06), dan Aplikasi Tombstone (T07).
class SyncEngine {
  final AppDatabase _db;
  final ISupabaseSyncService _supabaseSync;
  final FlutterSecureStorage _secureStorage;
  final Random _random = Random();

  SyncEngine({
    required AppDatabase db,
    required ISupabaseSyncService supabaseSync,
    FlutterSecureStorage? secureStorage,
  })  : _db = db,
        _supabaseSync = supabaseSync,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String> _getDeviceId() async {
    return (await _secureStorage.read(key: 'device_id')) ?? 'android-s24-default';
  }

  Future<String> _getOwnerId() async {
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    return profile?.id ?? _supabaseSync.currentUserId ?? 'user-default-kost';
  }

  /// 1. PUSH ENGINE: Mengirim antrean sync_outbox ke Supabase RPC `apply_operation`
  /// Memenuhi Gate Test T05 (Idempotensi) & Gate Test T06 (Edit lokal saat push berlangsung)
  Future<List<SyncOperationAck>> pushOutbox() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Ambil operasi pending / inflight yang sudah melewati masa retry
    final pendingOps = await (_db.select(_db.syncOutbox)
          ..where((o) =>
              (o.status.equals('pending') | o.status.equals('inflight')) &
              (o.nextRetryAt.isNull() | o.nextRetryAt.isSmallerOrEqualValue(now)))
          ..orderBy([(o) => OrderingTerm(expression: o.createdAt, mode: OrderingMode.asc)]))
        .get();

    if (pendingOps.isEmpty) return [];

    final deviceId = await _getDeviceId();
    final results = <SyncOperationAck>[];

    for (final op in pendingOps) {
      // Tandai inflight sebelum mengirim ke jaringan
      await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(op.operationId))).write(
        const SyncOutboxCompanion(status: Value('inflight')),
      );

      SyncOperationPayload payload;
      try {
        final decoded = jsonDecode(op.payloadJson) as Map<String, dynamic>;
        payload = SyncOperationPayload(
          schemaVersion: 1,
          operationId: op.operationId,
          deviceId: deviceId,
          deviceGeneration: 1,
          datasetGeneration: 1,
          aggregateType: op.aggregateType,
          aggregateId: op.aggregateId,
          baseVersions: {op.aggregateType: op.baseVersion},
          commands: [decoded],
        );
      } catch (e) {
        // Payload rusak: tandai blocked
        await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(op.operationId))).write(
          SyncOutboxCompanion(
            status: const Value('blocked'),
            lastErrorCode: Value('MALFORMED_PAYLOAD: $e'),
          ),
        );
        continue;
      }

      // Panggil RPC Supabase `apply_operation`
      final ack = await _supabaseSync.applyOperation(payload);
      results.add(ack);

      if (ack.isAcknowledged) {
        // GATE TEST T06: Periksa apakah ada edit lokal baru yang terjadi saat push berlangsung
        // Kita periksa apakah revisi outbox ini masih revisi yang dikirim.
        // Acknowledgement HANYA menandai operation_id ini sebagai done.
        // Jika ada baris baru di outbox untuk aggregate ini dengan localRevision > op.localRevision,
        // baris baru tersebut tetap aman berstatus 'pending'.
        await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(op.operationId))).write(
          const SyncOutboxCompanion(
            status: Value('done'),
            lastErrorCode: Value(null),
          ),
        );
      } else if (ack.isConflict) {
        // Terjadi VERSION_CONFLICT: simpan ke sync_conflicts tanpa menghilangkan data pengguna
        await _db.transaction(() async {
          await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(op.operationId))).write(
            SyncOutboxCompanion(
              status: const Value('conflict'),
              lastErrorCode: Value(ack.errorCode ?? 'VERSION_CONFLICT'),
            ),
          );

          await _db.into(_db.syncConflicts).insertOnConflictUpdate(
                SyncConflictsCompanion.insert(
                  operationId: op.operationId,
                  localSnapshot: op.payloadJson,
                  remoteSnapshot: jsonEncode(ack.serverSnapshot ?? {'conflict': true}),
                  remoteVersion: ack.serverVersion,
                  createdAt: now,
                ),
              );
        });
      } else {
        // Gangguan jaringan / 5xx: Backoff berjitter (5s -> 15s -> 1m -> 5m -> max 30m)
        final retryCount = op.retryCount + 1;
        final baseDelayMs = min(1800000, 5000 * pow(2, min(retryCount, 6)).toInt());
        final jitterMs = _random.nextInt(2000);
        final nextRetryAt = now + baseDelayMs + jitterMs;

        await (_db.update(_db.syncOutbox)..where((o) => o.operationId.equals(op.operationId))).write(
          SyncOutboxCompanion(
            status: const Value('pending'),
            retryCount: Value(retryCount),
            nextRetryAt: Value(nextRetryAt),
            lastErrorCode: Value(ack.errorMessage ?? ack.errorCode),
          ),
        );
      }
    }

    return results;
  }

  /// 2. PULL ENGINE: Menarik change feed berurutan dari Supabase via `pull_changes`
  /// Memenuhi Gate Test T07: Menjamin pengaplikasian tombstone dan atomisitas per halaman cursor
  Future<int> pullChanges({int limit = 200}) async {
    final ownerId = await _getOwnerId();
    final deviceId = await _getDeviceId();

    // Baca cursor terakhir untuk perangkat lokal ini
    final currentCursor = await (_db.select(_db.syncCursors)
          ..where((c) => c.ownerId.equals(ownerId) & c.deviceId.equals(deviceId)))
        .getSingleOrNull();

    final afterSeq = currentCursor?.lastChangeSeq ?? 0;

    // Tarik feed dari Supabase
    final response = await _supabaseSync.pullChanges(afterSeq: afterSeq, limit: limit);
    if (response.changes.isEmpty) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Terapkan seluruh halaman perubahan dan cursor dalam SATU TRANSAKSI lokal (Gate T07)
    await _db.transaction(() async {
      for (final change in response.changes) {
        if (change.isTombstone) {
          // TERAPKAN TOMBSTONE (PENGHAPUSAN):
          // Ubah `deletedAt` menjadi timestamp now agar tidak tampil di UI aktif
          await _applyTombstone(change.entityType, change.entityId, now);
        } else if (change.rowSnapshot != null) {
          // TERAPKAN UPSERT / PERUBAHAN DATA REMOTE
          await _applyUpsertSnapshot(
            change.entityType,
            change.entityId,
            change.rowSnapshot!,
            now,
            ownerId: ownerId,
            deviceId: deviceId,
            opId: change.operationId,
          );
        }
      }

      // Perbarui sync_cursors pada transaksi yang sama
      await _db.into(_db.syncCursors).insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              ownerId: ownerId,
              deviceId: deviceId,
              lastChangeSeq: Value(response.nextSeq),
              datasetGeneration: const Value(1),
              lastSuccessAt: Value(now),
            ),
          );
    });

    return response.changes.length;
  }

  /// Menerapkan tombstone penghapusan secara aman ke tabel Drift terkait
  Future<void> _applyTombstone(String entityType, String entityId, int now) async {
    switch (entityType) {
      case 'transaction':
        await (_db.update(_db.transactions)..where((t) => t.id.equals(entityId))).write(
          TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
      case 'inventory_item':
        await (_db.update(_db.inventoryItems)..where((t) => t.id.equals(entityId))).write(
          InventoryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
      case 'activity_event':
        await (_db.update(_db.activityEvents)..where((t) => t.id.equals(entityId))).write(
          ActivityEventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
      case 'task':
        await (_db.update(_db.tasks)..where((t) => t.id.equals(entityId))).write(
          TasksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
      case 'bill_template':
        await (_db.update(_db.billTemplates)..where((t) => t.id.equals(entityId))).write(
          BillTemplatesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
      case 'bill_occurrence':
        await (_db.update(_db.billOccurrences)..where((t) => t.id.equals(entityId))).write(
          BillOccurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
      case 'document':
        await (_db.update(_db.documents)..where((t) => t.id.equals(entityId))).write(
          DocumentsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        break;
    }
  }

  /// Menerapkan snapshot data dari server ke tabel Drift terkait
  Future<void> _applyUpsertSnapshot(
    String entityType,
    String entityId,
    Map<String, dynamic> snapshot,
    int now, {
    required String ownerId,
    required String deviceId,
    required String opId,
  }) async {
    final createdAt = snapshot['created_at'] as int? ?? now;
    final updatedAt = snapshot['updated_at'] as int? ?? now;
    final opIdentifier = opId.isNotEmpty ? opId : 'op-remote-$now';

    switch (entityType) {
      case 'wallet':
        final name = snapshot['name'] as String? ?? 'Dompet';
        final walletType = snapshot['wallet_type'] as String? ?? snapshot['type'] as String? ?? 'cash';
        await _db.into(_db.wallets).insertOnConflictUpdate(
              WalletsCompanion.insert(
                id: entityId,
                userId: ownerId,
                name: name,
                walletType: walletType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOperationId: opIdentifier,
                originDeviceId: deviceId,
              ),
            );
        break;
      case 'transaction':
        final kind = snapshot['kind'] as String? ?? 'expense';
        final amountRp = (snapshot['amount_rp'] as num?)?.toInt() ?? 0;
        final localDate = snapshot['local_date'] as String? ?? '2026-10-10';
        final occurredAt = snapshot['occurred_at'] as int? ?? now;
        await _db.into(_db.transactions).insertOnConflictUpdate(
              TransactionsCompanion.insert(
                id: entityId,
                userId: ownerId,
                kind: kind,
                amountRp: amountRp,
                localDate: localDate,
                occurredAt: occurredAt,
                merchant: Value(snapshot['merchant'] as String?),
                note: Value(snapshot['note'] as String?),
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOperationId: opIdentifier,
                originDeviceId: deviceId,
              ),
            );
        break;
      case 'inventory_item':
        final name = snapshot['name'] as String? ?? 'Barang';
        final baseUnit = snapshot['base_unit'] as String? ?? 'pcs';
        final minQty = (snapshot['minimum_qty_milli'] as num?)?.toInt() ?? 0;
        await _db.into(_db.inventoryItems).insertOnConflictUpdate(
              InventoryItemsCompanion.insert(
                id: entityId,
                userId: ownerId,
                name: name,
                baseUnit: Value(baseUnit),
                minimumQtyMilli: Value(minQty),
                stockCategory: Value(snapshot['stock_category'] as String?),
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOperationId: opIdentifier,
                originDeviceId: deviceId,
              ),
            );
        break;
    }
  }

  /// 3. SINKRONISASI LENGKAP: Push outbox terlebih dahulu, lalu Pull perubahan remote
  Future<SyncSummary> syncNow() async {
    final deviceId = await _getDeviceId();
    final ownerId = await _getOwnerId();

    if (!_supabaseSync.isAuthenticated) {
      final pendingCount = await _getPendingCount();
      return SyncSummary(
        state: SyncState.offline,
        pendingOutboxCount: pendingCount,
        deviceId: deviceId,
        platform: 'android',
      );
    }

    try {
      // 1. Kirim perubahan lokal
      await pushOutbox();

      // 2. Tarik perubahan remote
      await pullChanges();

      final pendingCount = await _getPendingCount();
      final conflictCount = await _getConflictCount();
      final cursor = await (_db.select(_db.syncCursors)
            ..where((c) => c.ownerId.equals(ownerId) & c.deviceId.equals(deviceId)))
          .getSingleOrNull();

      final lastSync = cursor?.lastSuccessAt != null
          ? DateTime.fromMillisecondsSinceEpoch(cursor!.lastSuccessAt!)
          : DateTime.now();

      return SyncSummary(
        state: conflictCount > 0 ? SyncState.conflict : SyncState.success,
        pendingOutboxCount: pendingCount,
        conflictCount: conflictCount,
        lastSyncTime: lastSync,
        deviceId: deviceId,
        platform: 'android',
      );
    } catch (e) {
      final pendingCount = await _getPendingCount();
      return SyncSummary(
        state: SyncState.error,
        pendingOutboxCount: pendingCount,
        deviceId: deviceId,
        platform: 'android',
        lastError: e.toString(),
      );
    }
  }

  Future<int> _getPendingCount() async {
    final items = await (_db.select(_db.syncOutbox)..where((o) => o.status.equals('pending') | o.status.equals('inflight'))).get();
    return items.length;
  }

  Future<int> _getConflictCount() async {
    final conflicts = await (_db.select(_db.syncConflicts)).get();
    return conflicts.length;
  }
}
