import 'package:escpos_kit/escpos_kit.dart';
import 'package:test/test.dart';

void main() {
  group('GBK', () {
    const gbk = PrinterEncoding.gbk;

    test('turns on Chinese mode', () => expect(gbk.setup, [0x1C, 0x26]));

    test('keeps ASCII as is', () {
      expect(gbk.encode('Total: 7.70'), 'Total: 7.70'.codeUnits);
    });

    test('encodes Chinese as two bytes', () {
      expect(gbk.encode('A中文'), [0x41, 0xD6, 0xD0, 0xCE, 0xC4]);
      expect(gbk.encode('港湾咖啡'), [0xB8, 0xDB, 0xCD, 0xE5, 0xBF, 0xA7, 0xB7, 0xC8]);
    });

    // Expected values come from Python's GBK codec, independent of the table.
    const samples = {
      '體': 0xF377, // traditional character
      '鑫': 0xF6CE,
      '·': 0xA1A4, // U+00B7, outside the CJK block
      '—': 0xA1AA,
      '①': 0xA2D9,
      '，': 0xA3AC, // full-width comma
      '￥': 0xA3A4,
      '〇': 0xA996,
      'ⅰ': 0xA2A1,
      'é': 0xA8A6,
    };
    for (final MapEntry(key: char, value: code) in samples.entries) {
      test('encodes $char', () {
        expect(gbkCode(char.runes.single), code);
        expect(gbk.encode(char), [code >> 8, code & 0xFF]);
      });
    }

    test('replaces characters GBK does not have', () {
      expect(gbk.encode('€'), [0x3F]);
      expect(gbk.encode('a😀b'), [0x61, 0x3F, 0x62]);
    });

    test('every CJK ideograph has a two-byte code with a high lead byte', () {
      for (var rune = 0x4E00; rune <= 0x9FA5; rune++) {
        final code = gbkCode(rune)!;
        expect(code >> 8, inInclusiveRange(0x81, 0xFE));
        expect(code & 0xFF, inInclusiveRange(0x40, 0xFE));
      }
    });
  });

  group('Windows-1252', () {
    final cp1252 = PrinterEncoding.cp1252();

    test('selects the code page', () => expect(cp1252.setup, [0x1B, 0x74, 16]));
    test('code page number can be changed', () {
      expect(PrinterEncoding.cp1252(n: 19).setup, [0x1B, 0x74, 19]);
    });
    test('encodes accents and the euro sign', () {
      expect(cp1252.encode('Café €5'), [0x43, 0x61, 0x66, 0xE9, 0x20, 0x80, 0x35]);
      expect(cp1252.encode('Œuvre – “ok”'), [
        0x8C, 0x75, 0x76, 0x72, 0x65, 0x20, 0x96, 0x20, 0x93, 0x6F, 0x6B, 0x94, //
      ]);
    });
    test('replaces anything else', () => expect(cp1252.encode('中'), [0x3F]));
  });

  group('ASCII', () {
    test('has no setup', () => expect(PrinterEncoding.ascii.setup, isEmpty));
    test('replaces non-ASCII', () {
      expect(PrinterEncoding.ascii.encode('né'), [0x6E, 0x3F]);
    });
  });
}
