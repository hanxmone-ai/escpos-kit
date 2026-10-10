import 'package:escpos_kit/escpos_kit.dart';
import 'package:test/test.dart';

const init = [0x1B, 0x40];
const lf = 0x0A;

void main() {
  test('starts with initialize and the encoding setup', () {
    expect(Receipt().bytes, [...init, 0x1C, 0x26]);
    expect(Receipt(encoding: PrinterEncoding.ascii).bytes, init);
  });

  group('text', () {
    test('plain text is just the text and a line feed', () {
      final receipt = Receipt(encoding: PrinterEncoding.ascii)..text('Hi');
      expect(receipt.bytes, [...init, 0x48, 0x69, lf]);
    });

    test('styles are switched on and back off', () {
      final receipt = Receipt(encoding: PrinterEncoding.ascii)
        ..text('Hi', align: PosAlign.center, bold: true, size: TextSize.large);
      expect(receipt.bytes, [
        ...init,
        0x1B, 0x61, 1, // center
        0x1B, 0x45, 1, // bold on
        0x1D, 0x21, 0x11, // double size
        0x48, 0x69, lf,
        0x1D, 0x21, 0x00, // normal size
        0x1B, 0x45, 0, // bold off
        0x1B, 0x61, 0, // left
      ]);
    });

    test('Chinese text is GBK', () {
      final receipt = Receipt()..text('中文');
      expect(receipt.bytes.sublist(4), [0xD6, 0xD0, 0xCE, 0xC4, lf]);
    });
  });

  group('row and divider', () {
    test('row fills the paper width', () {
      final receipt = Receipt(encoding: PrinterEncoding.ascii)..row(['Flat white', '4.50']);
      final line = receipt.bytes.sublist(2);
      expect(String.fromCharCodes(line), 'Flat white${' ' * 18}4.50\n');
    });

    test('80 mm paper has 48 columns', () {
      final receipt = Receipt(paper: Paper.mm80, encoding: PrinterEncoding.ascii)..divider();
      expect(receipt.bytes.sublist(2), [...List.filled(48, 0x2D), lf]);
    });

    test('a wide divider character is repeated half as often', () {
      final receipt = Receipt()..divider(char: '＝');
      // 16 full-width characters, two bytes each, then a line feed.
      expect(receipt.bytes.length, 4 + 32 + 1);
    });

    test('bold row', () {
      final receipt = Receipt(encoding: PrinterEncoding.ascii)
        ..row(['TOTAL', '7.70'], bold: true);
      final bytes = receipt.bytes;
      expect(bytes.sublist(2, 5), [0x1B, 0x45, 1]);
      expect(bytes.sublist(bytes.length - 3), [0x1B, 0x45, 0]);
    });
  });

  group('codes, images and paper handling', () {
    test('QR codes are centred', () {
      final bytes = (Receipt(encoding: PrinterEncoding.ascii)..qr('hi')).bytes;
      expect(bytes.sublist(2, 5), [0x1B, 0x61, 1]);
      expect(bytes.sublist(bytes.length - 3), [0x1B, 0x61, 0]);
    });

    test('barcode defaults to CODE128', () {
      final bytes = (Receipt(encoding: PrinterEncoding.ascii)..barcode('A1')).bytes;
      expect(bytes.sublist(5, 14), [0x1D, 0x68, 80, 0x1D, 0x77, 2, 0x1D, 0x48, 2]);
      expect(bytes.sublist(14, 18), [0x1D, 0x6B, 73, 4]);
    });

    test('images wider than the paper are rejected', () {
      final image = RasterImage.fromLuminance(List.filled(400, 0), 400, 1);
      expect(() => Receipt().image(image), throwsArgumentError);
      expect(() => Receipt(paper: Paper.mm80).image(image), returnsNormally);
    });

    test('cut feeds three lines first', () {
      final receipt = Receipt(encoding: PrinterEncoding.ascii)..cut();
      expect(receipt.bytes.sublist(2), [0x1B, 0x64, 3, 0x1D, 0x56, 66, 0]);
    });

    test('drawer and raw bytes', () {
      final receipt = Receipt(encoding: PrinterEncoding.ascii)
        ..openDrawer()
        ..raw([1, 2, 3]);
      expect(receipt.bytes.sublist(2), [0x1B, 0x70, 0, 50, 50, 1, 2, 3]);
    });
  });

  test('chunks for Bluetooth writes', () {
    final receipt = Receipt(encoding: PrinterEncoding.ascii)..raw(List.filled(8, 0));
    expect(receipt.chunks(4).map((c) => c.length), [4, 4, 2]);
    expect(receipt.chunks(4).expand((c) => c), receipt.bytes);
  });

  test('the example from the README builds', () {
    final receipt = Receipt(paper: Paper.mm58)
      ..text('HARBORLANE CAFE', align: PosAlign.center, bold: true)
      ..row(['Flat white', '4.50'])
      ..row(['Banana bread', '3.20'])
      ..divider()
      ..row(['TOTAL', '7.70'], bold: true)
      ..qr('https://example.com/r/1042')
      ..cut();
    final bytes = receipt.bytes;
    expect(bytes.sublist(0, 4), [...init, 0x1C, 0x26]);
    expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 66, 0]);
  });
}
