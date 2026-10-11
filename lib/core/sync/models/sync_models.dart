import 'dart:convert';

/// Status Sinkronisasi
enum SyncState {
  idle,
  syncing,
  success,
  conflict,
  error,
  offline;

  String get label {
    switch (this) {
      case SyncState.idle:
        return 'Siap';
      case SyncState.syncing:
        return 'Sedang Menyinkronkan...';
      case SyncState.success:
        return 'Tersinkron';
      case SyncState.conflict:
        return 'Perlu Ditinjau (Konflik)';
      case SyncState.error:
        return 'Gagal Sinkronisasi';
      case SyncState.offline:
        return 'Mode Offline (Tersimpan Lokal)';
    }
  }
}

/// Ringkasan Metrik Sinkronisasi untuk UI Pengaturan
class SyncSummary {
  final SyncState state;
  final int pendingOutboxCount;
  final int conflictCount;
  final int pendingAttachmentCount;
  final DateTime? lastSyncTime;
  final String deviceId;
  final String platform;
  final int deviceGeneration;
  final int datasetGeneration;
  final String? lastError;

  const SyncSummary({
    this.state = SyncState.idle,
    this.pendingOutboxCount = 0,
    this.conflictCount = 0,
    this.pendingAttachmentCount = 0,
    this.lastSyncTime,
    required this.deviceId,
    required this.platform,
    this.deviceGeneration = 1,
    this.datasetGeneration = 1,
    this.lastError,
  });

  bool get hasPending => pendingOutboxCount > 0 || pendingAttachmentCount > 0;
  bool get hasConflict => conflictCount > 0;
}

/// Hasil Eksekusi Operasi Server (Acknowledgement RPC `apply_operation`)
class SyncOperationAck {
  final String operationId;
  final String status; // 'acknowledged', 'conflict', 'rejected'
  final int serverVersion;
  final int changeSeq;
  final String? errorCode; // e.g. 'VERSION_CONFLICT', 'STOCK_INSUFFICIENT'
  final String? errorMessage;
  final Map<String, dynamic>? serverSnapshot;

  const SyncOperationAck({
    required this.operationId,
    required this.status,
    this.serverVersion = 0,
    this.changeSeq = 0,
    this.errorCode,
    this.errorMessage,
    this.serverSnapshot,
  });

  bool get isAcknowledged => status == 'acknowledged';
  bool get isConflict => status == 'conflict' || errorCode == 'VERSION_CONFLICT';

  factory SyncOperationAck.fromJson(Map<String, dynamic> json) {
    return SyncOperationAck(
      operationId: json['operation_id'] as String? ?? '',
      status: json['status'] as String? ?? 'rejected',
      serverVersion: (json['server_version'] as num?)?.toInt() ?? 0,
      changeSeq: (json['change_seq'] as num?)?.toInt() ?? 0,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      serverSnapshot: json['server_snapshot'] != null
          ? Map<String, dynamic>.from(json['server_snapshot'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'operation_id': operationId,
        'status': status,
        'server_version': serverVersion,
        'change_seq': changeSeq,
        if (errorCode != null) 'error_code': errorCode,
        if (errorMessage != null) 'error_message': errorMessage,
        if (serverSnapshot != null) 'server_snapshot': serverSnapshot,
      };
}

/// Item Perubahan dari Change Feed RPC `pull_changes`
class ServerChangeItem {
  final int changeSeq;
  final String entityType; // e.g. 'transaction', 'inventory_item', 'activity_event'
  final String entityId;
  final int rowVersion;
  final bool isTombstone;
  final String operationId;
  final Map<String, dynamic>? rowSnapshot;

  const ServerChangeItem({
    required this.changeSeq,
    required this.entityType,
    required this.entityId,
    required this.rowVersion,
    required this.isTombstone,
    required this.operationId,
    this.rowSnapshot,
  });

  factory ServerChangeItem.fromJson(Map<String, dynamic> json) {
    return ServerChangeItem(
      changeSeq: (json['change_seq'] as num).toInt(),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      rowVersion: (json['row_version'] as num?)?.toInt() ?? 1,
      isTombstone: json['is_tombstone'] as bool? ?? false,
      operationId: json['operation_id'] as String? ?? '',
      rowSnapshot: json['row_snapshot'] != null
          ? (json['row_snapshot'] is String
              ? jsonDecode(json['row_snapshot'] as String) as Map<String, dynamic>
              : Map<String, dynamic>.from(json['row_snapshot'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'change_seq': changeSeq,
        'entity_type': entityType,
        'entity_id': entityId,
        'row_version': rowVersion,
        'is_tombstone': isTombstone,
        'operation_id': operationId,
        if (rowSnapshot != null) 'row_snapshot': rowSnapshot,
      };
}

/// Hasil Pemanggilan RPC `pull_changes`
class PullChangesResponse {
  final List<ServerChangeItem> changes;
  final int nextSeq;
  final bool hasMore;

  const PullChangesResponse({
    required this.changes,
    required this.nextSeq,
    required this.hasMore,
  });

  factory PullChangesResponse.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List<dynamic>? ?? [];
    final changesList = rawChanges
        .map((e) => ServerChangeItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PullChangesResponse(
      changes: changesList,
      nextSeq: (json['next_seq'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

/// DTO Data Konflik Sinkronisasi
class SyncConflictData {
  final String operationId;
  final String aggregateType;
  final String aggregateId;
  final Map<String, dynamic> localSnapshot;
  final Map<String, dynamic> remoteSnapshot;
  final int remoteVersion;
  final int createdAt;

  const SyncConflictData({
    required this.operationId,
    required this.aggregateType,
    required this.aggregateId,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.remoteVersion,
    required this.createdAt,
  });
}
