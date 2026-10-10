import 'package:intl/intl.dart';

/// Aturan penanganan mata uang IDR murni (Integer Rupiah)
/// Sesuai PRD GAMINI.md Asumsi A03 & Aturan Bisnis Uang (3.2)
/// Nominal disimpan sebagai integer rupiah tanpa pecahan, bukan floating point.
abstract class Money {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _numberOnlyFormat = NumberFormat.decimalPattern('id_ID');

  /// Memformat int rupiah menjadi format standar: "Rp15.000"
  static String format(int amountRp, {bool withSymbol = true, bool withSpace = false}) {
    if (withSymbol) {
      final formatted = _currencyFormat.format(amountRp);
      if (!withSpace) {
        // Hilangkan spasi jika format default mengandung spasi setelah "Rp"
        return formatted.replaceAll('Rp ', 'Rp');
      }
      return formatted;
    }
    return _numberOnlyFormat.format(amountRp);
  }

  /// Mem-parse string input pengguna (misal "15.000", "Rp 15.000", "15000") menjadi integer rupiah
  /// Mengabaikan karakter non-digit selain tanda minus untuk saldo koreksi
  static int parse(String raw) {
    if (raw.trim().isEmpty) return 0;
    
    // Normalisasi: buang "Rp", titik ribuan, spasi
    final cleaned = raw
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(' ', '')
        .trim();

    // Jika pengguna memasukkan koma desimal, potong bagian desimal karena IDR tidak memiliki pecahan
    final commaIndex = cleaned.indexOf(',');
    final integerPart = commaIndex != -1 ? cleaned.substring(0, commaIndex) : cleaned;

    return int.tryParse(integerPart) ?? 0;
  }

  /// Memvalidasi apakah nominal valid untuk transaksi standar (> 0)
  static bool isValidPositive(int amountRp) => amountRp > 0;
}
