import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';

/// Status Pembayaran Tagihan Dihitung Dinamis (PRD Bagian 6.5 & Test T03)
enum BillStatus {
  unpaid('Belum Dibayar'),
  partial('Sebagian'),
  paid('Lunas'),
  overdue('Terlambat');

  final String label;
  const BillStatus(this.label);
}

/// DTO Kejadian Tagihan Lengkap beserta Riwayat Pembayaran & Status Dinamis
class BillOccurrenceWithStatus {
  final BillTemplate template;
  final BillOccurrence occurrence;
  final List<BillPayment> payments;

  const BillOccurrenceWithStatus({
    required this.template,
    required this.occurrence,
    this.payments = const [],
  });

  /// Total pembayaran sah yang telah dilakukan
  int get totalPaidRp => payments.fold(0, (sum, p) => sum + p.amountRp);

  /// Nominal tagihan efektif (prioritas: occurrence.amountDueRp -> template.estimatedAmountRp -> 0)
  int get effectiveAmountDueRp =>
      occurrence.amountDueRp ?? template.estimatedAmountRp ?? 0;

  /// Sisa tagihan yang harus dibayar (tidak boleh negatif)
  int get remainingRp {
    final diff = effectiveAmountDueRp - totalPaidRp;
    return diff > 0 ? diff : 0;
  }

  /// Status dihitung dinamis sesuai aturan PRD (Gate Test T03)
  BillStatus calculateStatus([DateTime? asOfDate]) {
    // 1. Jika lunas (sisa nol dan sudah ada pembayaran atau nominal nol)
    if (effectiveAmountDueRp > 0 && remainingRp == 0) {
      return BillStatus.paid;
    }

    // 2. Jika sudah ada pembayaran sebagian
    if (totalPaidRp > 0 && remainingRp > 0) {
      return BillStatus.partial;
    }

    // 3. Jika terlambat (lewat tanggal jatuh tempo dan masih ada sisa)
    final refDate = asOfDate ?? DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(refDate);
    if (todayStr.compareTo(occurrence.dueDate) > 0 && remainingRp > 0) {
      return BillStatus.overdue;
    }

    // 4. Belum ada pembayaran sama sekali
    return BillStatus.unpaid;
  }

  BillStatus get status => calculateStatus();

  bool get isPaid => status == BillStatus.paid;
  bool get isOverdue => status == BillStatus.overdue;
  bool get isPartial => status == BillStatus.partial;
}

/// Engine Recurrence & Evaluasi Anchor Tagihan Kost (Gate Test T09)
class BillRecurrenceEngine {
  /// Menghitung tanggal jatuh tempo untuk bulan tertentu dengan aturan Anchor 31
  /// Sesuai PRD GAMINI.md Bagian 3.5 & Test T09:
  /// Anchor 31 pada bulan pendek memakai hari terakhir bulan tersebut,
  /// dan kembali ke 31 pada bulan berikutnya yang mendukung (misal: Jan 31 -> Feb 28 -> Mar 31).
  static DateTime computeDueDateForMonth({
    required String anchorDateStr, // "YYYY-MM-DD" e.g. "2026-01-31"
    required int targetYear,
    required int targetMonth,
  }) {
    final anchorParts = anchorDateStr.split('-');
    final anchorDay = int.parse(anchorParts[2]);

    // Hari terakhir dalam targetMonth dihitung dengan mengambil hari ke-0 dari bulan berikutnya
    final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;

    // Clamp anchorDay ke hari maksimal bulan tersebut
    final clampedDay = anchorDay > daysInTargetMonth ? daysInTargetMonth : anchorDay;
    return DateTime(targetYear, targetMonth, clampedDay);
  }

  /// Menghasilkan period key deterministik unik tanpa duplikasi: "YYYY-MM"
  static String formatPeriodKey(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  /// Menghasilkan tanggal jatuh tempo string: "YYYY-MM-DD"
  static String formatDueDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
