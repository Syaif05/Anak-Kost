/// Koordinat Bounding Box Ternormalisasi 0.0 - 1.0 (Top-Left origin)
/// Sesuai PRD GAMINI.md Bagian 3.6.3: Identik antara Android (ML Kit) dan macOS (Apple Vision)
class OcrNormalizedBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const OcrNormalizedBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory OcrNormalizedBox.fromJson(Map<String, dynamic> json) => OcrNormalizedBox(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

/// Baris Teks Hasil OCR
class OcrTextLine {
  final String text;
  final OcrNormalizedBox? box;
  final double? confidence;
  final int lineIndex;

  const OcrTextLine({
    required this.text,
    this.box,
    this.confidence,
    this.lineIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'box': box?.toJson(),
        'confidence': confidence,
        'line_index': lineIndex,
      };

  factory OcrTextLine.fromJson(Map<String, dynamic> json) => OcrTextLine(
        text: json['text'] as String,
        box: json['box'] != null ? OcrNormalizedBox.fromJson(json['box'] as Map<String, dynamic>) : null,
        confidence: (json['confidence'] as num?)?.toDouble(),
        lineIndex: (json['line_index'] as num?)?.toInt() ?? 0,
      );
}

/// Blok Paragraf/Area Hasil OCR
class OcrTextBlock {
  final String text;
  final List<OcrTextLine> lines;
  final OcrNormalizedBox? box;

  const OcrTextBlock({
    required this.text,
    required this.lines,
    this.box,
  });
}

/// Hasil Lengkap Pengenalan Teks OCR
class OcrResult {
  final String rawText;
  final List<OcrTextLine> lines;
  final List<OcrTextBlock> blocks;
  final String engine; // 'mlkit_latin' atau 'apple_vision'
  final int imageWidth;
  final int imageHeight;

  const OcrResult({
    required this.rawText,
    required this.lines,
    this.blocks = const [],
    required this.engine,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  /// Factory helper untuk membuat OcrResult dari teks mentah (misal untuk testing)
  factory OcrResult.fromRawLines(List<String> rawLines, {String engine = 'test_mock'}) {
    final lines = <OcrTextLine>[];
    for (int i = 0; i < rawLines.length; i++) {
      lines.add(OcrTextLine(
        text: rawLines[i],
        lineIndex: i,
        confidence: 0.95,
      ));
    }
    return OcrResult(
      rawText: rawLines.join('\n'),
      lines: lines,
      engine: engine,
    );
  }
}
