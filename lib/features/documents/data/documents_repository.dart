import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/storage/local_file_storage.dart';
import '../domain/models/document_models.dart';
import 'documents_dao.dart';

class DocumentsRepository {
  final AppDatabase _db;
  final DocumentsDao _dao;
  final EncryptionService _encryptionService;
  final KeyManager _keyManager;
  final FlutterSecureStorage _secureStorage;
  final LocalFileStorage _fileStorage;
  final Uuid _uuid = const Uuid();

  DocumentsRepository({
    required AppDatabase db,
    DocumentsDao? dao,
    EncryptionService? encryptionService,
    KeyManager? keyManager,
    FlutterSecureStorage? secureStorage,
    LocalFileStorage? fileStorage,
  })  : _db = db,
        _dao = dao ?? DocumentsDao(db),
        _encryptionService = encryptionService ?? EncryptionService(),
        _keyManager = keyManager ?? KeyManager(encryptionService: encryptionService, secureStorage: secureStorage),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _fileStorage = fileStorage ?? LocalFileStorage();

  DocumentsDao get dao => _dao;
  KeyManager get keyManager => _keyManager;
  EncryptionService get encryptionService => _encryptionService;
  LocalFileStorage get fileStorage => _fileStorage;

  Future<String> _getDeviceId() async {
    var id = await _secureStorage.read(key: AppConstants.secKeyDeviceId);
    if (id == null) {
      id = _uuid.v4();
      await _secureStorage.write(key: AppConstants.secKeyDeviceId, value: id);
    }
    return id;
  }

  Future<String> _getUserId() async {
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    return profile?.id ?? '00000000-0000-0000-0000-000000000001';
  }

  Future<String> _getCryptoContextId() async {
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    return profile?.cryptoContextId ?? '00000000-0000-0000-0000-000000000001';
  }

