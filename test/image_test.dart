import 'package:escpos_kit/escpos_kit.dart';
import 'package:test/test.dart';

void main() {
  group('threshold', () {
    test('packs dots most significant bit first', () {
      final image = RasterImage.fromLuminance([for (var i = 0; i < 10; i++) i.isEven ? 0 : 255], 10, 1);
      expect(image.widthBytes, 2);
      expect(image.rows, [0xAA, 0x80]);
      expect(image.isBlack(0, 0), isTrue);
      expect(image.isBlack(1, 0), isFalse);
      expect(image.isBlack(8, 0), isTrue);
    });

    test('custom threshold', () {
      final grey = [100, 200];
      expect(RasterImage.fromLuminance(grey, 2, 1).rows, [0x80]);
      expect(RasterImage.fromLuminance(grey, 2, 1, threshold: 220).rows, [0xC0]);
    });
  });

  group('RGBA', () {
    test('opaque black prints, transparent pixels are paper', () {
      final rgba = [0, 0, 0, 255, 0, 0, 0, 0];
      expect(RasterImage.fromRgba(rgba, 2, 1).rows, [0x80]);
    });

    test('rejects a buffer of the wrong size', () {
      expect(() => RasterImage.fromRgba([0, 0, 0], 1, 1), throwsArgumentError);
    });
  });

  group('scaling', () {
    test('wide images shrink to maxWidth and keep their aspect ratio', () {
      final image = RasterImage.fromLuminance(List.filled(8 * 4, 0), 8, 4, maxWidth: 4);
      expect(image.width, 4);
      expect(image.height, 2);
      expect(image.rows, [0xF0, 0xF0]);
    });

    test('averages the pixels it merges', () {
      // Black and white columns average to grey 127, which is below 128.
      final image = RasterImage.fromLuminance([0, 255, 0, 255], 4, 1, maxWidth: 2);
      expect(image.rows, [0xC0]);
    });

    test('narrow images are left alone', () {
      final image = RasterImage.fromLuminance(List.filled(4, 0), 4, 1, maxWidth: 384);
      expect(image.width, 4);
    });
  });

  group('Floyd-Steinberg', () {
    test('mid grey becomes about half black', () {
      const size = 16;
      final image = RasterImage.fromLuminance(
        List.filled(size * size, 128),
        size,
        size,
        dithering: Dithering.floydSteinberg,
      );
      var black = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (image.isBlack(x, y)) black++;
        }
      }
      expect(black, inInclusiveRange(size * size * 0.4, size * size * 0.6));
    });

    test('pure black and white stay pure', () {
      final white = RasterImage.fromLuminance(List.filled(16, 255), 4, 4, dithering: Dithering.floydSteinberg);
      final black = RasterImage.fromLuminance(List.filled(16, 0), 4, 4, dithering: Dithering.floydSteinberg);
      expect(white.rows, everyElement(0));
      expect(black.rows, everyElement(0xF0));
    });
  });
}
