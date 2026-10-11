import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'crypto_constants.dart';
import 'encryption_service.dart';

/// Amplop master key yang dibungkus (wrapped)
class KeyEnvelope {
  final String keyPurpose; // media, vault, recovery
  final int keyVersion;
  final String cryptoContextId;
  final Uint8List wrappedMasterKey;
  final Uint8List wrapNonce;
  final Uint8List recoverySalt;
  final int cryptoVersion;

  const KeyEnvelope({
    required this.keyPurpose,
    this.keyVersion = 1,
    required this.cryptoContextId,
    required this.wrappedMasterKey,
    required this.wrapNonce,
    required this.recoverySalt,
    this.cryptoVersion = CryptoConstants.cryptoVersion,
  });
}

/// Pengelola Kunci Enkripsi Master & Pemulihan (Recovery)
/// Sesuai PRD GAMINI.md Bagian 7.6 & Bagian 10.6
class KeyManager {
  final EncryptionService _encryptionService;
  final FlutterSecureStorage _secureStorage;

  KeyManager({
    EncryptionService? encryptionService,
    FlutterSecureStorage? secureStorage,
  })  : _encryptionService = encryptionService ?? EncryptionService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Menghasilkan master key acak 256-bit baru
  Uint8List generateMasterKey() {
    return _encryptionService.generateRandomBytes(CryptoConstants.aesKeyLengthBytes);
  }

  /// Membungkus (wrap) master key dengan recovery secret menggunakan AES-256-GCM + PBKDF2
  Future<KeyEnvelope> wrapMasterKeyWithRecoverySecret({
    required Uint8List masterKey,
    required String recoverySecret,
    required String cryptoContextId,
    required String keyPurpose,
    int keyVersion = 1,
  }) async {
    final salt = _encryptionService.generateRandomBytes(CryptoConstants.recoverySaltLengthBytes);
    final wrappingKey = await _encryptionService.deriveKeyPbkdf2(
      passwordOrSecret: recoverySecret,
      salt: salt,
      iterations: 100000,
    );

    final encrypted = await _encryptionService.encrypt(
      plaintext: masterKey,
      key: wrappingKey,
      aad: cryptoContextId.codeUnits,
    );

    return KeyEnvelope(
      keyPurpose: keyPurpose,
      keyVersion: keyVersion,
      cryptoContextId: cryptoContextId,
      wrappedMasterKey: encrypted.combinedWithTag,
      wrapNonce: encrypted.nonce,
      recoverySalt: salt,
    );
  }

  /// Membuka bungkus (unwrap) master key menggunakan recovery secret
  Future<Uint8List> unwrapMasterKeyWithRecoverySecret({
    required KeyEnvelope envelope,
    required String recoverySecret,
  }) async {
    final wrappingKey = await _encryptionService.deriveKeyPbkdf2(
      passwordOrSecret: recoverySecret,
      salt: envelope.recoverySalt,
      iterations: 100000,
    );

    final payload = EncryptedPayload.fromCombined(
      combined: envelope.wrappedMasterKey,
      nonce: envelope.wrapNonce,
    );

    return _encryptionService.decrypt(
      ciphertext: payload.ciphertext,
      key: wrappingKey,
      nonce: payload.nonce,
      tag: payload.tag,
      aad: envelope.cryptoContextId.codeUnits,
    );
  }

  /// Menyimpan master key lokal di FlutterSecureStorage (terproteksi hardware Android Keystore)
  Future<void> saveLocalMasterKey(String purpose, Uint8List key) async {
    final hexString = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(
      key: '${AppConstants.secKeyMasterMediaEnvelope}_$purpose',
      value: hexString,
    );
  }

  /// Mengambil master key lokal dari FlutterSecureStorage
  Future<Uint8List?> getLocalMasterKey(String purpose) async {
    final hexString = await _secureStorage.read(
      key: '${AppConstants.secKeyMasterMediaEnvelope}_$purpose',
    );
    if (hexString == null || hexString.length != CryptoConstants.aesKeyLengthBytes * 2) {
      return null;
    }
    final bytes = <int>[];
    for (var i = 0; i < hexString.length; i += 2) {
      bytes.add(int.parse(hexString.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
