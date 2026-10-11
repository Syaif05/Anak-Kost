import 'dart:convert';
import '../../../../core/database/app_database.dart';

/// Metadata Sensitif Dokumen yang Dienkripsi AES-256-GCM Sebelum Ditulis ke DB (DOC03 & T13)
class DocumentMetadata {
  final String title;
  final String? documentNumber; // Nomor KTP, NIM/KTM, dll (rahasia)
  final String? notes;
  final List<String> tags;
  final String? expiryDate; // YYYY-MM-DD

  const DocumentMetadata({
    required this.title,
    this.documentNumber,
    this.notes,
    this.tags = const [],
    this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'document_number': documentNumber,
        'notes': notes,
        'tags': tags,
        'expiry_date': expiryDate,
      };

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) => DocumentMetadata(
        title: json['title'] as String? ?? 'Tanpa Judul',
        documentNumber: json['document_number'] as String?,
        notes: json['notes'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        expiryDate: json['expiry_date'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory DocumentMetadata.fromJsonString(String rawJson) =>
      DocumentMetadata.fromJson(jsonDecode(rawJson) as Map<String, dynamic>);
}

/// DTO Dokumen Brankas Terenkripsi Beserta Status Dekripsi dan Lampiran
class DocumentWithDetails {
  final Document document;
  final DocumentMetadata? decryptedMetadata; // Null jika brankas masih terkunci
  final List<Attachment> attachments;

  const DocumentWithDetails({
    required this.document,
    this.decryptedMetadata,
    this.attachments = const [],
  });

  bool get isDecrypted => decryptedMetadata != null;

  String get displayTitle => decryptedMetadata?.title ?? 'Dokumen Terproteksi';

  String get typeLabel {
    switch (document.documentType.toLowerCase()) {
      case 'ktp':
        return 'Kartu Tanda Penduduk (KTP)';
      case 'ktm':
        return 'Kartu Mahasiswa (KTM)';
      case 'internship_letter':
        return 'Surat Penerimaan Magang';
      case 'lease_contract':
        return 'Surat Kontrak Sewa Kost';
      case 'other':
      default:
        return 'Dokumen Penting';
    }
  }

  bool get isExpired {
    if (document.expiresOn == null) return false;
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    return nowStr.compareTo(document.expiresOn!) > 0;
  }
}
