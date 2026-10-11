import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:anakkost/core/security/app_lock_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage mockSecureStorage;
  late AppLockService appLockService;
  final Map<String, String> memoryStorage = {};

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    memoryStorage.clear();

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      return memoryStorage[key];
    });

    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String;
      memoryStorage[key] = value;
    });

    appLockService = AppLockService(secureStorage: mockSecureStorage);
  });

  group('AppLockService PIN & Cooldown Tests', () {
    test('Status awal adalah notConfigured jika belum ada PIN', () async {
      await appLockService.initialize();
      expect(appLockService.status, AppLockStatus.notConfigured);
    });

    test('Setup PIN 6-digit berhasil dan membuka aplikasi', () async {
      final success = await appLockService.setupPin('123456');
      expect(success, isTrue);
      expect(appLockService.status, AppLockStatus.unlocked);
      expect(await appLockService.isPinSet(), isTrue);
    });

    test('Setup PIN kurang dari 6 digit ditolak dengan ArgumentError', () async {
      expect(() async => await appLockService.setupPin('1234'), throwsArgumentError);
    });

    test('Verifikasi PIN yang benar berhasil membuka aplikasi', () async {
      await appLockService.setupPin('654321');
      appLockService.lock();
      expect(appLockService.isLocked, isTrue);

      final unlocked = await appLockService.unlockWithPin('654321');
      expect(unlocked, isTrue);
      expect(appLockService.status, AppLockStatus.unlocked);
      expect(appLockService.failedAttempts, 0);
    });

    test('Salah PIN 5 kali memicu status cooldown tanpa menghapus data', () async {
      await appLockService.setupPin('112233');
      appLockService.lock();

      // Coba PIN salah 4 kali
      for (var i = 0; i < 4; i++) {
        final res = await appLockService.unlockWithPin('000000');
        expect(res, isFalse);
        expect(appLockService.status, AppLockStatus.locked);
      }
      expect(appLockService.failedAttempts, 4);

      // Coba PIN salah ke-5 kali -> Masuk cooldown
      final res5 = await appLockService.unlockWithPin('000000');
      expect(res5, isFalse);
      expect(appLockService.status, AppLockStatus.cooldown);
      expect(appLockService.cooldownUntil, isNotNull);
      expect(appLockService.failedAttempts, 5);

      // Selama cooldown, mencoba PIN yang benar pun tetap ditolak
      final resWhileCooldown = await appLockService.unlockWithPin('112233');
      expect(resWhileCooldown, isFalse);
    });
  });
}
