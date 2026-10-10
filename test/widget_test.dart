import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anakkost/app/app.dart';

void main() {
  testWidgets('Smoke test navigasi 5 tab utama Anak Kost', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AnakKostApp(),
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