  /// 1. Simpan Dokumen Terenkripsi AES-256-GCM ke Brankas (DOC01, DOC03, T13, T14)
  Future<String> createEncryptedDocument({
    required String documentType, // ktp, ktm, internship_letter, lease_contract, other
    required DocumentMetadata metadata,
    required Uint8List masterKey,
    Uint8List? fileBytes,
    String? mediaKind, // photo, scan, pdf
    String? mimeType,
    String? expiresOn, // YYYY-MM-DD
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final cryptoContextId = await _getCryptoContextId();
    final docId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Enkripsi Metadata Sensitif (nomor identitas, judul, catatan) dengan AES-256-GCM
    final metadataPlaintext = Uint8List.fromList(utf8.encode(metadata.toJsonString()));
    final encryptedMeta = await _encryptionService.encrypt(
      plaintext: metadataPlaintext,
      key: masterKey,
      aad: cryptoContextId.codeUnits,
    );

    await _db.transaction(() async {
      await _db.into(_db.documents).insert(
            DocumentsCompanion.insert(
              id: docId,
              userId: userId,
              documentType: documentType,
              encryptedMetadata: encryptedMeta.combinedWithTag,
              nonce: encryptedMeta.nonce,
              cryptoContextId: cryptoContextId,
              expiresOn: Value(expiresOn ?? metadata.expiryDate),
              hasExpiry: Value(expiresOn != null || metadata.expiryDate != null),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // Jika ada lampiran berkas fisik (PDF / Foto)
      if (fileBytes != null && fileBytes.isNotEmpty) {
        final attachmentId = _uuid.v4();
        final fileKey = _encryptionService.generateRandomBytes(32);

        // Enkripsi berkas fisik dengan fileKey
        final encryptedFile = await _encryptionService.encrypt(
          plaintext: fileBytes,
          key: fileKey,
          aad: attachmentId.codeUnits,
        );

        // Bungkus fileKey dengan masterKey
        final wrappedKeyPayload = await _encryptionService.encrypt(
          plaintext: fileKey,
          key: masterKey,
          aad: cryptoContextId.codeUnits,
        );

        final ciphertextHash = await _encryptionService.sha256Hex(encryptedFile.combinedWithTag);
        final savedPath = await _fileStorage.saveCiphertext(
          fileId: attachmentId,
          ciphertextBytes: encryptedFile.combinedWithTag,
        );

        await _db.into(_db.attachments).insert(
              AttachmentsCompanion.insert(
                id: attachmentId,
                userId: userId,
                mediaKind: mediaKind ?? 'photo',
                mimeType: mimeType ?? 'image/jpeg',
                storagePath: savedPath,
                ciphertextSha256: ciphertextHash,
                byteSize: encryptedFile.combinedWithTag.length,
                cryptoContextId: cryptoContextId,
                wrappedFileKey: wrappedKeyPayload.combinedWithTag,
                wrapNonce: wrappedKeyPayload.nonce,
                fileNonce: encryptedFile.nonce,
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );

        await _db.into(_db.attachmentLinks).insert(
              AttachmentLinksCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                attachmentId: attachmentId,
                documentId: Value(docId),
                linkRole: const Value('primary'),
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );
      }

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'document',
              aggregateId: docId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'document_type': documentType,
                'has_expiry': expiresOn != null || metadata.expiryDate != null,
                'expires_on': expiresOn ?? metadata.expiryDate,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return docId;
  }

  /// 2. Dekripsi Metadata Dokumen Brankas (Gate Test T13)
  /// Menggunakan kunci master yang sah. Jika ciphertext diubah atau kunci salah, dekripsi gagal aman.
  Future<DocumentMetadata> decryptDocumentMetadata({
    required Document document,
    required Uint8List masterKey,
  }) async {
    final payload = EncryptedPayload.fromCombined(
      combined: document.encryptedMetadata,
      nonce: document.nonce,
    );

    // Akan melempar SecretBoxAuthenticationError jika ciphertext/tag tidak cocok atau kunci salah (Test T13)
    final decryptedBytes = await _encryptionService.decrypt(
      ciphertext: payload.ciphertext,
      key: masterKey,
      nonce: payload.nonce,
      tag: payload.tag,
      aad: document.cryptoContextId.codeUnits,
    );

    final jsonStr = utf8.decode(decryptedBytes);
    return DocumentMetadata.fromJsonString(jsonStr);
  }

  /// 3. Dekripsi Berkas Lampiran Dokumen di Memori Privat (DOC03 & T14)
  Future<Uint8List> decryptAttachmentFile({
    required Attachment attachment,
    required Uint8List encryptedFileBytes,
    required Uint8List masterKey,
  }) async {
    // a. Buka bungkus fileKey
    final wrappedKeyPayload = EncryptedPayload.fromCombined(
      combined: attachment.wrappedFileKey,
      nonce: attachment.wrapNonce,
    );

    final fileKey = await _encryptionService.decrypt(
      ciphertext: wrappedKeyPayload.ciphertext,
      key: masterKey,
      nonce: wrappedKeyPayload.nonce,
      tag: wrappedKeyPayload.tag,
      aad: attachment.cryptoContextId.codeUnits,
    );

    // b. Dekripsi berkas fisik
    final filePayload = EncryptedPayload.fromCombined(
      combined: encryptedFileBytes,
      nonce: attachment.fileNonce,
    );

    return _encryptionService.decrypt(
      ciphertext: filePayload.ciphertext,
      key: fileKey,
      nonce: filePayload.nonce,
      tag: filePayload.tag,
      aad: attachment.id.codeUnits,
    );
  }

  /// 3b. Muat berkas ciphertext dari storage privat dan dekripsi di memori privat (DOC03 & T14)
  Future<Uint8List> loadAndDecryptAttachment({
    required Attachment attachment,
    required Uint8List masterKey,
  }) async {
    final ciphertextBytes = await _fileStorage.readCiphertext(attachment.storagePath);
    if (ciphertextBytes == null) {
      throw StateError('Berkas ciphertext lampiran tidak ditemukan pada path: ${attachment.storagePath}');
    }

    return decryptAttachmentFile(
      attachment: attachment,
      encryptedFileBytes: ciphertextBytes,
      masterKey: masterKey,
    );
  }

  /// 4. Hapus Dokumen dari Brankas (Soft Delete)
  Future<void> deleteDocument(String documentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opId = _uuid.v4();

    await (_db.update(_db.documents)..where((d) => d.id.equals(documentId))).write(
      DocumentsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        lastOperationId: Value(opId),
      ),
    );
  }

  /// 5. Menautkan Foto Bukti Struk Terenkripsi ke Transaksi Keuangan (PRD 3.6.2, 3.6.4, 6.5)
  Future<String> attachEvidenceToTransaction({
    required String transactionId,
    required Uint8List fileBytes,
    required Uint8List masterKey,
    String mimeType = 'image/jpeg',
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final cryptoContextId = await _getCryptoContextId();
    final attachmentId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final fileKey = _encryptionService.generateRandomBytes(32);

    final encryptedFile = await _encryptionService.encrypt(
      plaintext: fileBytes,
      key: fileKey,
      aad: attachmentId.codeUnits,
    );

    final wrappedKeyPayload = await _encryptionService.encrypt(
      plaintext: fileKey,
      key: masterKey,
      aad: cryptoContextId.codeUnits,
    );

    final ciphertextHash = await _encryptionService.sha256Hex(encryptedFile.combinedWithTag);
    final savedPath = await _fileStorage.saveCiphertext(
      fileId: attachmentId,
      ciphertextBytes: encryptedFile.combinedWithTag,
    );

    await _db.transaction(() async {
      await _db.into(_db.attachments).insert(
            AttachmentsCompanion.insert(
              id: attachmentId,
              userId: userId,
              mediaKind: 'photo',
              mimeType: mimeType,
              storagePath: savedPath,
              ciphertextSha256: ciphertextHash,
              byteSize: encryptedFile.combinedWithTag.length,
              cryptoContextId: cryptoContextId,
              wrappedFileKey: wrappedKeyPayload.combinedWithTag,
              wrapNonce: wrappedKeyPayload.nonce,
              fileNonce: encryptedFile.nonce,
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.attachmentLinks).insert(
            AttachmentLinksCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              attachmentId: attachmentId,
              transactionId: Value(transactionId),
              linkRole: const Value('evidence'),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'attachment',
              aggregateId: attachmentId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'attachment_id': attachmentId,
                'media_kind': 'photo',
                'mime_type': mimeType,
                'link_role': 'evidence',
                'transaction_id': transactionId,
                'ciphertext_sha256': ciphertextHash,
                'byte_size': encryptedFile.combinedWithTag.length,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    return attachmentId;
  }
}
