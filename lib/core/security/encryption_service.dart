import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'crypto_constants.dart';

/// Hasil enkripsi AES-256-GCM
class EncryptedPayload {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List tag;

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
  });

  /// Menggabungkan ciphertext + tag (16 byte) menjadi single payload standar
  Uint8List get combinedWithTag {
    final result = Uint8List(ciphertext.length + tag.length);
    result.setAll(0, ciphertext);
    result.setAll(ciphertext.length, tag);
    return result;
  }

  /// Memisahkan combined payload (ciphertext + 16 byte tag)
  static EncryptedPayload fromCombined({
    required Uint8List combined,
    required Uint8List nonce,
  }) {
    if (combined.length < CryptoConstants.gcmTagLengthBytes) {
      throw ArgumentError('Combined payload terlalu pendek untuk memuat GCM tag');
    }
    final ciphertextLength = combined.length - CryptoConstants.gcmTagLengthBytes;
    final ciphertext = combined.sublist(0, ciphertextLength);
    final tag = combined.sublist(ciphertextLength);
    return EncryptedPayload(ciphertext: ciphertext, nonce: nonce, tag: tag);
  }
}

/// Layanan Kriptografi Klien menggunakan AES-256-GCM & PBKDF2-HMAC-SHA256
/// Sesuai PRD GAMINI.md Bagian 7.6 & Bagian 10.6
class EncryptionService {
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();
  final Random _secureRandom = Random.secure();

  /// Menghasilkan byte acak berentropi tinggi
  Uint8List generateRandomBytes(int length) {
    final values = List<int>.generate(length, (_) => _secureRandom.nextInt(256));
    return Uint8List.fromList(values);
  }

  /// Enkripsi data menggunakan AES-256-GCM dengan AAD (Additional Authenticated Data) opsional
  Future<EncryptedPayload> encrypt({
    required Uint8List plaintext,
    required Uint8List key,
    Uint8List? nonce,
    List<int>? aad,
  }) async {
    if (key.length != CryptoConstants.aesKeyLengthBytes) {
      throw ArgumentError('Panjang kunci AES harus tepat 32 byte (256-bit)');
    }

    final secretKey = SecretKey(key);
    final actualNonce = nonce ?? generateRandomBytes(CryptoConstants.gcmNonceLengthBytes);

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: actualNonce,
      aad: aad ?? const <int>[],
    );

    return EncryptedPayload(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: Uint8List.fromList(secretBox.nonce),
      tag: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  /// Dekripsi ciphertext AES-256-GCM
  /// Jika ciphertext, tag, atau AAD telah dimodifikasi, verifikasi MAC akan gagal dan melempar SecretBoxAuthenticationError
  Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List tag,
    List<int>? aad,
  }) async {
    if (key.length != CryptoConstants.aesKeyLengthBytes) {
      throw ArgumentError('Panjang kunci AES harus tepat 32 byte (256-bit)');
    }

    final secretKey = SecretKey(key);
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(tag),
    );

    final cleartext = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: aad ?? const <int>[],
    );

    return Uint8List.fromList(cleartext);
  }

  /// Derivasi Kunci Kriptografi menggunakan PBKDF2-HMAC-SHA256
  Future<Uint8List> deriveKeyPbkdf2({
    required String passwordOrSecret,
    required Uint8List salt,
    int iterations = CryptoConstants.pinKdfIterations,
    int bits = 256,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac(_sha256),
      iterations: iterations,
      bits: bits,
    );

    final secretKey = SecretKey(passwordOrSecret.codeUnits);
    final derived = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );

    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
