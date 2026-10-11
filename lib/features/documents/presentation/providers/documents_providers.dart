import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/documents_dao.dart';
import '../../data/documents_repository.dart';
import '../../domain/models/document_models.dart';

/// Provider singleton untuk DocumentsRepository
final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  final keyMgr = ref.watch(keyManagerProvider);
  return DocumentsRepository(
    db: db,
    encryptionService: encryption,
    keyManager: keyMgr,
  );
});

/// Provider DAO Dokumen
final documentsDaoProvider = Provider<DocumentsDao>((ref) {
  return ref.watch(documentsRepositoryProvider).dao;
});

/// Notifier untuk status kunci brankas (false = terkunci, true = terbuka)
class VaultUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setUnlocked(bool value) => state = value;
}

final vaultUnlockedProvider =
    NotifierProvider<VaultUnlockedNotifier, bool>(VaultUnlockedNotifier.new);

/// Notifier untuk master key brankas dalam memori privat (dibersihkan saat brankas dikunci)
class VaultMasterKeyNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void setKey(Uint8List? key) => state = key;
}

final vaultMasterKeyProvider =
    NotifierProvider<VaultMasterKeyNotifier, Uint8List?>(VaultMasterKeyNotifier.new);

/// Stream daftar dokumen brankas
final documentsStreamProvider =
    StreamProvider.family<List<DocumentWithDetails>, String?>((ref, docType) {
  return ref.watch(documentsDaoProvider).watchDocuments(documentType: docType);
});
