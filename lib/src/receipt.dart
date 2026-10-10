import 'dart:typed_data';

import 'commands.dart' as cmd;
import 'commands.dart'
    show
        BarcodeText,
        BarcodeType,
        Cut,
        Font,
        PosAlign,
        QrErrorLevel,
        TextSize,
        Underline;
import 'encoding.dart';
import 'image.dart';
import 'layout.dart';

/// Paper width.
class Paper {
  const Paper({required this.dots, required this.columns});

  /// Printable width in dots.
  final int dots;

  /// Characters per line in font A at normal size.
  final int columns;

  /// 58 mm paper: 384 dots, 32 characters (16 Chinese characters).
  static const Paper mm58 = Paper(dots: 384, columns: 32);

  /// 80 mm paper: 576 dots, 48 characters (24 Chinese characters).
  static const Paper mm80 = Paper(dots: 576, columns: 48);
}

/// Builds the bytes of one receipt.
///
/// ```dart
/// final receipt = Receipt(paper: Paper.mm58)
///   ..text('HARBORLANE CAFE', align: PosAlign.center, bold: true)
///   ..row(['Flat white', '4.50'])
///   ..divider()
///   ..row(['TOTAL', '4.50'], bold: true)
///   ..qr('https://example.com/r/1042')
///   ..cut();
/// ```
///
/// Every method leaves the printer in its default style (left aligned, normal
/// size, not bold), so the calls can be reordered without surprises.
class Receipt {
  Receipt({this.paper = Paper.mm58, this.encoding = PrinterEncoding.gbk}) {
    _out
      ..addAll(cmd.initialize())
      ..addAll(encoding.setup);
  }

  final Paper paper;

  /// How text is turned into bytes. GBK covers ASCII and Chinese; use
  /// [PrinterEncoding.cp1252] for Western European text on printers without
  /// Chinese support.
  final PrinterEncoding encoding;

  final List<int> _out = [];

  /// The bytes to send to the printer.
  Uint8List get bytes => Uint8List.fromList(_out);

  /// [bytes] split into pieces of at most [size] bytes, for Bluetooth LE
  /// writes, which are limited by the connection's MTU.
  Iterable<Uint8List> chunks(int size) sync* {
    if (size < 1) throw RangeError.value(size, 'size', 'must be at least 1');
    final all = bytes;
    for (var start = 0; start < all.length; start += size) {
      final end = start + size < all.length ? start + size : all.length;
      yield Uint8List.sublistView(all, start, end);
    }
  }

  /// Prints [value] followed by a line break. The printer wraps long lines.
  void text(
    String value, {
    PosAlign align = PosAlign.left,
    bool bold = false,
    Underline underline = Underline.none,
    TextSize size = TextSize.normal,
    bool reverse = false,
    Font font = Font.a,
  }) {
    _styled(
      align: align,
      bold: bold,
      underline: underline,
      size: size,
      reverse: reverse,
      font: font,
      body: () => _line(value),
    );
  }

  /// Prints [cells] side by side, for "item ... price" lines.
  ///
  /// [widths] are in columns and default to [autoWidths]. Cells that do not
  /// fit wrap inside their own column.
  void row(
    List<String> cells, {
    List<int>? widths,
    List<PosAlign>? aligns,
    bool bold = false,
  }) {
    final columns = widths ?? autoWidths(cells, paper.columns);
    final lines = layoutRow(cells, columns, aligns: aligns);
    _styled(bold: bold, body: () => lines.forEach(_line));
  }

  /// A full-width line of [char].
  void divider({String char = '-'}) {
    final width = textWidth(char);
    if (width < 1) throw ArgumentError.value(char, 'char', 'must not be empty');
    _line(char * (paper.columns ~/ width));
  }

  /// Feeds [lines] empty lines.
  void feed([int lines = 1]) => _out.addAll(cmd.feedLines(lines));

  /// Prints a barcode, centred by default.
  void barcode(
    String data, {
    BarcodeType type = BarcodeType.code128,
    int height = 80,
    int moduleWidth = 2,
    BarcodeText text = BarcodeText.below,
    PosAlign align = PosAlign.center,
  }) {
    _styled(
      align: align,
      body: () => _out.addAll(cmd.barcode(
        type,
        data,
        height: height,
        moduleWidth: moduleWidth,
        text: text,
      )),
    );
  }

  /// Prints a QR code, centred by default.
  void qr(
    String data, {
    int moduleSize = 6,
    QrErrorLevel errorLevel = QrErrorLevel.medium,
    PosAlign align = PosAlign.center,
  }) {
    _styled(
      align: align,
      body: () => _out.addAll(
        cmd.qrCode(data, moduleSize: moduleSize, errorLevel: errorLevel),
      ),
    );
  }

  /// Prints a raster image, centred by default. Images wider than the paper
  /// are rejected; pass `maxWidth: paper.dots` when building the image.
  void image(RasterImage image, {PosAlign align = PosAlign.center}) {
    if (image.width > paper.dots) {
      throw ArgumentError(
          'image is ${image.width} dots wide but the paper has ${paper.dots}');
    }
    _styled(
      align: align,
      body: () => _out.addAll(
        cmd.rasterImage(image.rows, image.widthBytes, image.height),
      ),
    );
  }

  /// Feeds [feedLines] lines so the last printed line clears the cutter, then cuts.
  void cut({Cut mode = Cut.partial, int feedLines = 3}) {
    if (feedLines > 0) _out.addAll(cmd.feedLines(feedLines));
    _out.addAll(cmd.cut(mode: mode));
  }

  /// Opens the cash drawer connected to the printer.
  void openDrawer({int pin = 2}) => _out.addAll(cmd.openDrawer(pin: pin));

  /// Appends raw bytes, for commands this library does not cover.
  void raw(List<int> bytes) => _out.addAll(bytes);

  void _line(String value) {
    _out
      ..addAll(encoding.encode(value))
      ..addAll(cmd.lineFeed());
  }

  /// Switches on only the styles that differ from the defaults, runs [body],
  /// then switches them back off.
  void _styled({
    PosAlign align = PosAlign.left,
    bool bold = false,
    Underline underline = Underline.none,
    TextSize size = TextSize.normal,
    bool reverse = false,
    Font font = Font.a,
    required void Function() body,
  }) {
    if (align != PosAlign.left) _out.addAll(cmd.align(align));
    if (font != Font.a) _out.addAll(cmd.font(font));
    if (bold) _out.addAll(cmd.bold(true));
    if (underline != Underline.none) _out.addAll(cmd.underline(underline));
    if (size != TextSize.normal) _out.addAll(cmd.textSize(size));
    if (reverse) _out.addAll(cmd.reverse(true));
    body();
    if (reverse) _out.addAll(cmd.reverse(false));
    if (size != TextSize.normal) _out.addAll(cmd.textSize(TextSize.normal));
    if (underline != Underline.none) _out.addAll(cmd.underline(Underline.none));
    if (bold) _out.addAll(cmd.bold(false));
    if (font != Font.a) _out.addAll(cmd.font(Font.a));
    if (align != PosAlign.left) _out.addAll(cmd.align(PosAlign.left));
  }
}
