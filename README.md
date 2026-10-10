# escpos_kit

[![Dart CI](https://github.com/hanxmone-ai/escpos-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/hanxmone-ai/escpos-kit/actions/workflows/ci.yml)

Build ESC/POS receipts in pure Dart and send them to thermal receipt printers.

- **No Flutter dependency, no native code.** Works in Flutter apps (including web), on servers and in command-line tools. `NetworkPrinter` needs `dart:io`, so it is not available on the web.
- **Chinese out of the box.** A built-in GBK table (no extra packages) plus Windows-1252 for Western European text.
- **Columns that line up.** Item and price rows are padded by display width, so Chinese names (two columns per character) align with Latin ones, and long names wrap inside their own column.
- **Barcodes, QR codes and images.** Images come from raw RGBA pixels, scaled to the paper and dithered.
- **Any connection.** Send to a network printer on port 9100, or take the bytes (in Bluetooth-sized chunks) to whatever plugin your app uses.
- **Tested byte by byte.** Every command has a unit test against the exact bytes it must produce.

[中文说明](README.zh-CN.md)

## Install

Not on pub.dev yet; add it from GitHub:

```yaml
dependencies:
  escpos_kit:
    git:
      url: https://github.com/hanxmone-ai/escpos-kit
      ref: main
```

## Quick start

```dart
import 'package:escpos_kit/escpos_kit.dart';

final receipt = Receipt(paper: Paper.mm58)
  ..text('HARBORLANE CAFE', align: PosAlign.center, bold: true, size: TextSize.large)
  ..text('12 Harbour Road', align: PosAlign.center)
  ..divider()
  ..row(['Flat white', '4.50'])
  ..row(['Banana bread with walnuts', '3.20'])
  ..divider()
  ..row(['TOTAL', '7.70'], bold: true)
  ..qr('https://example.com/r/1042')
  ..cut();

await NetworkPrinter('192.168.1.80').print(receipt);
```

The rows come out like this on 58 mm paper (32 columns):

```
--------------------------------
Flat white                  4.50
Banana bread with walnuts   3.20
--------------------------------
TOTAL                       7.70
```

Run `dart run example/main.dart <printer-ip>` to print the full example, or without an address to write the
bytes to `receipt.bin`.

## Receipt

| Method | What it prints |
|---|---|
| `text(value, align:, bold:, underline:, size:, reverse:, font:)` | One line of text in the given style. The printer wraps long lines. |
| `row(cells, widths:, aligns:, bold:)` | Cells side by side. By default every cell after the first is as wide as its text and the first takes the rest. |
| `divider(char: '-')` | A full-width line. |
| `feed([lines])` | Empty lines. |
| `barcode(data, type:, height:, moduleWidth:, text:)` | A barcode, CODE128 by default. Data is checked against the symbology. |
| `qr(data, moduleSize:, errorLevel:)` | A QR code (model 2), UTF-8. |
| `image(rasterImage)` | A 1-bit image. |
| `cut(mode:, feedLines:)` | Feeds past the cutter, then cuts. |
| `openDrawer(pin:)` | Pulses the cash drawer. |
| `raw(bytes)` | Anything else. |

Every method puts the style back to the default when it finishes, so calls can be reordered freely.
`receipt.bytes` returns everything as a `Uint8List`.

Paper sizes: `Paper.mm58` (384 dots, 32 columns) and `Paper.mm80` (576 dots, 48 columns), or
`Paper(dots: ..., columns: ...)` for anything else.

## Text encoding

Thermal printers don't understand UTF-8, so pick the encoding your printer supports:

| Encoding | Use for | Sends |
|---|---|---|
| `PrinterEncoding.gbk` (default) | Chinese and ASCII on printers sold in China (most low-cost 58/80 mm models) | `FS &` (Chinese mode on) |
| `PrinterEncoding.cp1252(n: 16)` | English, French, German, Spanish, Portuguese… | `ESC t 16`; check the code page number in your printer's manual |
| `PrinterEncoding.ascii` | Plain ASCII | nothing |

```dart
final receipt = Receipt(encoding: PrinterEncoding.cp1252());
```

Characters an encoding can't represent print as `?`. To support another code page, extend `PrinterEncoding`.

## Images

`RasterImage` takes raw pixels, so the library needs no image decoder.

```dart
// Flutter: from a ui.Image (for example a decoded logo asset).
final data = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
final logo = RasterImage.fromRgba(
  data!.buffer.asUint8List(),
  uiImage.width,
  uiImage.height,
  maxWidth: Paper.mm58.dots,           // scale down to fit the paper
  dithering: Dithering.floydSteinberg, // for photos; the default threshold suits logos
);
receipt.image(logo);
```

## Bluetooth

The library builds bytes; the Bluetooth plugin your app already uses sends them. BLE writes are limited by the
MTU, so split the receipt:

```dart
for (final chunk in receipt.chunks(180)) {
  await characteristic.write(chunk, withoutResponse: true);
}
```

## Low-level commands

`package:escpos_kit/commands.dart` exposes each command as a function returning bytes, for custom layouts:

```dart
import 'package:escpos_kit/commands.dart' as esc;

final bytes = [
  ...esc.initialize(),
  ...esc.textSize(esc.TextSize.large),
  ...'BIG'.codeUnits,
  ...esc.lineFeed(),
  ...esc.cut(mode: esc.Cut.full),
];
```

## Development

```bash
dart pub get
dart analyze
dart test
```

`lib/src/gbk_table.dart` is generated from Python's GBK codec by `python3 tool/gen_gbk_table.py`; CI checks that the
two still match.

## License

[MIT](LICENSE) © 2026 Yihan Qiu
