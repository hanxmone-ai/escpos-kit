/// Raw ESC/POS command bytes.
///
/// Every function returns a list of bytes and has no side effects, so the
/// commands can be tested byte by byte and combined freely. Most code uses
/// `Receipt` instead, which calls these.
library;

import 'dart:convert';
import 'dart:typed_data';

const int esc = 0x1B;
const int gs = 0x1D;
const int fs = 0x1C;
const int lf = 0x0A;

/// Horizontal alignment of text, barcodes, QR codes and images.
enum PosAlign {
  left(0),
  center(1),
  right(2);

  const PosAlign(this.value);

  /// The `n` of `ESC a n`.
  final int value;
}

/// Underline thickness.
enum Underline {
  none(0),
  single(1),
  thick(2);

  const Underline(this.value);

  /// The `n` of `ESC - n`.
  final int value;
}

/// Built-in printer fonts. Font A is 12×24 dots on most printers, font B 9×17.
enum Font {
  a(0),
  b(1);

  const Font(this.value);

  /// The `n` of `ESC M n`.
  final int value;
}

/// Character size multiplier, 1 to 8 in each direction.
class TextSize {
  const TextSize(this.width, this.height)
      : assert(width >= 1 && width <= 8),
        assert(height >= 1 && height <= 8);

  final int width;
  final int height;

  static const TextSize normal = TextSize(1, 1);
  static const TextSize doubleHeight = TextSize(1, 2);
  static const TextSize doubleWidth = TextSize(2, 1);
  static const TextSize large = TextSize(2, 2);
  static const TextSize triple = TextSize(3, 3);

  /// The `n` of `GS ! n`: width in the high nibble, height in the low one.
  int get value => ((width - 1) << 4) | (height - 1);

  @override
  bool operator ==(Object other) =>
      other is TextSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'TextSize($width, $height)';
}

/// How the paper is cut.
enum Cut {
  /// Cuts all the way through.
  full(65),

  /// Leaves a small tab so the receipt stays attached until torn off.
  partial(66);

  const Cut(this.value);

  /// The `m` of `GS V m n` (function B: feed `n` dots, then cut).
  final int value;
}

/// Where the human-readable text of a barcode is printed.
enum BarcodeText {
  none(0),
  above(1),
  below(2),
  both(3);

  const BarcodeText(this.value);

  /// The `n` of `GS H n`.
  final int value;
}

/// QR code error correction level.
enum QrErrorLevel {
  /// About 7% of the code can be damaged.
  low(48),

  /// About 15%.
  medium(49),

  /// About 25%.
  quartile(50),

  /// About 30%.
  high(51);

  const QrErrorLevel(this.value);

  final int value;
}

/// `ESC @`: clears the buffer and resets every setting to its default.
List<int> initialize() => const [esc, 0x40];

/// `LF`: prints the buffer and feeds one line.
List<int> lineFeed() => const [lf];

/// `ESC d n`: prints the buffer and feeds [lines] lines (0 to 255).
List<int> feedLines(int lines) => [esc, 0x64, _byte(lines, 'lines')];

/// `ESC a n`.
List<int> align(PosAlign value) => [esc, 0x61, value.value];

/// `ESC E n`.
List<int> bold(bool on) => [esc, 0x45, on ? 1 : 0];

/// `ESC - n`.
List<int> underline(Underline value) => [esc, 0x2D, value.value];

/// `GS B n`: white text on black.
List<int> reverse(bool on) => [gs, 0x42, on ? 1 : 0];

/// `ESC M n`.
List<int> font(Font value) => [esc, 0x4D, value.value];

/// `GS ! n`.
List<int> textSize(TextSize size) => [gs, 0x21, size.value];

/// `ESC t n`: selects the character code table for single-byte text.
List<int> codePage(int n) => [esc, 0x74, _byte(n, 'code page')];

/// `FS &`: double-byte (Chinese) character mode on.
List<int> kanjiOn() => const [fs, 0x26];

/// `FS .`: double-byte character mode off.
List<int> kanjiOff() => const [fs, 0x2E];

/// `GS V m n`: feeds [feedDots] dots so the last line clears the cutter, then cuts.
List<int> cut({Cut mode = Cut.partial, int feedDots = 0}) =>
    [gs, 0x56, mode.value, _byte(feedDots, 'feedDots')];

/// `ESC p m t1 t2`: sends a pulse to open the cash drawer on [pin] 2 or 5.
List<int> openDrawer({int pin = 2, int onMs = 100, int offMs = 100}) {
  if (pin != 2 && pin != 5) {
    throw ArgumentError.value(pin, 'pin', 'must be 2 or 5');
  }
  return [
    esc,
    0x70,
    pin == 2 ? 0 : 1,
    _byte((onMs / 2).round(), 'onMs'),
    _byte((offMs / 2).round(), 'offMs'),
  ];
}

