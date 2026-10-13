import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../contracts/operation_contracts.dart';
import 'models/sync_models.dart';

/// Abstraksi Layanan Sinkronisasi Supabase Backend (PRD GAMINI.md Bagian 6.8 & 7.5)
abstract class ISupabaseSyncService {
  /// Pendaftaran perangkat instalasi via RPC `register_device`
  Future<bool> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
  });

  /// Pengiriman satu operasi perubahan atomik via RPC `apply_operation` (Gate T05 & T06)
  Future<SyncOperationAck> applyOperation(SyncOperationPayload payload);

  /// Pengambilan feed perubahan berurutan via RPC `pull_changes` (Gate T07)
  Future<PullChangesResponse> pullChanges({
    required int afterSeq,
    int limit = 200,
  });

  /// Pencabutan izin perangkat tertentu via RPC `revoke_device`
  Future<void> revokeDevice(String deviceId);

  /// Unggah berkas ciphertext lampiran ke bucket privat Supabase Storage
  Future<bool> uploadAttachmentCiphertext({
    required String bucket,
    required String path,
    required Uint8List bytes,
  });

  /// Unduh berkas ciphertext lampiran dari bucket privat Supabase Storage
  Future<Uint8List?> downloadAttachmentCiphertext({
    required String bucket,
    required String path,
  });

  /// Memeriksa apakah sesi pengguna saat ini aktif dan terautentikasi
  bool get isAuthenticated;

  /// ID User dari sesi Supabase Auth saat ini
  String? get currentUserId;
}

/// Implementasi Konkret ISupabaseSyncService Menggunakan Supabase Flutter SDK
class SupabaseSyncService implements ISupabaseSyncService {
  final SupabaseClient? _client;

  SupabaseSyncService({SupabaseClient? client})
      : _client = client ?? _safeGetClient();

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isAuthenticated => _client?.auth.currentUser != null;

  @override
  String? get currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<bool> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final client = _client;
    if (client == null || !isAuthenticated) return false;

    try {
      final res = await client.rpc('register_device', params: {
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_platform': platform,
      });
      return res == true || (res is Map && res['status'] == 'ok');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SyncOperationAck> applyOperation(SyncOperationPayload payload) async {
    final client = _client;
    if (client == null || !isAuthenticated) {
      return SyncOperationAck(
        operationId: payload.operationId,
        status: 'rejected',
        errorCode: 'SESSION_REQUIRED',
        errorMessage: 'Pengguna belum terautentikasi ke Supabase.',
      );
    }

    try {
      final res = await client.rpc('apply_operation', params: {
        'p_payload': payload.toJson(),
      });

      if (res is Map) {
        return SyncOperationAck.fromJson(Map<String, dynamic>.from(res));
      }

      return SyncOperationAck(
        operationId: payload.operationId,
        status: 'acknowledged',
      );
    } on PostgrestException catch (e) {
      final isConflict = e.code == 'VERSION_CONFLICT' || e.message.contains('VERSION_CONFLICT');
      return SyncOperationAck(
        operationId: payload.operationId,
        status: isConflict ? 'conflict' : 'rejected',
        errorCode: isConflict ? 'VERSION_CONFLICT' : e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      return SyncOperationAck(
        operationId: payload.operationId,
        status: 'rejected',
        errorCode: 'NETWORK_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<PullChangesResponse> pullChanges({
    required int afterSeq,
    int limit = 200,
  }) async {
    final client = _client;
    if (client == null || !isAuthenticated) {
      return const PullChangesResponse(changes: [], nextSeq: 0, hasMore: false);
    }

    try {
      final res = await client.rpc('pull_changes', params: {
        'p_after_seq': afterSeq,
        'p_limit': limit,
      });

      if (res is Map) {
        return PullChangesResponse.fromJson(Map<String, dynamic>.from(res));
      }

      return const PullChangesResponse(changes: [], nextSeq: 0, hasMore: false);
    } catch (_) {
      return const PullChangesResponse(changes: [], nextSeq: 0, hasMore: false);
    }
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    final client = _client;
    if (client == null || !isAuthenticated) return;

    await client.rpc('revoke_device', params: {'p_device_id': deviceId});
  }

  @override
  Future<bool> uploadAttachmentCiphertext({
    required String bucket,
    required String path,
    required Uint8List bytes,
  }) async {
    final client = _client;
    if (client == null || !isAuthenticated) return false;

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> downloadAttachmentCiphertext({
    required String bucket,
    required String path,
  }) async {
    final client = _client;
    if (client == null || !isAuthenticated) return null;

    try {
      return await client.storage.from(bucket).download(path);
    } catch (_) {
      return null;
    }
  }
}
