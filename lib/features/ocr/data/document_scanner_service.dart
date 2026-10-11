import 'dart:io';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../../../core/media/image_pipeline_service.dart';

/// Hasil Pemindaian Struk / Dokumen
class ScanReceiptResult {
  final String imagePath;
  final bool usedMlKitScanner;

  const ScanReceiptResult({
    required this.imagePath,
    this.usedMlKitScanner = false,
  });
}

/// Service Pemindaian Dokumen Struk Android (PRD GAMINI.md Bagian 3.6.3 & Bagian 10.6)
/// Memanfaatkan Google ML Kit Document Scanner untuk deteksi tepi otomatis,
/// dengan fallback transparan ke Kamera perangkat jika Google Play Services Scanner belum siap offline.
class DocumentScannerService {
  final ImagePipelineService _imagePipeline;

  DocumentScannerService({ImagePipelineService? imagePipeline})
      : _imagePipeline = imagePipeline ?? ImagePipelineService();

  /// Memindai struk belanja dengan Document Scanner atau Fallback Kamera
  Future<ScanReceiptResult?> scanReceipt() async {
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.jpeg},
          mode: ScannerMode.filter,
          pageLimit: 1,
          isGalleryImport: true,
        ),
      );

      final result = await documentScanner.scanDocument();
      await documentScanner.close();

      final images = result.images;
      if (images != null && images.isNotEmpty) {
        return ScanReceiptResult(
          imagePath: images.first,
          usedMlKitScanner: true,
        );
      }
    } catch (_) {
      // Fallback anggun: Jika Play Services Document Scanner belum terunduh / offline
    }

    // Fallback ke Kamera perangkat dengan Photo Pipeline
    final fallbackMedia = await _imagePipeline.captureImageFromCamera();
    if (fallbackMedia == null) return null;

    final tempDir = Directory.systemTemp.createTempSync('receipt_fallback_');
    final filePath = '${tempDir.path}/${fallbackMedia.fileName}';
    final file = File(filePath);
    await file.writeAsBytes(fallbackMedia.bytes, flush: true);

    return ScanReceiptResult(
      imagePath: filePath,
      usedMlKitScanner: false,
    );
  }

  /// Memilih foto struk yang sudah ada dari galeri (Photo Picker)
  Future<ScanReceiptResult?> pickReceiptFromGallery() async {
    final media = await _imagePipeline.pickImageFromGallery();
    if (media == null) return null;

    final tempDir = Directory.systemTemp.createTempSync('receipt_gallery_');
    final filePath = '${tempDir.path}/${media.fileName}';
    final file = File(filePath);
    await file.writeAsBytes(media.bytes, flush: true);

    return ScanReceiptResult(
      imagePath: filePath,
      usedMlKitScanner: false,
    );
  }
}
