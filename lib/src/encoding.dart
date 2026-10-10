import 'dart:convert';
import 'dart:typed_data';

import 'commands.dart' as cmd;
import 'gbk_table.dart';

/// Turns text into the bytes a printer expects.
///
/// Thermal printers do not understand UTF-8. They print single-byte text from a
/// selected code page, and printers sold in China also accept GBK double-byte
/// text once "Chinese mode" is on. Pick the encoding that matches the printer.
abstract class PrinterEncoding {
  const PrinterEncoding();

  /// Bytes sent once after `ESC @` to put the printer in the right mode.
  List<int> get setup;

  /// Encodes [text]. Characters the encoding cannot represent become [replacement].
  List<int> encode(String text);

  /// The byte printed for characters that cannot be encoded.
  int get replacement => 0x3F; // '?'

  /// GBK (CP936): ASCII plus Simplified and Traditional Chinese. Turns on the
  /// printer's Chinese mode with `FS &`.
  static const PrinterEncoding gbk = GbkEncoding();

  /// Windows-1252 (Western European) through code page [n] of `ESC t`. 16 is
  /// WPC1252 on most Epson-compatible printers; check your printer's manual.
  static PrinterEncoding cp1252({int n = 16}) => Cp1252Encoding(codePage: n);

  /// Plain ASCII. Anything else is replaced.
  static const PrinterEncoding ascii = AsciiEncoding();
}

/// ASCII only; no setup bytes.
class AsciiEncoding extends PrinterEncoding {
  const AsciiEncoding();

  @override
  List<int> get setup => const [];

  @override
  List<int> encode(String text) => [
        for (final rune in text.runes) rune < 0x80 ? rune : replacement,
      ];
}

/// GBK double-byte text with the printer in Chinese mode.
class GbkEncoding extends PrinterEncoding {
  const GbkEncoding();

  @override
  List<int> get setup => cmd.kanjiOn();

  @override
  List<int> encode(String text) {
    final out = <int>[];
    for (final rune in text.runes) {
      if (rune < 0x80) {
        out.add(rune);
        continue;
      }
      final code = gbkCode(rune);
      if (code == null) {
        out.add(replacement);
      } else {
        out
          ..add(code >> 8)
          ..add(code & 0xFF);
      }
    }
    return out;
  }
}

/// Windows-1252, the usual code page for English, French, German, Spanish,
/// Portuguese and other Western European languages.
class Cp1252Encoding extends PrinterEncoding {
  const Cp1252Encoding({this.codePage = 16});

  /// The `n` of `ESC t n` that selects WPC1252 on the target printer.
  final int codePage;

  @override
  List<int> get setup => cmd.codePage(codePage);

  // 0x80-0x9F in Windows-1252; zero marks bytes with no character.
  static const List<int> _high = [
    0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0, //
    0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178, //
  ];

  @override
  List<int> encode(String text) {
    final out = <int>[];
    for (final rune in text.runes) {
      if (rune < 0x80 || (rune >= 0xA0 && rune <= 0xFF)) {
        out.add(rune);
      } else {
        final index = _high.indexOf(rune);
        out.add(index >= 0 ? 0x80 + index : replacement);
      }
    }
    return out;
  }
}

Uint8List? _dense;
Map<int, int>? _sparse;

/// The two-byte GBK code of [rune] as `lead << 8 | trail`, or null when GBK
/// has no such character. ASCII is not handled here.
int? gbkCode(int rune) {
  if (rune >= gbkDenseFirst && rune <= gbkDenseLast) {
    final dense = _dense ??= base64.decode(gbkDenseBase64);
    final i = (rune - gbkDenseFirst) * 2;
    return dense[i] << 8 | dense[i + 1];
  }
  final sparse = _sparse ??= _loadSparse();
  return sparse[rune];
}

Map<int, int> _loadSparse() {
  final data = base64.decode(gbkSparseBase64);
  return {
    for (var i = 0; i < data.length; i += 4)
      data[i] << 8 | data[i + 1]: data[i + 2] << 8 | data[i + 3],
  };
}
