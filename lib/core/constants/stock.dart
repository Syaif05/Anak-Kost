import 'package:intl/intl.dart';

/// Aturan penanganan kuantitas stok desimal tetap (Fixed Precision Milli-Units)
/// Sesuai PRD GAMINI.md Asumsi A11, Bagian 3.3 & Bagian 6.1
/// SQLite menyimpan integer milli-unit (1.250 unit disimpan sebagai 1250).
/// Server PostgreSQL menyimpan numeric(14,3).
/// Dilarang menggunakan tipe double/floating-point untuk komputasi stok atau mutasi.
abstract class Stock {
  static const int milliFactor = 1000;

  static final NumberFormat _decimalFormat = NumberFormat('#,##0.###', 'id_ID');

  /// Mengonversi desimal float/string (misal 1.25 atau "1.25") ke milli-unit int64 (1250)
  static int toMilliUnit(num quantity) {
    return (quantity * milliFactor).round();
  }

  /// Mengonversi string input (misal "1,25" atau "1.25" atau "5") ke milli-unit integer (1250 / 5000)
  static int parseToMilliUnit(String raw) {
    if (raw.trim().isEmpty) return 0;
    final trimmed = raw.trim();

    // Jika ada koma, koma adalah pemisah desimal (standar Indonesia)
    if (trimmed.contains(',')) {
      final cleaned = trimmed.replaceAll('.', '').replaceAll(',', '.');
      final value = double.tryParse(cleaned);
      return value == null ? 0 : (value * milliFactor).round();
    }

    // Jika mengandung titik
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length == 2 && parts[1].length != 3) {
        // Desimal eksplisit non-3-digit (misal "1.25", "0.5")
        final value = double.tryParse(trimmed);
        return value == null ? 0 : (value * milliFactor).round();
      } else {
        // Pemisah ribuan Indonesia (misal "1.000" atau "5.000")
        final cleaned = trimmed.replaceAll('.', '');
        final value = double.tryParse(cleaned);
        return value == null ? 0 : (value * milliFactor).round();
      }
    }

    final value = double.tryParse(trimmed);
    return value == null ? 0 : (value * milliFactor).round();
  }

  /// Mengonversi milli-unit (1250) kembali ke nilai desimal untuk kalkulasi harga satuan
  static double toDecimal(int milliUnits) {
    return milliUnits / milliFactor;
  }

  /// Memformat milli-unit (1250) ke tampilan string yang rapi ("1,25")
  static String format(int milliUnits, {String? unit}) {
    final decimalValue = milliUnits / milliFactor;
    final formatted = _decimalFormat.format(decimalValue);
    if (unit != null && unit.isNotEmpty) {
      return '$formatted $unit';
    }
    return formatted;
  }
}
