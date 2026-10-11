import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../constants/app_constants.dart';
import 'crypto_constants.dart';
import 'encryption_service.dart';

/// Status Kunci Aplikasi
enum AppLockStatus {
  notConfigured, // Belum pernah membuat PIN
  locked, // Terkunci, memerlukan PIN atau biometrik
  unlocked, // Terbuka
  cooldown, // Terkunci sementara karena 5+ kegagalan PIN
}

/// Layanan Kunci Aplikasi (App Lock)
/// Sesuai PRD GAMINI.md Bagian 7.6:
/// - PIN minimal 6 digit dengan PBKDF2 hash & salt (bukan plaintext)
/// - Biometrik via local_auth
/// - Jeda meningkat setelah 5 kegagalan tanpa hapus data otomatis
class AppLockService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final EncryptionService _encryptionService;
  final int kdfIterations;

  AppLockStatus _status = AppLockStatus.locked;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;
  bool _isBiometricsSupported = false;

  AppLockStatus get status => _status;
  bool get isLocked => _status == AppLockStatus.locked || _status == AppLockStatus.cooldown;
  int get failedAttempts => _failedAttempts;
  DateTime? get cooldownUntil => _cooldownUntil;
  bool get isBiometricsSupported => _isBiometricsSupported;

  AppLockService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
    EncryptionService? encryptionService,
    this.kdfIterations = CryptoConstants.pinKdfIterations,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication(),
        _encryptionService = encryptionService ?? EncryptionService();

  /// Inisialisasi status kunci aplikasi
  Future<void> initialize() async {
    final pinHash = await _secureStorage.read(key: AppConstants.secKeyAppPinHash);
    if (pinHash == null) {
      _status = AppLockStatus.notConfigured;
    } else {
      _status = AppLockStatus.locked;
    }

    try {
      _isBiometricsSupported = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      _isBiometricsSupported = false;
    }
    notifyListeners();
  }

  /// Menyiapkan PIN 6-digit pertama kali
  Future<bool> setupPin(String pin) async {
    if (pin.length < 6 || int.tryParse(pin) == null) {
      throw ArgumentError('PIN harus minimal 6 digit angka numerik');
    }

    final salt = _encryptionService.generateRandomBytes(CryptoConstants.pinSaltLengthBytes);
    final derived = await _encryptionService.deriveKeyPbkdf2(
      passwordOrSecret: pin,
      salt: salt,
      iterations: kdfIterations,
    );

    final hashHex = base64Encode(derived);
    final saltHex = base64Encode(salt);

    await _secureStorage.write(key: AppConstants.secKeyAppPinHash, value: hashHex);
    await _secureStorage.write(key: AppConstants.secKeyAppPinSalt, value: saltHex);

    _status = AppLockStatus.unlocked;
    _failedAttempts = 0;
    _cooldownUntil = null;
    notifyListeners();
    return true;
  }

  /// Memeriksa apakah PIN sudah diatur
  Future<bool> isPinSet() async {
    final pinHash = await _secureStorage.read(key: AppConstants.secKeyAppPinHash);
    return pinHash != null;
  }

  /// Verifikasi PIN untuk membuka aplikasi
  Future<bool> unlockWithPin(String pin) async {
    // Periksa cooldown
    if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) {
      _status = AppLockStatus.cooldown;
      notifyListeners();
      return false;
    }

    final storedHash = await _secureStorage.read(key: AppConstants.secKeyAppPinHash);
    final storedSalt = await _secureStorage.read(key: AppConstants.secKeyAppPinSalt);

    if (storedHash == null || storedSalt == null) {
      _status = AppLockStatus.notConfigured;
      notifyListeners();
      return false;
    }

    final salt = base64Decode(storedSalt);
    final derived = await _encryptionService.deriveKeyPbkdf2(
      passwordOrSecret: pin,
      salt: salt,
      iterations: kdfIterations,
    );
    final candidateHash = base64Encode(derived);

    if (candidateHash == storedHash) {
      _status = AppLockStatus.unlocked;
      _failedAttempts = 0;
      _cooldownUntil = null;
      notifyListeners();
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        // Terapkan jeda 30 detik pada kegagalan ke-5, 60 detik jika berlanjut
        final cooldownSeconds = _failedAttempts >= 8 ? 60 : 30;
        _cooldownUntil = DateTime.now().add(Duration(seconds: cooldownSeconds));
        _status = AppLockStatus.cooldown;
      }
      notifyListeners();
      return false;
    }
  }

  /// Membuka aplikasi menggunakan biometrik perangkat
  Future<bool> unlockWithBiometrics({String reason = 'Buka aplikasi Anak Kost'}) async {
    if (!_isBiometricsSupported) return false;

    // Periksa apakah cooldown sedang aktif
    if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) {
      return false;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );

      if (authenticated) {
        _status = AppLockStatus.unlocked;
        _failedAttempts = 0;
        _cooldownUntil = null;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Gagal autentikasi biometrik
    }
    return false;
  }

  /// Mengunci aplikasi secara manual atau otomatis
  void lock() {
    if (_status != AppLockStatus.notConfigured) {
      _status = AppLockStatus.locked;
      notifyListeners();
    }
  }
}
