// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../security/encryption_service.dart';
import '../storage/local_file_storage.dart';
import 'supabase_sync_service.dart';

/// Worker Unggah / Unduh Berkas Lampiran Terenkripsi ke Supabase Storage (PRD GAMINI.md Bagian 7.5.4)
/// Berjalan terpisah dari metadata commit untuk memastikan file besar tidak menghambat transaksi database.
class AttachmentSyncWorker {
  final AppDatabase _db;
  final ISupabaseSyncService _supabaseSync;
  final LocalFileStorage _fileStorage;
  final EncryptionService _encryptionService;

  AttachmentSyncWorker({
    required AppDatabase db,
    required ISupabaseSyncService supabaseSync,
    required LocalFileStorage fileStorage,
    EncryptionService? encryptionService,
  })  : _db = db,
        _supabaseSync = supabaseSync,
        _fileStorage = fileStorage,
        _encryptionService = encryptionService ?? EncryptionService();

  /// Menjalankan pemrosesan seluruh antrean attachment_jobs pending
  Future<int> processPendingJobs() async {
    final jobs = await (_db.select(_db.attachmentJobs)
          ..where((j) => j.status.equals('pending') | j.status.equals('failed')))
        .get();

    if (jobs.isEmpty) return 0;

    int successCount = 0;

    for (final job in jobs) {
      final attachment = await (_db.select(_db.attachments)..where((a) => a.id.equals(job.attachmentId))).getSingleOrNull();
      if (attachment == null) {
        await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
          const AttachmentJobsCompanion(status: Value('failed'), lastError: Value('ATTACHMENT_NOT_FOUND')),
        );
        continue;
      }

      await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
        const AttachmentJobsCompanion(status: Value('inflight')),
      );

      final bucket = attachment.storageBucket;
      final remotePath = '${attachment.userId}/${attachment.id}/${attachment.storagePath.split('/').last}';

      if (job.direction == 'upload') {
        final success = await _handleUpload(job, attachment, bucket, remotePath);
        if (success) successCount++;
      } else {
        final success = await _handleDownload(job, attachment, bucket, remotePath);
        if (success) successCount++;
      }
    }

    return successCount;
  }

  Future<bool> _handleUpload(
    AttachmentJob job,
    Attachment attachment,
    String bucket,
    String remotePath,
  ) async {
    try {
      final ciphertextBytes = await _fileStorage.readCiphertext(job.localCiphertextPath);
      if (ciphertextBytes == null) {
        await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
          const AttachmentJobsCompanion(status: Value('failed'), lastError: Value('LOCAL_FILE_MISSING')),
        );
        return false;
      }

      // Verifikasi integritas checksum SHA-256 sebelum upload
      final localHash = await _encryptionService.sha256Hex(ciphertextBytes);
      if (localHash != attachment.ciphertextSha256) {
        await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
          const AttachmentJobsCompanion(status: Value('failed'), lastError: Value('CHECKSUM_MISMATCH')),
        );
        return false;
      }

      final uploaded = await _supabaseSync.uploadAttachmentCiphertext(
        bucket: bucket,
        path: remotePath,
        bytes: ciphertextBytes,
      );

      if (uploaded) {
        await _db.transaction(() async {
          await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
            const AttachmentJobsCompanion(status: Value('completed'), lastError: Value(null)),
          );
          await (_db.update(_db.attachments)..where((a) => a.id.equals(attachment.id))).write(
            const AttachmentsCompanion(remoteState: Value('available')),
          );
        });
        return true;
      } else {
        await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
          AttachmentJobsCompanion(
            status: const Value('failed'),
            attemptCount: Value(job.attemptCount + 1),
            lastError: const Value('UPLOAD_FAILED'),
          ),
        );
        return false;
      }
    } catch (e) {
      await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
        AttachmentJobsCompanion(
          status: const Value('failed'),
          attemptCount: Value(job.attemptCount + 1),
          lastError: Value(e.toString()),
        ),
      );
      return false;
    }
  }

  Future<bool> _handleDownload(
    AttachmentJob job,
    Attachment attachment,
    String bucket,
    String remotePath,
  ) async {
    try {
      final bytes = await _supabaseSync.downloadAttachmentCiphertext(
        bucket: bucket,
        path: remotePath,
      );

      if (bytes == null) {
        await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
          AttachmentJobsCompanion(
            status: const Value('failed'),
            attemptCount: Value(job.attemptCount + 1),
            lastError: const Value('DOWNLOAD_EMPTY'),
          ),
        );
        return false;
      }

      // Verifikasi checksum SHA-256 hasil download
      final downloadHash = await _encryptionService.sha256Hex(bytes);
      if (downloadHash != attachment.ciphertextSha256) {
        await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
          const AttachmentJobsCompanion(status: Value('failed'), lastError: Value('DOWNLOAD_CORRUPTED')),
        );
        return false;
      }

      // Simpan berkas ciphertext ke direktori sandbox privat lokal
      await _fileStorage.saveCiphertext(fileId: attachment.id, ciphertextBytes: bytes);

      await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
        const AttachmentJobsCompanion(status: Value('completed'), lastError: Value(null)),
      );
      return true;
    } catch (e) {
      await (_db.update(_db.attachmentJobs)..where((j) => j.attachmentId.equals(job.attachmentId))).write(
        AttachmentJobsCompanion(
          status: const Value('failed'),
          attemptCount: Value(job.attemptCount + 1),
          lastError: Value(e.toString()),
        ),
      );
      return false;
    }
  }
}
