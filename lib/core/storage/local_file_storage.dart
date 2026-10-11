import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Pengelola Penyimpanan Berkas Privat Klien Android (Ciphertext Sandbox)
/// Sesuai PRD GAMINI.md Bagian 3.6.4 & Bagian 7.6
class LocalFileStorage {
  final Directory? customBaseDir;

  LocalFileStorage({this.customBaseDir});

  static const String mediaSubdir = 'secure_media';
  static const String thumbnailSubdir = 'secure_thumbnails';

  /// Mendapatkan direktori privat untuk berkas media terenkripsi
  Future<Directory> getMediaDirectory() async {
    final docsDir = customBaseDir ?? await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, mediaSubdir));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Mendapatkan direktori privat untuk thumbnail terenkripsi
  Future<Directory> getThumbnailDirectory() async {
    final docsDir = customBaseDir ?? await getApplicationDocumentsDirectory();
    final thumbDir = Directory(p.join(docsDir.path, thumbnailSubdir));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  /// Menyimpan berkas ciphertext ke direktori privat
  Future<String> saveCiphertext({
    required String fileId,
    required Uint8List ciphertextBytes,
    bool isThumbnail = false,
  }) async {
    final dir = isThumbnail ? await getThumbnailDirectory() : await getMediaDirectory();
    final filePath = p.join(dir.path, '$fileId.enc');
    final file = File(filePath);
    await file.writeAsBytes(ciphertextBytes, flush: true);
    return filePath;
  }

  /// Membaca berkas ciphertext dari direktori privat
  Future<Uint8List?> readCiphertext(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  /// Menghapus berkas privat
  Future<bool> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
