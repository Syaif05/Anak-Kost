import 'dart:typed_data';
import '../models/ocr_models.dart';

/// Abstraksi Interface OCR (PRD GAMINI.md Bagian 3.6.3)
/// Menghubungkan Android (Google ML Kit Latin Bundled) dan macOS (Apple Vision)
/// dengan output kontrak OcrResult yang identik.
abstract class OcrService {
  /// Melakukan pengenalan teks dari berkas gambar lokal
  Future<OcrResult> recognizeTextFromPath(String imagePath);

  /// Melakukan pengenalan teks dari memori gambar (Uint8List bytes)
  Future<OcrResult> recognizeTextFromBytes(Uint8List bytes);

  /// Membersihkan resource atau menutup instance recognizer
  Future<void> dispose();
}
