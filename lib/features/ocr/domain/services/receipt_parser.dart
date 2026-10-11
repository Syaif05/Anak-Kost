import 'package:uuid/uuid.dart';

import '../models/ocr_models.dart';
import '../models/receipt_draft.dart';

/// Parser Struk Deterministik (PRD GAMINI.md Bagian 3.6.2 & Bagian 10.6)
/// Menjalankan ekstraksi berbasis aturan (rule-based) cerdas:
/// 1. Toko/Merchant dari header atas
/// 2. Tanggal format lokal Indonesia
/// 3. Pemisahan ketat TOTAL vs SUBTOTAL, TUNAI, dan KEMBALIAN (Gate Test T11)
/// 4. Parsing baris item belanja (nama, jumlah, unit, harga satuan, subtotal)
/// 5. Validasi integritas dan kalkulasi confidence parser
class DeterministicReceiptParser {
  final Uuid _uuid = const Uuid();

  ReceiptDraft parse(OcrResult ocrResult, {String? imagePath}) {
    final lines = ocrResult.lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).toList();

    if (lines.isEmpty) {
      return ReceiptDraft(
        draftId: _uuid.v4(),
        totalRpCandidate: 0,
        parserConfidence: ParserConfidence.low,
        warnings: const ['Tidak ada teks yang terdeteksi pada struk'],
        imagePath: imagePath,
      );
    }

    final merchant = _extractMerchant(lines);
    final date = _extractDate(lines);

    // Ekstraksi nilai finansial terlabel
    final financialFigures = _extractFinancialFigures(lines);
    final totalCandidate = financialFigures.totalRp;
    final subtotalCandidate = financialFigures.subtotalRp;
    final taxCandidate = financialFigures.taxRp;
    final discountCandidate = financialFigures.discountRp;
    final cashTendered = financialFigures.cashTenderedRp;
    final changeCandidate = financialFigures.changeRp;
    final paymentMethod = financialFigures.paymentMethod;

    // Ekstraksi item belanja
    final items = _extractItems(lines);

    // Evaluasi integritas & confidence
    final warnings = <String>[];
    var confidence = ParserConfidence.medium;

    if (totalCandidate <= 0) {
      confidence = ParserConfidence.low;
      warnings.add('Total belanja tidak dapat dikenali secara pasti dari struk');
    } else {
      final itemsTotal = items.fold<int>(0, (sum, it) => sum + it.lineTotalRp);
      if (items.isNotEmpty) {
        final expectedTotal = (subtotalCandidate ?? itemsTotal) + (taxCandidate ?? 0) - (discountCandidate ?? 0);
        if (expectedTotal == totalCandidate || itemsTotal == totalCandidate) {
          confidence = ParserConfidence.high;
        } else if ((itemsTotal - totalCandidate).abs() > 500) {
          warnings.add('Jumlah total item (Rp $itemsTotal) berbeda dari total struk (Rp $totalCandidate)');
          confidence = ParserConfidence.medium;
        }
      }
    }

    if (changeCandidate != null && cashTendered != null && totalCandidate > 0) {
      final calculatedChange = cashTendered - totalCandidate;
      if ((calculatedChange - changeCandidate).abs() > 500) {
        warnings.add('Kembalian struk (Rp $changeCandidate) berbeda dari selisih tunai dan total (Rp $calculatedChange)');
      }
    }

