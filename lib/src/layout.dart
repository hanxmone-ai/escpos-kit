import 'commands.dart' show PosAlign;

/// How many columns [rune] takes on a receipt: 2 for Chinese, Japanese and
/// Korean characters and full-width forms, 1 for everything else.
int runeWidth(int rune) {
  if (rune < 0x1100) return 1;
  if (rune <= 0x115F || // Hangul Jamo
      (rune >= 0x2E80 && rune <= 0xA4CF && rune != 0x303F) || // CJK
      (rune >= 0xAC00 && rune <= 0xD7A3) || // Hangul syllables
      (rune >= 0xF900 && rune <= 0xFAFF) || // CJK compatibility ideographs
      (rune >= 0xFE30 && rune <= 0xFE4F) || // CJK compatibility forms
      (rune >= 0xFF00 && rune <= 0xFF60) || // full-width forms
      (rune >= 0xFFE0 && rune <= 0xFFE6) ||
      (rune >= 0x20000 && rune <= 0x3FFFD)) {
    return 2;
  }
  return 1;
}

/// The printed width of [text] in columns.
int textWidth(String text) {
  var width = 0;
  for (final rune in text.runes) {
    width += runeWidth(rune);
  }
  return width;
}

/// Splits [text] into lines at most [width] columns wide.
///
/// Latin text breaks at the last space that fits; words longer than a line,
/// and Chinese text, break anywhere. Existing line breaks are kept.
List<String> wrapText(String text, int width) {
  if (width < 1) throw RangeError.value(width, 'width', 'must be at least 1');
  final lines = <String>[];
  for (final paragraph in text.split('\n')) {
    var line = <int>[];
    var lineWidth = 0;
    var lastSpace = -1;
    for (final rune in paragraph.runes) {
      final w = runeWidth(rune);
      if (lineWidth + w > width && line.isNotEmpty) {
        if (rune == 0x20) {
          // The space itself would overflow: end the line here and drop it.
          lines.add(String.fromCharCodes(line));
          line = <int>[];
          lineWidth = 0;
          lastSpace = -1;
          continue;
        }
        if (lastSpace > 0) {
          final rest = line.sublist(lastSpace + 1);
          lines.add(String.fromCharCodes(line.sublist(0, lastSpace)));
          line = rest;
          lineWidth = textWidth(String.fromCharCodes(rest));
        } else {
          lines.add(String.fromCharCodes(line));
          line = <int>[];
          lineWidth = 0;
        }
        lastSpace = -1;
      }
      if (rune == 0x20) lastSpace = line.length;
      line.add(rune);
      lineWidth += w;
    }
    lines.add(String.fromCharCodes(line));
  }
  return lines;
}

/// Pads [text] with spaces to exactly [width] columns.
String pad(String text, int width, PosAlign align) {
  final space = width - textWidth(text);
  if (space <= 0) return text;
  switch (align) {
    case PosAlign.left:
      return '$text${' ' * space}';
    case PosAlign.right:
      return '${' ' * space}$text';
    case PosAlign.center:
      final left = space ~/ 2;
      return '${' ' * left}$text${' ' * (space - left)}';
  }
}

/// Column widths for [cells] on a line of [total] columns.
///
/// Every cell after the first gets the width of its text and the first cell
/// takes what is left, which suits "item ... price" rows. When that would leave
/// the first cell less than a third of the line, the columns are split evenly.
List<int> autoWidths(List<String> cells, int total, {int gap = 1}) {
  final n = cells.length;
  if (n == 0) return const [];
  if (n == 1) return [total];
  final available = total - gap * (n - 1);
  final rest = [for (final cell in cells.skip(1)) textWidth(cell).clamp(1, available)];
  final first = available - rest.fold<int>(0, (a, b) => a + b);
  if (first >= total ~/ 3) return [first, ...rest];
  final even = available ~/ n;
  return [available - even * (n - 1), for (var i = 1; i < n; i++) even];
}

/// Lays [cells] out side by side and returns the printed lines.
///
/// Each cell wraps inside its own column. [aligns] defaults to the first column
/// on the left and the others on the right.
List<String> layoutRow(
  List<String> cells,
  List<int> widths, {
  List<PosAlign>? aligns,
  int gap = 1,
}) {
  if (cells.length != widths.length) {
    throw ArgumentError('cells and widths must have the same length');
  }
  if (aligns != null && aligns.length != cells.length) {
    throw ArgumentError('cells and aligns must have the same length');
  }
  final wrapped = [
    for (var i = 0; i < cells.length; i++) wrapText(cells[i], widths[i]),
  ];
  final height = wrapped.fold<int>(0, (h, lines) => lines.length > h ? lines.length : h);
  final separator = ' ' * gap;
  return [
    for (var line = 0; line < height; line++)
      [
        for (var i = 0; i < cells.length; i++)
          pad(
            line < wrapped[i].length ? wrapped[i][line] : '',
            widths[i],
            aligns?[i] ?? (i == 0 ? PosAlign.left : PosAlign.right),
          ),
      ].join(separator).trimRight(),
  ];
}
