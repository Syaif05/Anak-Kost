import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:anakkost/app/app.dart';
import 'package:anakkost/core/providers/core_providers.dart';
import 'package:anakkost/core/security/app_lock_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  late MockSecureStorage mockSecureStorage;
  late MockLocalAuth mockLocalAuth;
  final Map<String, String> memoryStorage = {};

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    mockLocalAuth = MockLocalAuth();
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

    when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
    when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);
  });

  testWidgets('Aplikasi baru (belum ada PIN) mengarahkan ke SetupPinScreen', (WidgetTester tester) async {
    final lockService = AppLockService(
      secureStorage: mockSecureStorage,
      localAuth: mockLocalAuth,
      kdfIterations: 10,
    );
    await lockService.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockServiceProvider.overrideWithValue(lockService),
        ],
        child: const AnakKostApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buat PIN 6-Digit'), findsOneWidget);
  });

  testWidgets('Aplikasi terkunci menampilkan LockScreen', (WidgetTester tester) async {
    final lockService = AppLockService(
      secureStorage: mockSecureStorage,
      localAuth: mockLocalAuth,
      kdfIterations: 10,
    );
    await lockService.setupPin('123456');
    lockService.lock();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockServiceProvider.overrideWithValue(lockService),
        ],
        child: const AnakKostApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masukkan PIN'), findsOneWidget);
  });

  testWidgets('Aplikasi yang telah di-unlock menampilkan 5 tab navigasi utama', (WidgetTester tester) async {
    final lockService = AppLockService(
      secureStorage: mockSecureStorage,
      localAuth: mockLocalAuth,
      kdfIterations: 10,
    );
    await lockService.setupPin('123456'); // setupPin langsung meng-unlock

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockServiceProvider.overrideWithValue(lockService),
        ],
        child: const AnakKostApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi 5 tab destinasi muncul di NavigationBar
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Keuangan'), findsOneWidget);
    expect(find.text('Kebutuhan'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Kost'), findsOneWidget);

    // Verifikasi Beranda awal tampil
    expect(find.text('Total Saldo'), findsOneWidget);
  });
}
