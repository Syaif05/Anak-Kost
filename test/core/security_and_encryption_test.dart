import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anakkost/core/security/encryption_service.dart';
import 'package:anakkost/core/security/key_manager.dart';

void main() {
  late EncryptionService encryptionService;
  late KeyManager keyManager;

  setUp(() {
    encryptionService = EncryptionService();
    keyManager = KeyManager(encryptionService: encryptionService);
  });

  group('EncryptionService AES-256-GCM Tests', () {
    test('Enkripsi dan dekripsi menghasilkan plaintext yang identik', () async {
      final key = encryptionService.generateRandomBytes(32);
      final plaintext = Uint8List.fromList('Data Rahasia KTP Anak Kost 123456'.codeUnits);
      final aad = 'user-context-123'.codeUnits;

      final encrypted = await encryptionService.encrypt(
        plaintext: plaintext,
        key: key,
        aad: aad,
      );

      expect(encrypted.ciphertext.length, plaintext.length);
      expect(encrypted.tag.length, 16);
      expect(encrypted.nonce.length, 12);

      final decrypted = await encryptionService.decrypt(
        ciphertext: encrypted.ciphertext,
        key: key,
        nonce: encrypted.nonce,
        tag: encrypted.tag,
        aad: aad,
      );

      expect(String.fromCharCodes(decrypted), 'Data Rahasia KTP Anak Kost 123456');
    });

    test('Modifikasi ciphertext menyebabkan kegagalan autentikasi GCM (Anti-Tampering)', () async {
      final key = encryptionService.generateRandomBytes(32);
      final plaintext = Uint8List.fromList('Kontrak Sewa Kost 2026'.codeUnits);

      final encrypted = await encryptionService.encrypt(
        plaintext: plaintext,
        key: key,
      );

      // Manipulasi 1 byte ciphertext
      final tamperedCiphertext = Uint8List.fromList(encrypted.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;

      expect(
        () async => await encryptionService.decrypt(
          ciphertext: tamperedCiphertext,
          key: key,
          nonce: encrypted.nonce,
          tag: encrypted.tag,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Modifikasi AAD menyebabkan kegagalan autentikasi GCM', () async {
      final key = encryptionService.generateRandomBytes(32);
      final plaintext = Uint8List.fromList('Catatan Keuangan'.codeUnits);

      final encrypted = await encryptionService.encrypt(
        plaintext: plaintext,
        key: key,
        aad: 'context-owner-A'.codeUnits,
      );

      // Coba dekripsi dengan context-owner-B
      expect(
        () async => await encryptionService.decrypt(
          ciphertext: encrypted.ciphertext,
          key: key,
          nonce: encrypted.nonce,
          tag: encrypted.tag,
          aad: 'context-owner-B'.codeUnits,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Derivasi kunci PBKDF2 deterministik untuk salt yang sama', () async {
      const pin = '123456';
      final salt = encryptionService.generateRandomBytes(16);

      final key1 = await encryptionService.deriveKeyPbkdf2(
        passwordOrSecret: pin,
        salt: salt,
        iterations: 1000,
      );

      final key2 = await encryptionService.deriveKeyPbkdf2(
        passwordOrSecret: pin,
        salt: salt,
        iterations: 1000,
      );

      expect(key1.length, 32);
      expect(key1, key2);
    });
  });

  group('KeyManager & Master Key Envelope Tests', () {
    test('Wrap dan unwrap master key dengan recovery secret berhasil', () async {
      final masterKey = keyManager.generateMasterKey();
      const recoverySecret = 'kunci-pemulihan-32-karakter-acak-anak-kost';
      const contextId = 'crypto-ctx-uuid-001';

      final envelope = await keyManager.wrapMasterKeyWithRecoverySecret(
        masterKey: masterKey,
        recoverySecret: recoverySecret,
        cryptoContextId: contextId,
        keyPurpose: 'vault',
      );

      expect(envelope.keyPurpose, 'vault');
      expect(envelope.wrappedMasterKey.length, masterKey.length + 16);

      final restoredMasterKey = await keyManager.unwrapMasterKeyWithRecoverySecret(
        envelope: envelope,
        recoverySecret: recoverySecret,
      );

      expect(restoredMasterKey, masterKey);
    });

    test('Unwrap dengan recovery secret yang salah melempar authentication error', () async {
      final masterKey = keyManager.generateMasterKey();
      const recoverySecret = 'kunci-pemulihan-benar';
      const contextId = 'crypto-ctx-uuid-001';

      final envelope = await keyManager.wrapMasterKeyWithRecoverySecret(
        masterKey: masterKey,
        recoverySecret: recoverySecret,
        cryptoContextId: contextId,
        keyPurpose: 'vault',
      );

      expect(
        () async => await keyManager.unwrapMasterKeyWithRecoverySecret(
          envelope: envelope,
          recoverySecret: 'kunci-pemulihan-SALAH',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
