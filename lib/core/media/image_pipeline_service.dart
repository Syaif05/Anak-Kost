import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Hasil Pengambilan Media Foto/Gambar
class PickedMediaResult {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int byteSize;

  const PickedMediaResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  String get formattedSize {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Service Pipeline Pengambilan & Pemrosesan Gambar (PRD FASE 4 & 5)
/// Mematuhi standar:
/// 1. Modern Android Photo Picker (tanpa izin READ_EXTERNAL_STORAGE usang)
/// 2. Kompresi JPEG kualitas 80–85 (default 82)
/// 3. Penghapusan metadata lokasi GPS (requestFullMetadata: false) untuk menjaga privasi
class ImagePipelineService {
  final ImagePicker _picker;

  ImagePipelineService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Mengambil foto/struk/dokumen dari Galeri menggunakan Android Photo Picker
  Future<PickedMediaResult?> pickImageFromGallery({
    int quality = 82,
    double? maxWidth = 1920,
    double? maxHeight = 1920,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      requestFullMetadata: false, // Menghapus tag privasi EXIF GPS
    );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return PickedMediaResult(
      bytes: bytes,
      fileName: file.name,
      mimeType: file.mimeType ?? 'image/jpeg',
      byteSize: bytes.length,
    );
  }

  /// Mengambil foto struk / barang langsung dari Kamera perangkat
  Future<PickedMediaResult?> captureImageFromCamera({
    int quality = 82,
    double? maxWidth = 1920,
    double? maxHeight = 1920,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      requestFullMetadata: false, // Menghapus tag privasi EXIF GPS
    );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return PickedMediaResult(
      bytes: bytes,
      fileName: file.name,
      mimeType: file.mimeType ?? 'image/jpeg',
      byteSize: bytes.length,
    );
  }
}
