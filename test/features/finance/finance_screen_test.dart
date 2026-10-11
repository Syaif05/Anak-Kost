import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart' as drift;

import 'package:intl/date_symbol_data_local.dart';

import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/core/providers/core_providers.dart';
import 'package:anakkost/features/finance/data/finance_repository.dart';
import 'package:anakkost/features/finance/presentation/finance_screen.dart';
import 'package:anakkost/features/finance/presentation/providers/finance_providers.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late AppDatabase db;
  late MockSecureStorage mockSecureStorage;
  late FinanceRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() async {
    db = AppDatabase.inMemory();
    mockSecureStorage = MockSecureStorage();

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'mock-device-id');
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    repository = FinanceRepository(
      db: db,
      dao: db.financeDao,
      secureStorage: mockSecureStorage,
    );

    // Seed dummy user profile
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'test-user-001',
            cryptoContextId: 'test-crypto-001',
            displayName: const drift.Value('Anak Kost Test'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // Seed default wallets & categories
    await repository.seedDefaultsIfEmpty();

    FlutterError.onError = (FlutterErrorDetails details) {
      // ignore: avoid_print
      print('FLUTTER_ERROR: ${details.exceptionAsString()}');
    };
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        financeRepositoryProvider.overrideWithValue(repository),
        financeDaoProvider.overrideWithValue(repository.dao),
      ],
      child: const MaterialApp(
        home: FinanceScreen(),
      ),
    );
  }

  testWidgets('FinanceScreen renders BalanceCard and toggles balance visibility', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verifikasi judul layar dan komponen utama
    expect(find.text('Keuangan & Budget'), findsOneWidget);
    expect(find.text('Total Saldo Aktif'), findsOneWidget);
    expect(find.text('Rp0'), findsWidgets);

    // Verifikasi tombol aksi cepat
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Tabungan'), findsOneWidget);

    // Verifikasi toggle mata (visibility)
    final eyeButton = find.byIcon(Icons.visibility_outlined);
    expect(eyeButton, findsOneWidget);

    await tester.tap(eyeButton);
    await tester.pumpAndSettle();

    // Saldo tertutup
    expect(find.text('••••••••'), findsOneWidget);

    // Buka kembali
    final eyeOffButton = find.byIcon(Icons.visibility_off_outlined);
    expect(eyeOffButton, findsOneWidget);
    await tester.tap(eyeOffButton);
    await tester.pumpAndSettle();

    expect(find.text('Rp0'), findsWidgets);

    // Unmount and flush pending timers
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('FinanceScreen menampilkan daftar dompet dan bagian budget', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Daftar Dompet'), findsOneWidget);
    expect(find.text('Dompet Tunai'), findsOneWidget);
    expect(find.text('Rekening Bank'), findsOneWidget);
    expect(find.text('E-Wallet'), findsOneWidget);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Unmount and flush pending timers
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
