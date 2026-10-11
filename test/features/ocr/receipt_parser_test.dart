import 'package:flutter_test/flutter_test.dart';
import 'package:anakkost/features/ocr/domain/models/ocr_models.dart';
import 'package:anakkost/features/ocr/domain/models/receipt_draft.dart';
import 'package:anakkost/features/ocr/domain/services/receipt_parser.dart';

void main() {
  late DeterministicReceiptParser parser;

  setUp(() {
    parser = DeterministicReceiptParser();
  });

  group('Deterministic Receipt Parser Tests (Fase 5)', () {
    test('Gate Test T11: Parser mampu memisahkan total dari subtotal, tunai, dan kembalian pada struk uji', () {
      final ocrResult = OcrResult.fromRawLines([
        'SUPERINDO KALIURANG',
        'JL. KALIURANG KM 6 YOGYAKARTA',
        'TGL: 10/10/2026 14:30',
        '================================',
        'BERAS ROJOLELE 5KG 75.000',
        'SABUN MANDI 2 PCS 10.000',
        '--------------------------------',
        'SUBTOTAL Rp 85.000',
        'DISKON Rp 5.000',
        'TOTAL Rp 80.000',
        'TUNAI Rp 100.000',
        'KEMBALIAN Rp 20.000',
        '================================',
        'TERIMA KASIH TELAH BERBELANJA',
      ]);

      final draft = parser.parse(ocrResult);

      // Verifikasi A: Merchant dan Tanggal
      expect(draft.merchantCandidate, contains('SUPERINDO'));
      expect(draft.localDateCandidate, '2026-10-10');

      // Verifikasi B (Gate T11 Inti):
      // Total HARUS Rp80.000. Parser TIDAK BOLEH salah memilih Tunai (Rp100.000) atau Kembalian (Rp20.000)
      expect(draft.totalRpCandidate, 80000);
      expect(draft.subtotalRp, 85000);
      expect(draft.discountRp, 5000);
      expect(draft.cashTenderedRp, 100000);
      expect(draft.changeRp, 20000);
      expect(draft.paymentMethod, 'cash');

      // Verifikasi C: Item belanja
      expect(draft.items, hasLength(2));
      expect(draft.items.first.name, contains('BERAS ROJOLELE'));
      expect(draft.items.first.lineTotalRp, 75000);
      expect(draft.items[1].name, contains('SABUN MANDI'));
      expect(draft.items[1].lineTotalRp, 10000);

      // Verifikasi D: Confidence & Konfirmasi Status
      expect(draft.confirmed, isFalse); // Wajib false (save_without_user_review: forbidden)
      expect(draft.parserConfidence, ParserConfidence.high);
    });

    test('Deteksi Struk Indomaret dengan QRIS dan format tanggal teks (DD-MMM-YYYY)', () {
      final ocrResult = OcrResult.fromRawLines([
        'INDOMARET GEJAYAN',
        '15-OKT-2026',
        'INDOMIE AYAM BAWANG 5 PCS 17.500',
        'ULTRA MILK COKELAT 1L 21.000',
        'JUMLAH Rp 38.500',
        'QRIS Rp 38.500',
        'TERIMA KASIH',
      ]);

      final draft = parser.parse(ocrResult);

      expect(draft.merchantCandidate, contains('INDOMARET'));
      expect(draft.localDateCandidate, '2026-10-15');
      expect(draft.totalRpCandidate, 38500);
      expect(draft.paymentMethod, 'qris');
      expect(draft.items, hasLength(2));
    });

    test('Deteksi Label dan Nominal Finansial pada Baris Terpisah (Multline Label)', () {
      final ocrResult = OcrResult.fromRawLines([
        'ALFAMART PASTEUR',
        '12/11/2026',
        'ROTI TAWAR SARI ROTI 15.000',
        'SUSU BEAR BRAND 10.000',
        'TOTAL BELANJA',
        'Rp 25.000',
        'TUNAI',
        'Rp 50.000',
        'KEMBALI',
        'Rp 25.000',
      ]);

      final draft = parser.parse(ocrResult);

      expect(draft.merchantCandidate, contains('ALFAMART'));
      expect(draft.localDateCandidate, '2026-11-12');
      expect(draft.totalRpCandidate, 25000);
      expect(draft.cashTenderedRp, 50000);
      expect(draft.changeRp, 25000);
    });

    test('Penanganan Typo OCR Karakter O dan Format Desimal Sen Indonesia', () {
      final ocrResult = OcrResult.fromRawLines([
        'WARUNG MADURA',
        '05/09/2026',
        'TELUR 1KG 28.000,00',
        'MINYAK GORENG 14.O00',
        'TOTAL',
        'Rp 42.OOO',
      ]);

      final draft = parser.parse(ocrResult);

      expect(draft.merchantCandidate, contains('WARUNG MADURA'));
      expect(draft.localDateCandidate, '2026-09-05');
      expect(draft.totalRpCandidate, 42000);
      expect(draft.items, hasLength(2));
      expect(draft.items.first.lineTotalRp, 28000);
      expect(draft.items[1].lineTotalRp, 14000);
    });
  });
}
