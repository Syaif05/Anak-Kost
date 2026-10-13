/// Konstanta global aplikasi Anak Kost (Android Client)
/// Sesuai spesifikasi PRD GAMINI.md v1.1
abstract class AppConstants {
  static const String appName = 'Dompet Kos';
  static const String appVersion = '1.1.0';
  static const int schemaVersion = 1;

  // Waktu & Zona
  static const String defaultTimezone = 'Asia/Jakarta';

  // Breakpoints tampilan (Logical Pixels)
  static const double compactBreakpoint = 600.0;
  static const double mediumBreakpoint = 1024.0;

  // Ukuran touch target minimum Android (Material 3 guideline)
  static const double minTouchTargetSize = 48.0;

  // Batas file media (Attachment)
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB per berkas
  static const int maxReceiptImagesPerTransaction = 5;
  static const int maxDocumentPages = 10;

  // Target resolusi gambar
  static const int thumbnailTargetLongEdge = 480; // px
  static const int inventoryTargetLongEdge = 1280; // px
  static const int receiptTargetLongEdge = 2560; // px

  // Supabase Storage Bucket Names (Private Buckets)
  static const String bucketPersonalMedia = 'personal-media';
  static const String bucketDocumentVault = 'document-vault';

  // Kunci Secure Storage Lokal
  static const String secKeyAppPinHash = 'app_pin_hash';
  static const String secKeyAppPinSalt = 'app_pin_salt';
  static const String secKeyBiometricsEnabled = 'biometrics_enabled';
  static const String secKeyDeviceId = 'device_installation_id';
  static const String secKeyMasterMediaEnvelope = 'master_media_envelope';
  static const String secKeyMasterVaultEnvelope = 'master_vault_envelope';
  static const String secKeyRecoverySalt = 'recovery_salt';
}
