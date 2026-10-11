import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/ocr_models.dart';
import '../domain/services/ocr_service.dart';

/// Implementasi Offline ML Kit Text Recognition v2 untuk Android (PRD GAMINI.md Bagian 3.6.3)
/// Menggunakan model Latin yang dibundel di dalam aplikasi untuk kepastian mode offline.
class MlKitOcrService implements OcrService {
  final TextRecognizer _recognizer;

  MlKitOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrResult> recognizeTextFromPath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final blocks = <OcrTextBlock>[];
    final allLines = <OcrTextLine>[];
    int lineIndex = 0;

    for (final block in recognizedText.blocks) {
      final blockLines = <OcrTextLine>[];
      for (final line in block.lines) {
        final ocrLine = OcrTextLine(
          text: line.text,
          lineIndex: lineIndex++,
          box: OcrNormalizedBox(
            x: line.boundingBox.left.toDouble(),
            y: line.boundingBox.top.toDouble(),
            width: line.boundingBox.width.toDouble(),
            height: line.boundingBox.height.toDouble(),
          ),
        );
        blockLines.add(ocrLine);
        allLines.add(ocrLine);
      }

      blocks.add(OcrTextBlock(
        text: block.text,
        lines: blockLines,
        box: OcrNormalizedBox(
          x: block.boundingBox.left.toDouble(),
          y: block.boundingBox.top.toDouble(),
          width: block.boundingBox.width.toDouble(),
          height: block.boundingBox.height.toDouble(),
        ),
      ));
    }

    return OcrResult(
      rawText: recognizedText.text,
      lines: allLines,
      blocks: blocks,
      engine: 'mlkit_latin',
    );
  }

  @override
  Future<OcrResult> recognizeTextFromBytes(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, 'ocr_input_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await tempFile.writeAsBytes(bytes, flush: true);

    try {
      return await recognizeTextFromPath(tempFile.path);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