    return ReceiptDraft(
      draftId: _uuid.v4(),
      merchantCandidate: merchant,
      localDateCandidate: date,
      totalRpCandidate: totalCandidate,
      subtotalRp: subtotalCandidate,
      taxRp: taxCandidate,
      discountRp: discountCandidate,
      cashTenderedRp: cashTendered,
      changeRp: changeCandidate,
      paymentMethod: paymentMethod,
      parserConfidence: confidence,
      warnings: warnings,
      items: items,
      confirmed: false,
      imagePath: imagePath,
    );
  }

  /// 1. Deteksi Toko/Merchant dari Header (baris 1 - 5)
  String? _extractMerchant(List<String> lines) {
    final knownMerchants = [
      'SUPERINDO',
      'INDOMARET',
      'ALFAMART',
      'ALFAMIDI',
      'TRANS MART',
      'TRANSMART',
      'CARREFOUR',
      'HYPERMART',
      'YOGYA',
      'TIP TOP',
      'NAGA SWALAYAN',
      'CIRCLE K',
      'FAMILYMART',
      'LAWSON',
      'WARUNG',
      'FARMASI',
      'APOTEK',
      'FOTOKOPI',
      'LAUNDRY',
    ];

    // Cek pada 6 baris pertama
    final searchLimit = lines.length < 6 ? lines.length : 6;
    for (int i = 0; i < searchLimit; i++) {
      final upper = lines[i].toUpperCase();
      for (final km in knownMerchants) {
        if (upper.contains(km)) {
          return lines[i].replaceAll(RegExp(r'[^a-zA-Z0-9\s\.\-]'), '').trim();
        }
      }
    }

    // Fallback: Ambil baris pertama yang berisi alfabet dan bukan tanggal/telepon/struk
    for (int i = 0; i < searchLimit; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();
      if (upper.contains('STRUK') ||
          upper.contains('RECEIPT') ||
          upper.contains('INVOICE') ||
          upper.contains('JL.') ||
          upper.contains('JALAN') ||
          upper.contains('TELP') ||
          upper.contains('NO.') ||
          RegExp(r'^\d').hasMatch(line)) {
        continue;
      }
      if (RegExp(r'[a-zA-Z]{3,}').hasMatch(line)) {
        return line.trim();
      }
    }

    return null;
  }

  /// 2. Deteksi Tanggal Lokal Format Indonesia
  String? _extractDate(List<String> lines) {
    final monthMap = {
      'JAN': '01',
      'JANUARI': '01',
      'FEB': '02',
      'FEBRUARI': '02',
      'MAR': '03',
      'MARET': '03',
      'APR': '04',
      'APRIL': '04',
      'MEI': '05',
      'MAY': '05',
      'JUN': '06',
      'JUNI': '06',
      'JUL': '07',
      'JULI': '07',
      'AGU': '08',
      'AGT': '08',
      'AGUSTUS': '08',
      'AUG': '08',
      'SEP': '09',
      'SEPT': '09',
      'SEPTEMBER': '09',
      'OKT': '10',
      'OCT': '10',
      'OKTOBER': '10',
      'NOV': '11',
      'NOP': '11',
      'NOVEMBER': '11',
      'DES': '12',
      'DEC': '12',
      'DESEMBER': '12',
    };

    // Pola A: DD/MM/YYYY atau DD-MM-YYYY atau DD.MM.YYYY
    final numDatePattern = RegExp(r'\b([0-3]?\d)[\/\-\.]([0-1]?\d)[\/\-\.](\d{2,4})\b');

    // Pola B: DD MMM YYYY (misal: 11 Okt 2026 atau 11-Okt-2026)
    final textDatePattern = RegExp(r'\b([0-3]?\d)[\s\-\.]([a-zA-Z]{3,9})[\s\-\.](\d{2,4})\b');

    for (final line in lines) {
      // Coba pola B terlebih dahulu (teks nama bulan)
      final matchText = textDatePattern.firstMatch(line);
      if (matchText != null) {
        final dayStr = matchText.group(1)!.padLeft(2, '0');
        final monthStr = matchText.group(2)!.toUpperCase();
        var yearStr = matchText.group(3)!;
        if (yearStr.length == 2) yearStr = '20$yearStr';

        final m = monthMap[monthStr];
        if (m != null) {
          final day = int.tryParse(dayStr) ?? 0;
          if (day >= 1 && day <= 31) {
            return '$yearStr-$m-$dayStr';
          }
        }
      }

      // Coba pola A (angka)
      final matchNum = numDatePattern.firstMatch(line);
      if (matchNum != null) {
        final dayStr = matchNum.group(1)!.padLeft(2, '0');
        final monthStr = matchNum.group(2)!.padLeft(2, '0');
        var yearStr = matchNum.group(3)!;
        if (yearStr.length == 2) yearStr = '20$yearStr';

        final day = int.tryParse(dayStr) ?? 0;
        final month = int.tryParse(monthStr) ?? 0;
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          return '$yearStr-$monthStr-$dayStr';
        }
      }
    }

    return null;
  }

  /// 3. Ekstraksi Finansial Terlabel (Gate Test T11)
  /// Memisahkan TOTAL secara deterministik dari SUBTOTAL, TUNAI/BAYAR, dan KEMBALIAN
  _FinancialFigures _extractFinancialFigures(List<String> lines) {
    int totalRp = 0;
    int? subtotalRp;
    int? taxRp;
    int? discountRp;
    int? cashTenderedRp;
    int? changeRp;
    String? paymentMethod;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();

      // a. KEMBALIAN / CHANGE
      if (upper.contains('KEMBALI') || upper.contains('CHANGE')) {
        final amount = _parseRupiahFromLine(line, searchNextLines: lines, currentIndex: i);
        if (amount != null && amount >= 0) {
          changeRp = amount;
          continue;
        }
      }

      // b. TUNAI / CASH / DIBAYAR / BAYAR (Uang yang diserahkan konsumen)
      // Catatan: hindari false positive jika ada "TOTAL BAYAR"
      if ((upper.contains('TUNAI') || upper.contains('CASH') || upper.contains('BAYAR')) &&
          !upper.contains('TOTAL') &&
          !upper.contains('GRAND') &&
          !upper.contains('JUMLAH')) {
        final amount = _parseRupiahFromLine(line, searchNextLines: lines, currentIndex: i);
        if (amount != null && amount > 0) {
          cashTenderedRp = amount;
          paymentMethod ??= 'cash';
          continue;
        }
      }

      // c. METODE NON-TUNAI: QRIS / DEBIT / BCA / MANDIRI / GOPAY / OVO / SHOPEEPAY
      if (upper.contains('QRIS') ||
          upper.contains('DEBIT') ||
          upper.contains('KARTU') ||
          upper.contains('GOPAY') ||
          upper.contains('OVO') ||
          upper.contains('SHOPEEPAY')) {
        paymentMethod = upper.contains('QRIS') ? 'qris' : 'debit';
      }

      // d. SUBTOTAL / SUB TOTAL
      if (upper.contains('SUBTOTAL') || upper.contains('SUB TOTAL')) {
        final amount = _parseRupiahFromLine(line, searchNextLines: lines, currentIndex: i);
        if (amount != null && amount > 0) {
          subtotalRp = amount;
          continue;
        }
      }

      // e. PAJAK / PPN / PB1 / TAX
      if (upper.contains('PPN') || upper.contains('PAJAK') || upper.contains('TAX') || upper.contains('PB1')) {
        final amount = _parseRupiahFromLine(line, searchNextLines: lines, currentIndex: i);
        if (amount != null && amount >= 0) {
          taxRp = amount;
          continue;
        }
      }

      // f. DISKON / POTONGAN / HEMAT / DISC
      if (upper.contains('DISKON') || upper.contains('POTONGAN') || upper.contains('HEMAT') || upper.contains('DISC')) {
        final amount = _parseRupiahFromLine(line, searchNextLines: lines, currentIndex: i);
        if (amount != null && amount > 0) {
          discountRp = amount;
          continue;
        }
      }

      // g. TOTAL / GRAND TOTAL / JUMLAH / TOTAL BELANJA / TOTAL AKHIR / TOTAL BAYAR
      if (upper.contains('GRAND TOTAL') ||
          upper.contains('TOTAL BELANJA') ||
          upper.contains('TOTAL AKHIR') ||
          upper.contains('TOTAL BAYAR') ||
          upper.contains('TOTAL:') ||
          upper.contains('TOTAL ') ||
          upper == 'TOTAL' ||
          upper.contains('JUMLAH:') ||
          upper.contains('JUMLAH ') ||
          upper == 'JUMLAH') {
        // Jangan keliru dengan Subtotal
        if (!upper.contains('SUBTOTAL') && !upper.contains('SUB TOTAL')) {
          final amount = _parseRupiahFromLine(line, searchNextLines: lines, currentIndex: i);
          if (amount != null && amount > 0) {
            totalRp = amount;
          }
        }
      }
    }

    return _FinancialFigures(
      totalRp: totalRp,
      subtotalRp: subtotalRp,
      taxRp: taxRp,
      discountRp: discountRp,
      cashTenderedRp: cashTenderedRp,
      changeRp: changeRp,
      paymentMethod: paymentMethod ?? 'cash',
    );
  }

  /// 4. Ekstraksi Item Belanja
  List<ReceiptDraftItem> _extractItems(List<String> lines) {
    final items = <ReceiptDraftItem>[];

    // Temukan rentang baris barang (setelah header toko, sebelum baris TOTAL/SUBTOTAL)
    int startIndex = 0;
    int endIndex = lines.length;

    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (upper.contains('TELP') ||
          upper.contains('INVOICE') ||
          upper.contains('RECEIPT') ||
          upper.contains('KASIR') ||
          upper.contains('CASHIER') ||
          upper.contains('TGL') ||
          upper.contains('TANGGAL')) {
        startIndex = i + 1;
      }
      if (upper.contains('SUBTOTAL') ||
          upper.contains('TOTAL') ||
          upper.contains('JUMLAH') ||
          upper.contains('TUNAI') ||
          upper.contains('BAYAR')) {
        endIndex = i;
        break;
      }
    }

    if (startIndex >= endIndex) {
      startIndex = 0;
      endIndex = lines.length;
    }

    for (int i = startIndex; i < endIndex; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();

      // Lewati baris separator garis/bintang
      if (RegExp(r'^[\=\-\*\.\_]{3,}$').hasMatch(line)) continue;

      // Lewati keyword non-item
      if (_isNonItemLine(upper)) continue;

      // Pola 1: Baris memuat Nama Barang + Harga di ujung kanan
      // Misal: "INDOMIE GORENG 3.500" atau "BERAS ROJOLELE 5KG 75.000"
      final parsedItem = _parseItemLine(line, lines, i);
      if (parsedItem != null) {
        items.add(parsedItem);
      }
    }

    return items;
  }

  bool _isNonItemLine(String upper) {
    // Abaikan baris tanggal format numerik (DD/MM/YYYY atau DD-MM-YYYY)
    if (RegExp(r'\b[0-3]?\d[\/\-][0-1]?\d[\/\-]\d{2,4}\b').hasMatch(upper) ||
        RegExp(r'\b[0-3]?\d[\s\-\.](?:JAN|FEB|MAR|APR|MEI|MAY|JUN|JUL|AGU|AGT|AUG|SEP|OKT|OCT|NOV|NOP|DES|DEC)[A-Z]*[\s\-\.]\d{2,4}\b').hasMatch(upper)) {
      return true;
    }

    return upper.contains('SUBTOTAL') ||
        upper.contains('TOTAL') ||
        upper.contains('JUMLAH') ||
        upper.contains('PPN') ||
        upper.contains('PAJAK') ||
        upper.contains('TUNAI') ||
        upper.contains('KEMBALI') ||
        upper.contains('BAYAR') ||
        upper.contains('TERIMA KASIH') ||
        upper.contains('THANK YOU') ||
        upper.contains('BARANG YANG SUDAH DIBELI') ||
        upper.contains('KASIR') ||
        upper.contains('CASHIER') ||
        upper.contains('OPERATOR') ||
        upper.contains('TGL') ||
        upper.contains('TANGGAL') ||
        upper.contains('TIME') ||
        upper.contains('JAM') ||
        upper.contains('ITEM:') ||
        upper.contains('ITEMS:') ||
        upper.contains('QRIS') ||
        upper.contains('DEBIT') ||
        upper.contains('KARTU') ||
        upper.contains('CASH') ||
        upper.contains('CHANGE') ||
        upper.contains('DISKON') ||
        upper.contains('POTONGAN') ||
        upper.contains('HEMAT') ||
        upper.contains('DISC');
  }

  ReceiptDraftItem? _parseItemLine(String line, List<String> lines, int index) {
    // Cari angka rupiah di akhir baris (mendukung typo OCR 'O' dan desimal sen)
    final numbers = RegExp(r'(\b[0-9][0-9oO\.,]*[0-9oO]|\b[0-9]+)\b').allMatches(line).toList();
    if (numbers.isEmpty) return null;

    final lastMatch = numbers.last;
    final priceStr = lastMatch.group(0)!;
    final price = _normalizeRupiah(priceStr);
    if (price == null || price <= 0 || price > 50000000) return null;

    // Nama barang adalah teks sebelum angka harga
    var namePart = line.substring(0, lastMatch.start).trim();
    namePart = namePart.replaceAll(RegExp(r'[\=\-\:\*]'), '').trim();

    // Nama barang wajib mengandung setidaknya 2 karakter alfabet
    if (namePart.isEmpty || !RegExp(r'[a-zA-Z]{2,}').hasMatch(namePart)) return null;

    // Cek apakah ada informasi kuantitas / unit di namePart
    // Misal: "SABUN 2 PCS" atau "2 X 3500" atau "5 KG"
    double qty = 1.0;
    String unit = 'pcs';
    int? unitPrice;

    final qtyPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(PCS|KG|G|GRAM|L|LTR|BTL|BUNGKUS|BKS|PACK|SACHET|SCH)\b', caseSensitive: false);
    final qtyMatch = qtyPattern.firstMatch(namePart);
    if (qtyMatch != null) {
      qty = double.tryParse(qtyMatch.group(1)!) ?? 1.0;
      unit = qtyMatch.group(2)!.toLowerCase();
      namePart = namePart.replaceRange(qtyMatch.start, qtyMatch.end, '').trim();
    } else {
      // Cek perkalian "2 X 12.000" atau "2 @"
      final multiPattern = RegExp(r'(\d+)\s*[xX@]\s*(\d+[\d\.]*)');
      final multiMatch = multiPattern.firstMatch(namePart);
      if (multiMatch != null) {
        qty = double.tryParse(multiMatch.group(1)!) ?? 1.0;
        final up = _normalizeRupiah(multiMatch.group(2)!);
        if (up != null && up > 0) unitPrice = up;
        namePart = namePart.replaceRange(multiMatch.start, multiMatch.end, '').trim();
      }
    }

    if (unitPrice == null && qty > 1) {
      unitPrice = (price / qty).round();
    } else {
      unitPrice ??= price;
    }

    return ReceiptDraftItem(
      id: _uuid.v4(),
      name: namePart,
      quantity: qty,
      unit: unit,
      unitPriceRp: unitPrice,
      lineTotalRp: price,
      needsReview: false,
    );
  }

  /// Ekstraksi nilai Rupiah dari baris atau baris berikutnya (jika angka ada di baris terpisah)
  int? _parseRupiahFromLine(String line, {List<String>? searchNextLines, int currentIndex = -1, bool allowZero = false}) {
    // 1. Coba ambil dari baris yang sama
    final inLine = _extractRupiahCandidates(line, allowZero: allowZero);
    if (inLine.isNotEmpty) {
      return inLine.last;
    }

    // 2. Jika tidak ada angka di baris ini, cek 1 baris tepat berikutnya (kasus label dan angka beda baris)
    if (searchNextLines != null && currentIndex >= 0 && currentIndex + 1 < searchNextLines.length) {
      final nextLine = searchNextLines[currentIndex + 1];
      final inNextLine = _extractRupiahCandidates(nextLine, allowZero: allowZero);
      if (inNextLine.isNotEmpty) {
        return inNextLine.first;
      }
    }

    return null;
  }

  List<int> _extractRupiahCandidates(String text, {bool allowZero = false}) {
    final results = <int>[];

    // Angka harus diawali digit [0-9] di batas kata (\b) atau setelah tanda Rp
    // Menghindari false positive pada huruf 'O' di kata seperti 'TOTAL'
    final pattern = RegExp(r'(?:(?:Rp\.?|RP\.?)\s*|\b)([0-9][0-9oO\.,]*[0-9oO]|[0-9])\b');
    final matches = pattern.allMatches(text);

    for (final m in matches) {
      final rawNum = m.group(1);
      if (rawNum != null) {
        final parsed = _normalizeRupiah(rawNum);
        if (parsed != null && (allowZero ? parsed >= 0 : parsed > 0)) {
          results.add(parsed);
        }
      }
    }

    return results;
  }

  /// Normalisasi string nominal ke integer IDR murni (PRD GAMINI.md Bagian 3.6.2 Butir 6)
  /// Contoh: "Rp 15.000" -> 15000, "15.O00" -> 15000, "15.000,00" -> 15000
  int? _normalizeRupiah(String raw) {
    var cleaned = raw.trim().toUpperCase();

    // Koreksi typo OCR huruf O / o menjadi angka 0
    cleaned = cleaned.replaceAll('O', '0');

    // Buang prefix Rp, simbol minus, spasi
    cleaned = cleaned.replaceAll(RegExp(r'[^\d\.\,]'), '');

    if (cleaned.isEmpty) return null;

    // Tangani desimal sen Indonesia (,00 di akhir) atau (.00 di akhir)
    if (cleaned.endsWith(',00') || cleaned.endsWith('.00')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }

    // Jika format standar Indonesia titik ribuan: 85.000 atau 1.250.000
    // Buang tanda pemisah ribuan
    if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      // Jika bagian terakhir 3 digit, itu adalah ribuan -> hapus semua titik
      if (parts.last.length == 3) {
        cleaned = cleaned.replaceAll('.', '');
      } else if (parts.last.length == 2) {
        // Desimal 2 digit (misal 85000.50) -> ambil integer
        cleaned = parts.sublist(0, parts.length - 1).join('');
      } else {
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    // Tangani sisa koma jika ada
    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.last.length == 3) {
        cleaned = cleaned.replaceAll(',', '');
      } else {
        cleaned = parts.first.replaceAll(',', '');
      }
    }

    return int.tryParse(cleaned);
  }
}

class _FinancialFigures {
  final int totalRp;
  final int? subtotalRp;
  final int? taxRp;
  final int? discountRp;
  final int? cashTenderedRp;
  final int? changeRp;
  final String? paymentMethod;

  const _FinancialFigures({
    required this.totalRp,
    this.subtotalRp,
    this.taxRp,
    this.discountRp,
    this.cashTenderedRp,
    this.changeRp,
    this.paymentMethod,
  });
}
