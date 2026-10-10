## 0.1.0

- `Receipt` builder: text styles, aligned item/price rows with wrapping, dividers, barcodes, QR codes, raster images, cutting and cash drawer.
- Encodings: GBK (Chinese, built-in table, no dependencies), Windows-1252 and ASCII.
- `RasterImage` from RGBA or grey pixels, with scaling and threshold or Floyd–Steinberg dithering.
- `NetworkPrinter` for printers on TCP port 9100, and `Receipt.chunks` for Bluetooth LE writes.
- Low-level commands in `package:escpos_kit/commands.dart`.
