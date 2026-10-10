/// Kontrak Operasi Sinkronisasi & OCR
/// Sesuai PRD GAMINI.md Bagian 7.5.2 & Bagian 3.6.2
/// Berbagi format struktur data yang sama persis dengan client macOS.
library;

/// Kontrak Payload Operasi Outbox ke Supabase RPC `apply_operation`
class SyncOperationPayload {
  final int schemaVersion;
  final String operationId;
  final String deviceId;
  final int deviceGeneration;
  final int datasetGeneration;
  final String aggregateType;
  final String aggregateId;
  final Map<String, int> baseVersions;
  final List<Map<String, dynamic>> commands;

  const SyncOperationPayload({
    this.schemaVersion = 1,
    required this.operationId,
    required this.deviceId,
    required this.deviceGeneration,
    required this.datasetGeneration,
    required this.aggregateType,
    required this.aggregateId,
    required this.baseVersions,
    required this.commands,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'operation_id': operationId,
        'device_id': deviceId,
        'device_generation': deviceGeneration,
        'dataset_generation': datasetGeneration,
        'aggregate_type': aggregateType,
        'aggregate_id': aggregateId,
        'base_versions': baseVersions,
        'commands': commands,
      };

  factory SyncOperationPayload.fromJson(Map<String, dynamic> json) =>
      SyncOperationPayload(
        schemaVersion: json['schema_version'] as int? ?? 1,
        operationId: json['operation_id'] as String,
        deviceId: json['device_id'] as String,
        deviceGeneration: json['device_generation'] as int,
        datasetGeneration: json['dataset_generation'] as int,
        aggregateType: json['aggregate_type'] as String,
        aggregateId: json['aggregate_id'] as String,
        baseVersions: (json['base_versions'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ??
            {},
        commands: (json['commands'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );
}

/// Kontrak hasil mentah ekstraksi OCR per baris (dinormalisasi antara ML Kit & Apple Vision)
class OcrRawLine {
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double? nativeConfidence;

  const OcrRawLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.nativeConfidence,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        if (nativeConfidence != null) 'confidence': nativeConfidence,
      };
}

/// Kontrak item struk hasil deteksi OCR
class OcrDraftItem {
  final String name;
  final String quantity;
  final String unit;
  final int? unitPriceRp;
  final int? lineTotalRp;
  final bool needsReview;

  const OcrDraftItem({
    required this.name,
    this.quantity = '1',
    this.unit = 'pcs',
    this.unitPriceRp,
    this.lineTotalRp,
    this.needsReview = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'unit_price_rp': unitPriceRp,
        'line_total_rp': lineTotalRp,
        'needs_review': needsReview,
      };
}

/// Kontrak Draf Hasil Parse Struk (Wajib ditinjau pengguna sebelum simpan keuangan)
class ReceiptDraft {
  final int schemaVersion;
  final String draftId;
  final String? merchantCandidate;
  final String? localDateCandidate; // YYYY-MM-DD
  final int? totalRpCandidate;
  final String parserConfidence; // 'high' | 'medium' | 'low'
  final List<String> warnings;
  final List<OcrDraftItem> items;
  final bool confirmed;

  const ReceiptDraft({
    this.schemaVersion = 1,
    required this.draftId,
    this.merchantCandidate,
    this.localDateCandidate,
    this.totalRpCandidate,
    this.parserConfidence = 'medium',
    this.warnings = const [],
    this.items = const [],
    this.confirmed = false,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'draft_id': draftId,
        'merchant_candidate': merchantCandidate,
        'local_date_candidate': localDateCandidate,
        'total_rp_candidate': totalRpCandidate,
        'parser_confidence': parserConfidence,
        'warnings': warnings,
        'items': items.map((e) => e.toJson()).toList(),
        'confirmed': confirmed,
      };
}
