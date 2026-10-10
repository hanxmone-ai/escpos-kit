import 'dart:typed_data';

import 'package:escpos_kit/commands.dart';
import 'package:test/test.dart';

void main() {
  group('basic commands', () {
    test('initialize', () => expect(initialize(), [0x1B, 0x40]));
    test('line feed', () => expect(lineFeed(), [0x0A]));
    test('feed lines', () => expect(feedLines(3), [0x1B, 0x64, 3]));
    test('feed lines rejects values outside a byte', () {
      expect(() => feedLines(256), throwsRangeError);
      expect(() => feedLines(-1), throwsRangeError);
    });
    test('align', () {
      expect(align(PosAlign.left), [0x1B, 0x61, 0]);
      expect(align(PosAlign.center), [0x1B, 0x61, 1]);
      expect(align(PosAlign.right), [0x1B, 0x61, 2]);
    });
    test('bold', () {
      expect(bold(true), [0x1B, 0x45, 1]);
      expect(bold(false), [0x1B, 0x45, 0]);
    });
    test('underline', () {
      expect(underline(Underline.single), [0x1B, 0x2D, 1]);
      expect(underline(Underline.thick), [0x1B, 0x2D, 2]);
    });
    test('reverse', () => expect(reverse(true), [0x1D, 0x42, 1]));
    test('font', () => expect(font(Font.b), [0x1B, 0x4D, 1]));
    test('code page', () => expect(codePage(16), [0x1B, 0x74, 16]));
    test('Chinese mode', () {
      expect(kanjiOn(), [0x1C, 0x26]);
      expect(kanjiOff(), [0x1C, 0x2E]);
    });
  });

  group('text size', () {
    test('packs width and height into one byte', () {
      expect(TextSize.normal.value, 0x00);
      expect(TextSize.large.value, 0x11);
      expect(TextSize.doubleHeight.value, 0x01);
      expect(TextSize.doubleWidth.value, 0x10);
      expect(const TextSize(2, 3).value, 0x12);
      expect(const TextSize(8, 8).value, 0x77);
    });
    test('command', () => expect(textSize(TextSize.large), [0x1D, 0x21, 0x11]));
    test('equality', () => expect(const TextSize(2, 2), TextSize.large));
  });

  group('cut and drawer', () {
    test('partial cut by default', () => expect(cut(), [0x1D, 0x56, 66, 0]));
    test('full cut after feeding', () {
      expect(cut(mode: Cut.full, feedDots: 10), [0x1D, 0x56, 65, 10]);
    });
    test('drawer pulse on pin 2', () {
      expect(openDrawer(), [0x1B, 0x70, 0, 50, 50]);
    });
    test('drawer pulse on pin 5', () {
      expect(openDrawer(pin: 5, onMs: 50, offMs: 500), [0x1B, 0x70, 1, 25, 250]);
    });
    test('drawer rejects other pins', () {
      expect(() => openDrawer(pin: 3), throwsArgumentError);
    });
  });

  group('barcode', () {
    test('EAN-13', () {
      expect(barcode(BarcodeType.ean13, '590123412345'), [
        0x1D, 0x68, 80, //
        0x1D, 0x77, 2, //
        0x1D, 0x48, 2, //
        0x1D, 0x6B, 67, 12, ...'590123412345'.codeUnits,
      ]);
    });
    test('CODE128 uses code set B', () {
      final bytes = barcode(
        BarcodeType.code128,
        'AB-12',
        height: 60,
        moduleWidth: 3,
        text: BarcodeText.none,
      );
      expect(bytes, [
        0x1D, 0x68, 60, //
        0x1D, 0x77, 3, //
        0x1D, 0x48, 0, //
        0x1D, 0x6B, 73, 7, ...'{BAB-12'.codeUnits,
      ]);
    });
    test('rejects data the symbology cannot hold', () {
      expect(() => barcode(BarcodeType.ean13, 'abc'), throwsArgumentError);
      expect(() => barcode(BarcodeType.ean13, '123'), throwsArgumentError);
      expect(() => barcode(BarcodeType.ean8, '1234567'), returnsNormally);
      expect(() => barcode(BarcodeType.itf, '123'), throwsArgumentError);
      expect(() => barcode(BarcodeType.code39, 'abc'), throwsArgumentError);
      expect(() => barcode(BarcodeType.code39, 'ABC-1'), returnsNormally);
      expect(() => barcode(BarcodeType.code128, ''), throwsArgumentError);
      expect(() => barcode(BarcodeType.code128, 'café'), throwsArgumentError);
    });
    test('rejects module widths outside 2 to 6', () {
      expect(
        () => barcode(BarcodeType.code128, 'A', moduleWidth: 1),
        throwsRangeError,
      );
    });
  });

  group('QR code', () {
    test('model, size, error level, data and print', () {
      expect(qrCode('hi'), [
        0x1D, 0x28, 0x6B, 4, 0, 0x31, 0x41, 0x32, 0, // model 2
        0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x43, 6, // module size
        0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x45, 49, // error level M
        0x1D, 0x28, 0x6B, 5, 0, 0x31, 0x50, 0x30, 0x68, 0x69, // store "hi"
        0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30, // print
      ]);
    });
    test('data length uses two bytes', () {
      final bytes = qrCode('x' * 300, errorLevel: QrErrorLevel.high);
      // 300 bytes of data + 3 = 303 = 0x012F.
      final store = bytes.sublist(25, 33);
      expect(store, [0x1D, 0x28, 0x6B, 0x2F, 0x01, 0x31, 0x50, 0x30]);
      expect(bytes[24], 51);
    });
    test('encodes text as UTF-8', () {
      final bytes = qrCode('中');
      expect(bytes.sublist(33, 36), [0xE4, 0xB8, 0xAD]);
    });
    test('rejects empty data and bad sizes', () {
      expect(() => qrCode(''), throwsArgumentError);
      expect(() => qrCode('a', moduleSize: 0), throwsRangeError);
      expect(() => qrCode('a', moduleSize: 17), throwsRangeError);
    });
  });

  group('raster image', () {
    test('header and rows', () {
      final rows = Uint8List.fromList([0xF0, 0x0F]);
      expect(rasterImage(rows, 1, 2), [0x1D, 0x76, 0x30, 0, 1, 0, 2, 0, 0xF0, 0x0F]);
    });
    test('size uses two bytes each', () {
      final bytes = rasterImage(Uint8List(48 * 300), 48, 300);
      expect(bytes.sublist(4, 8), [48, 0, 0x2C, 0x01]);
    });
    test('rejects a size that does not match the data', () {
      expect(() => rasterImage(Uint8List(3), 1, 2), throwsArgumentError);
    });
  });
}
