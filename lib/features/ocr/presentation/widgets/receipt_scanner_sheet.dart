import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ocr_providers.dart';
import '../receipt_review_screen.dart';

/// Modal Bottom Sheet untuk Memilih Jalur Pemindaian Struk (Scanner ML Kit / Kamera / Galeri)
class ReceiptScannerSheet extends ConsumerStatefulWidget {
  const ReceiptScannerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ReceiptScannerSheet(),
    );
  }

  @override
  ConsumerState<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends ConsumerState<ReceiptScannerSheet> {
  bool _isProcessing = false;

  Future<void> _processImage(String imagePath) async {
    setState(() => _isProcessing = true);

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final parser = ref.read(receiptParserProvider);

      // 1. Eksekusi OCR Offline (Google ML Kit Latin v2)
      final ocrResult = await ocrService.recognizeTextFromPath(imagePath);

      // 2. Eksekusi Parser Struk Deterministik (Gate T11)
      final draft = parser.parse(ocrResult, imagePath: imagePath);

      if (mounted) {
        Navigator.pop(context); // Tutup bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptReviewScreen(
              initialDraft: draft,
              originalImagePath: imagePath,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Gagal mengenali struk: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scannerService = ref.read(documentScannerServiceProvider);

    if (_isProcessing) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Memindai & Mengenali Teks Struk...',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'OCR berjalan 100% offline di perangkat Anda (ML Kit Latin)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.document_scanner, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Pindai Struk Belanja',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih metode untuk mengambil struk. Draf pengeluaran akan dibuat otomatis untuk Anda periksa.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.document_scanner_outlined, color: theme.colorScheme.onPrimaryContainer),
              ),
              title: const Text('Document Scanner Pintar (ML Kit)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Deteksi tepi otomatis dan perataan sudut struk'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await scannerService.scanReceipt();
                if (result != null) {
                  await _processImage(result.imagePath);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_outlined, color: theme.colorScheme.onSecondaryContainer),
              ),
              title: const Text('Kamera Foto Langsung', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pengambilan foto standar dengan kompresi 82% & pembersihan EXIF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await scannerService.scanReceipt();
                if (result != null) {
                  await _processImage(result.imagePath);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library_outlined, color: theme.colorScheme.onTertiaryContainer),
              ),
              title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pilih foto struk yang sudah tersimpan di galeri ponsel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await scannerService.pickReceiptFromGallery();
                if (result != null) {
                  await _processImage(result.imagePath);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
