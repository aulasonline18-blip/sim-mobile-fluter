import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int defaultMaxImageSide = 1280;
const int defaultJpegQuality = 78;

String compressImageDataUrl(
  String dataUrl, {
  int maxSide = defaultMaxImageSide,
  int jpegQuality = defaultJpegQuality,
}) {
  final trimmed = dataUrl.trim();
  final match = RegExp(
    r'^data:image/(png|jpeg|jpg|webp);base64,([A-Za-z0-9+/=]+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) return trimmed;

  try {
    final bytes = base64Decode(match.group(2)!);
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return trimmed;

    final largest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = largest > maxSide
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxSide : null,
            height: decoded.height > decoded.width ? maxSide : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;
    final jpg = img.encodeJpg(resized, quality: jpegQuality);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  } catch (_) {
    return trimmed;
  }
}
