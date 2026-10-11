import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import 'attachment_sync_worker.dart';
import 'backup_and_export_service.dart';
import 'conflict_resolver.dart';
import 'models/sync_models.dart';
import 'supabase_sync_service.dart';
import 'sync_engine.dart';

/// Provider Layanan Klien Supabase
final supabaseSyncServiceProvider = Provider<ISupabaseSyncService>((ref) {
  return SupabaseSyncService();
});

/// Provider Engine Sinkronisasi Dua Arah
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabaseSync = ref.watch(supabaseSyncServiceProvider);
  final secureStorage = ref.watch(secureStorageProvider);

  return SyncEngine(
    db: db,
    supabaseSync: supabaseSync,
    secureStorage: secureStorage,
  );
});

/// Provider Worker Sinkronisasi Berkas Lampiran
final attachmentSyncWorkerProvider = Provider<AttachmentSyncWorker>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabaseSync = ref.watch(supabaseSyncServiceProvider);
  final fileStorage = ref.watch(localFileStorageProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);

  return AttachmentSyncWorker(
    db: db,
    supabaseSync: supabaseSync,
    fileStorage: fileStorage,
    encryptionService: encryptionService,
  );
});

/// Provider Resolusi Konflik
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ConflictResolver(db);
});

/// Provider Layanan Backup & Ekspor CSV
final backupAndExportServiceProvider = Provider<BackupAndExportService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);

  return BackupAndExportService(
    db: db,
    encryptionService: encryptionService,
  );
});

/// Notifier untuk memantau status sync secara reaktif di UI
class SyncNotifier extends Notifier<AsyncValue<SyncSummary>> {
  @override
  AsyncValue<SyncSummary> build() {
    Future.microtask(() => refreshSummary());
    return const AsyncValue.loading();
  }

  Future<void> refreshSummary() async {
    state = const AsyncValue.loading();
    try {
      final engine = ref.read(syncEngineProvider);
      final summary = await engine.syncNow();
      state = AsyncValue.data(summary);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> triggerSync() async {
    state = const AsyncValue.loading();
    try {
      final engine = ref.read(syncEngineProvider);
      final summary = await engine.syncNow();
      state = AsyncValue.data(summary);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final syncSummaryNotifierProvider = NotifierProvider<SyncNotifier, AsyncValue<SyncSummary>>(SyncNotifier.new);