/// Barcode symbologies, with the `m` of `GS k m n d1...dn`.
enum BarcodeType {
  upcA(65),
  upcE(66),
  ean13(67),
  ean8(68),
  code39(69),
  itf(70),
  codabar(71),
  code93(72),
  code128(73);

  const BarcodeType(this.value);

  final int value;
}

/// Prints a barcode.
///
/// [height] is in dots (1 to 255) and [moduleWidth] is the width of the
/// narrowest bar (2 to 6). CODE128 data is sent in code set B, so it can hold
/// any printable ASCII.
List<int> barcode(
  BarcodeType type,
  String data, {
  int height = 80,
  int moduleWidth = 2,
  BarcodeText text = BarcodeText.below,
}) {
  _checkBarcode(type, data);
  if (moduleWidth < 2 || moduleWidth > 6) {
    throw RangeError.range(moduleWidth, 2, 6, 'moduleWidth');
  }
  final payload = [
    if (type == BarcodeType.code128) ...'{B'.codeUnits,
    ...data.codeUnits,
  ];
  return [
    gs, 0x68, _byte(height, 'height'), // GS h: height
    gs, 0x77, moduleWidth, // GS w: module width
    gs, 0x48, text.value, // GS H: human-readable text position
    gs, 0x6B, type.value, _byte(payload.length, 'data length'), ...payload,
  ];
}

final RegExp _digits = RegExp(r'^[0-9]+$');

final RegExp _code39 = RegExp(r'^[0-9A-Z $%*+\-./]+$');
final RegExp _codabar = RegExp(r'^[0-9A-Da-d$+\-./:]+$');

void _checkBarcode(BarcodeType type, String data) {
  final digits = _digits.hasMatch(data);
  final n = data.length;
  final ok = switch (type) {
    BarcodeType.upcA => digits && (n == 11 || n == 12),
    BarcodeType.upcE => digits && const [6, 7, 8, 11, 12].contains(n),
    BarcodeType.ean13 => digits && (n == 12 || n == 13),
    BarcodeType.ean8 => digits && (n == 7 || n == 8),
    BarcodeType.itf => digits && n.isEven,
    BarcodeType.code39 => _code39.hasMatch(data),
    BarcodeType.codabar => _codabar.hasMatch(data),
    BarcodeType.code93 || BarcodeType.code128 =>
      n > 0 && data.codeUnits.every((c) => c >= 0x20 && c < 0x7F),
  };
  if (!ok) {
    throw ArgumentError.value(data, 'data', 'not valid for ${type.name}');
  }
}

/// Prints a QR code (model 2) holding [data] as UTF-8.
///
/// [moduleSize] is the size of one square in dots, 1 to 16.
List<int> qrCode(
  String data, {
  int moduleSize = 6,
  QrErrorLevel errorLevel = QrErrorLevel.medium,
}) {
  if (moduleSize < 1 || moduleSize > 16) {
    throw RangeError.range(moduleSize, 1, 16, 'moduleSize');
  }
  final bytes = utf8.encode(data);
  if (bytes.isEmpty || bytes.length > 7089) {
    throw ArgumentError.value(data, 'data', 'must be 1 to 7089 bytes');
  }
  final storeLength = bytes.length + 3;
  return [
    // Function 165: select model 2.
    gs, 0x28, 0x6B, 4, 0, 0x31, 0x41, 0x32, 0,
    // Function 167: module size.
    gs, 0x28, 0x6B, 3, 0, 0x31, 0x43, moduleSize,
    // Function 169: error correction level.
    gs, 0x28, 0x6B, 3, 0, 0x31, 0x45, errorLevel.value,
    // Function 180: store the data.
    gs, 0x28, 0x6B, storeLength & 0xFF, storeLength >> 8, 0x31, 0x50, 0x30,
    ...bytes,
    // Function 181: print it.
    gs, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30,
  ];
}

/// `GS v 0`: prints a 1-bit raster image.
///
/// [rows] holds `height` rows of `widthBytes` bytes each; a set bit is a black
/// dot and the most significant bit is the leftmost dot.
List<int> rasterImage(Uint8List rows, int widthBytes, int height) {
  if (widthBytes < 1 || widthBytes > 0xFFFF || height < 1 || height > 0xFFFF) {
    throw ArgumentError('image size out of range');
  }
  if (rows.length != widthBytes * height) {
    throw ArgumentError.value(
        rows.length, 'rows', 'expected ${widthBytes * height} bytes');
  }
  return [
    gs, 0x76, 0x30, 0, // m = 0: normal density
    widthBytes & 0xFF, widthBytes >> 8,
    height & 0xFF, height >> 8,
    ...rows,
  ];
}

int _byte(int value, String name) {
  if (value < 0 || value > 255) throw RangeError.range(value, 0, 255, name);
  return value;
}
