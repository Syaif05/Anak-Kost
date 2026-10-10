/// Spesifikasi dan Konstanta Kriptografi
/// Sesuai PRD GAMINI.md Bagian 7.6 & Bagian 10.6
/// Menggunakan AES-256-GCM dengan AAD (Additional Authenticated Data).
abstract class CryptoConstants {
  static const int cryptoVersion = 1;

  // Ukuran Kunci & Nonce (bytes)
  static const int aesKeyLengthBytes = 32; // 256 bit
  static const int gcmNonceLengthBytes = 12; // 96 bit (NIST SP 800-38D standard)
  static const int gcmTagLengthBytes = 16; // 128 bit authentication tag
  static const int recoverySaltLengthBytes = 16; // 128 bit salt

  // Tujuan Kunci (Key Purpose)
  static const String purposeMedia = 'media';
  static const String purposeVault = 'vault';
  static const String purposeRecovery = 'recovery';

  // Iterasi KDF (PBKDF2) untuk hashing PIN perangkat lokal
  static const int pinKdfIterations = 100000;
  static const int pinSaltLengthBytes = 16;
}
