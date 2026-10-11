import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../media/image_pipeline_service.dart';
import '../notifications/notification_service.dart';
import '../security/app_lock_service.dart';
import '../security/encryption_service.dart';
import '../security/key_manager.dart';
import '../storage/local_file_storage.dart';

/// Provider singleton untuk Drift AppDatabase lokal
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider singleton untuk EncryptionService
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

/// Provider singleton untuk KeyManager
final keyManagerProvider = Provider<KeyManager>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return KeyManager(encryptionService: encryption);
});

/// Provider singleton untuk LocalFileStorage
final localFileStorageProvider = Provider<LocalFileStorage>((ref) {
  return LocalFileStorage();
});

/// Provider untuk AppLockService (Listenable)
final appLockServiceProvider = Provider<AppLockService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  final service = AppLockService(encryptionService: encryption);
  service.initialize();
  return service;
});

/// Provider singleton untuk NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});

/// Provider singleton untuk ImagePipelineService
final imagePipelineServiceProvider = Provider<ImagePipelineService>((ref) {
  return ImagePipelineService();
});
