import 'dart:typed_data';

/// How grey pixels become black or white dots.
enum Dithering {
  /// Darker than the threshold prints black. Best for logos and text.
  threshold,

  /// Floyd–Steinberg error diffusion. Best for photos.
  floydSteinberg,
}

/// A 1-bit image ready for `GS v 0`.
///
/// Build one from raw pixels so the library needs no image decoder: in
/// Flutter, `ui.Image.toByteData(format: ImageByteFormat.rawRgba)` gives
/// exactly what [RasterImage.fromRgba] expects; on a server, any decoder that
/// outputs RGBA works.
class RasterImage {
  RasterImage._(this.width, this.height, this.rows);

  /// Width in dots.
  final int width;

  /// Height in dots.
  final int height;

  /// [height] rows of [widthBytes] bytes; a set bit is a black dot.
  final Uint8List rows;

  /// Bytes per row.
  int get widthBytes => (width + 7) >> 3;

  /// From 8-bit RGBA pixels (4 bytes per pixel, row by row). Transparent
  /// pixels count as white. Images wider than [maxWidth] are scaled down,
  /// keeping the aspect ratio.
  factory RasterImage.fromRgba(
    List<int> rgba,
    int width,
    int height, {
    int? maxWidth,
    Dithering dithering = Dithering.threshold,
    int threshold = 128,
  }) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError.value(rgba.length, 'rgba', 'expected ${width * height * 4} bytes');
    }
    final luminance = Uint8List(width * height);
    for (var i = 0; i < luminance.length; i++) {
      final r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
      final a = rgba[i * 4 + 3];
      final grey = (r * 299 + g * 587 + b * 114) ~/ 1000;
      // Blend onto white paper.
      luminance[i] = (grey * a + 255 * (255 - a)) ~/ 255;
    }
    return RasterImage.fromLuminance(
      luminance,
      width,
      height,
      maxWidth: maxWidth,
      dithering: dithering,
      threshold: threshold,
    );
  }

  /// From 8-bit grey pixels, 0 black to 255 white, row by row.
  factory RasterImage.fromLuminance(
    List<int> luminance,
    int width,
    int height, {
    int? maxWidth,
    Dithering dithering = Dithering.threshold,
    int threshold = 128,
  }) {
    if (width < 1 || height < 1 || luminance.length != width * height) {
      throw ArgumentError('luminance must hold width * height values');
    }
    var pixels = luminance;
    var w = width, h = height;
    if (maxWidth != null && width > maxWidth) {
      final scaledHeight = (height * maxWidth / width).round().clamp(1, height);
      pixels = _downscale(luminance, width, height, maxWidth, scaledHeight);
      w = maxWidth;
      h = scaledHeight;
    }
    final bits = switch (dithering) {
      Dithering.threshold => _threshold(pixels, w, h, threshold),
      Dithering.floydSteinberg => _floydSteinberg(pixels, w, h, threshold),
    };
    return RasterImage._(w, h, bits);
  }

  /// Whether the dot at ([x], [y]) is black.
  bool isBlack(int x, int y) => rows[y * widthBytes + (x >> 3)] & (0x80 >> (x & 7)) != 0;
}

/// Box filter: each output pixel is the average of the source pixels it covers.
Uint8List _downscale(List<int> src, int w, int h, int newW, int newH) {
  final out = Uint8List(newW * newH);
  for (var y = 0; y < newH; y++) {
    final y0 = y * h ~/ newH;
    final y1 = ((y + 1) * h ~/ newH).clamp(y0 + 1, h);
    for (var x = 0; x < newW; x++) {
      final x0 = x * w ~/ newW;
      final x1 = ((x + 1) * w ~/ newW).clamp(x0 + 1, w);
      var sum = 0;
      for (var sy = y0; sy < y1; sy++) {
        for (var sx = x0; sx < x1; sx++) {
          sum += src[sy * w + sx];
        }
      }
      out[y * newW + x] = sum ~/ ((y1 - y0) * (x1 - x0));
    }
  }
  return out;
}

Uint8List _threshold(List<int> pixels, int w, int h, int threshold) {
  final widthBytes = (w + 7) >> 3;
  final out = Uint8List(widthBytes * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (pixels[y * w + x] < threshold) {
        out[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
  }
  return out;
}

Uint8List _floydSteinberg(List<int> pixels, int w, int h, int threshold) {
  final widthBytes = (w + 7) >> 3;
  final out = Uint8List(widthBytes * h);
  final work = Int32List.fromList(pixels);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final old = work[i];
      final black = old < threshold;
      if (black) out[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
      final error = old - (black ? 0 : 255);
      if (x + 1 < w) work[i + 1] += error * 7 ~/ 16;
      if (y + 1 < h) {
        if (x > 0) work[i + w - 1] += error * 3 ~/ 16;
        work[i + w] += error * 5 ~/ 16;
        if (x + 1 < w) work[i + w + 1] += error ~/ 16;
      }
    }
  }
  return out;
}
