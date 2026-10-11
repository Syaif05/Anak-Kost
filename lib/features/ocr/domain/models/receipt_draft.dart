import 'dart:convert';

/// Tingkat Keyakinan Hasil Parser (PRD GAMINI.md Bagian 3.6.2 Butir 7)
enum ParserConfidence {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case ParserConfidence.high:
        return 'Tinggi';
      case ParserConfidence.medium:
        return 'Sedang';
      case ParserConfidence.low:
        return 'Rendah (Perlu Periksa)';
    }
  }
}

/// Item Belanja pada Draf Struk
class ReceiptDraftItem {
  final String id;
  final String name;
  final double quantity;
  final String unit; // 'pcs', 'pack', 'kg', 'g', 'L', dll
  final int? unitPriceRp;
  final int lineTotalRp;
  final bool needsReview;
  final String? matchedInventoryItemId; // ID barang inventaris yang cocok

  const ReceiptDraftItem({
    required this.id,
    required this.name,
    this.quantity = 1.0,
    this.unit = 'pcs',
    this.unitPriceRp,
    required this.lineTotalRp,
    this.needsReview = false,
    this.matchedInventoryItemId,
  });

  ReceiptDraftItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    int? unitPriceRp,
    int? lineTotalRp,
    bool? needsReview,
    String? matchedInventoryItemId,
  }) {
    return ReceiptDraftItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPriceRp: unitPriceRp ?? this.unitPriceRp,
      lineTotalRp: lineTotalRp ?? this.lineTotalRp,
      needsReview: needsReview ?? this.needsReview,
      matchedInventoryItemId: matchedInventoryItemId ?? this.matchedInventoryItemId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity.toString(),
        'unit': unit,
        'unit_price_rp': unitPriceRp,
        'line_total_rp': lineTotalRp,
        'needs_review': needsReview,
        'matched_inventory_item_id': matchedInventoryItemId,
      };

  factory ReceiptDraftItem.fromJson(Map<String, dynamic> json) => ReceiptDraftItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Barang',
        quantity: double.tryParse(json['quantity']?.toString() ?? '1.0') ?? 1.0,
        unit: json['unit'] as String? ?? 'pcs',
        unitPriceRp: (json['unit_price_rp'] as num?)?.toInt(),
        lineTotalRp: (json['line_total_rp'] as num?)?.toInt() ?? 0,
        needsReview: json['needs_review'] as bool? ?? false,
        matchedInventoryItemId: json['matched_inventory_item_id'] as String?,
      );
}

/// Draf Hasil Parsing Struk (PRD GAMINI.md Bagian 3.6.2)
/// Sesuai aturan mutlak: Draf ini TIDAK memengaruhi saldo/stok sebelum pengguna mengonfirmasi (save_without_user_review: forbidden).
class ReceiptDraft {
  final int schemaVersion;
  final String draftId;
  final String? merchantCandidate;
  final String? localDateCandidate; // YYYY-MM-DD
  final int totalRpCandidate;
  final int? subtotalRp;
  final int? taxRp;
  final int? discountRp;
  final int? cashTenderedRp; // Uang tunai yang diserahkan
  final int? changeRp; // Uang kembalian
  final String? paymentMethod; // 'cash', 'qris', 'debit', 'unknown'
  final ParserConfidence parserConfidence;
  final List<String> warnings;
  final List<ReceiptDraftItem> items;
  final bool confirmed;
  final String? imagePath; // Path berkas gambar asli

  const ReceiptDraft({
    this.schemaVersion = 1,
    required this.draftId,
    this.merchantCandidate,
    this.localDateCandidate,
    required this.totalRpCandidate,
    this.subtotalRp,
    this.taxRp,
    this.discountRp,
    this.cashTenderedRp,
    this.changeRp,
    this.paymentMethod,
    this.parserConfidence = ParserConfidence.medium,
    this.warnings = const [],
    this.items = const [],
    this.confirmed = false,
    this.imagePath,
  });

  ReceiptDraft copyWith({
    String? merchantCandidate,
    String? localDateCandidate,
    int? totalRpCandidate,
    int? subtotalRp,
    int? taxRp,
    int? discountRp,
    int? cashTenderedRp,
    int? changeRp,
    String? paymentMethod,
    ParserConfidence? parserConfidence,
    List<String>? warnings,
    List<ReceiptDraftItem>? items,
    bool? confirmed,
    String? imagePath,
  }) {
    return ReceiptDraft(
      schemaVersion: schemaVersion,
      draftId: draftId,
      merchantCandidate: merchantCandidate ?? this.merchantCandidate,
      localDateCandidate: localDateCandidate ?? this.localDateCandidate,
      totalRpCandidate: totalRpCandidate ?? this.totalRpCandidate,
      subtotalRp: subtotalRp ?? this.subtotalRp,
      taxRp: taxRp ?? this.taxRp,
      discountRp: discountRp ?? this.discountRp,
      cashTenderedRp: cashTenderedRp ?? this.cashTenderedRp,
      changeRp: changeRp ?? this.changeRp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      parserConfidence: parserConfidence ?? this.parserConfidence,
      warnings: warnings ?? this.warnings,
      items: items ?? this.items,
      confirmed: confirmed ?? this.confirmed,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'draft_id': draftId,
        'merchant_candidate': merchantCandidate,
        'local_date_candidate': localDateCandidate,
        'total_rp_candidate': totalRpCandidate,
        'subtotal_rp': subtotalRp,
        'tax_rp': taxRp,
        'discount_rp': discountRp,
        'cash_tendered_rp': cashTenderedRp,
        'change_rp': changeRp,
        'payment_method': paymentMethod,
        'parser_confidence': parserConfidence.name,
        'warnings': warnings,
        'items': items.map((e) => e.toJson()).toList(),
        'confirmed': confirmed,
        'image_path': imagePath,
      };

  factory ReceiptDraft.fromJson(Map<String, dynamic> json) => ReceiptDraft(
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
        draftId: json['draft_id'] as String,
        merchantCandidate: json['merchant_candidate'] as String?,
        localDateCandidate: json['local_date_candidate'] as String?,
        totalRpCandidate: (json['total_rp_candidate'] as num?)?.toInt() ?? 0,
        subtotalRp: (json['subtotal_rp'] as num?)?.toInt(),
        taxRp: (json['tax_rp'] as num?)?.toInt(),
        discountRp: (json['discount_rp'] as num?)?.toInt(),
        cashTenderedRp: (json['cash_tendered_rp'] as num?)?.toInt(),
        changeRp: (json['change_rp'] as num?)?.toInt(),
        paymentMethod: json['payment_method'] as String?,
        parserConfidence: ParserConfidence.values.firstWhere(
          (e) => e.name == json['parser_confidence'],
          orElse: () => ParserConfidence.medium,
        ),
        warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => ReceiptDraftItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        confirmed: json['confirmed'] as bool? ?? false,
        imagePath: json['image_path'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
}
