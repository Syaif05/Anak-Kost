import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/document_scanner_service.dart';
import '../../data/mlkit_ocr_service.dart';
import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';

/// Provider singleton untuk OcrService (ML Kit Latin offline engine)
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider singleton untuk DeterministicReceiptParser
final receiptParserProvider = Provider<DeterministicReceiptParser>((ref) {
  return DeterministicReceiptParser();
});

/// Provider singleton untuk DocumentScannerService
final documentScannerServiceProvider = Provider<DocumentScannerService>((ref) {
  final imagePipeline = ref.watch(imagePipelineServiceProvider);
  return DocumentScannerService(imagePipeline: imagePipeline);
});
