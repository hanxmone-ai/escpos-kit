# escpos_kit

[English](README.md)

纯 Dart 编写的 ESC/POS 小票打印库：生成小票字节，发给热敏小票打印机。

- **不依赖 Flutter，也没有原生代码。** Flutter 应用、服务端、命令行工具都能用。
- **中文开箱即用。** 内置 GBK 编码表（无需额外依赖），另有 Windows-1252 支持西欧语言。
- **列对得齐。** 商品和价格行按显示宽度补齐，中文（每字占两列）和英文混排也能对齐；名称过长时在本列内换行。
- **条码、二维码、图片。** 图片直接接收 RGBA 像素，自动缩放到纸宽并抖动处理。
- **连接方式不限。** 网络打印机（9100 端口）直接发送；蓝牙则把字节按块交给你项目里已有的蓝牙插件。
- **逐字节测试。** 每条指令都有单元测试，核对输出的每一个字节。

## 安装

暂未发布到 pub.dev，可从 GitHub 引用：

```yaml
dependencies:
  escpos_kit:
    git:
      url: https://github.com/hanxmone-ai/escpos-kit
      ref: main
```

## 快速开始

```dart
import 'package:escpos_kit/escpos_kit.dart';

final receipt = Receipt(paper: Paper.mm58) // 默认 GBK 编码
  ..text('港湾咖啡', align: PosAlign.center, bold: true, size: TextSize.large)
  ..divider()
  ..row(['拿铁', '28.00'])
  ..row(['香蕉核桃蛋糕（大份）', '18.00'])
  ..divider()
  ..row(['合计', '46.00'], bold: true)
  ..qr('https://example.com/r/1042')
  ..cut();

await NetworkPrinter('192.168.1.80').print(receipt);
```

## 常用方法

| 方法 | 作用 |
|---|---|
| `text(内容, align:, bold:, underline:, size:, reverse:, font:)` | 打印一行指定样式的文字 |
| `row(各列, widths:, aligns:, bold:)` | 多列并排；默认除第一列外按内容宽度，第一列占剩余宽度 |
| `divider(char: '-')` | 整行分隔线 |
| `feed([行数])` | 走纸空行 |
| `barcode(数据, type:, height:, moduleWidth:, text:)` | 条码，默认 CODE128，会校验数据格式 |
| `qr(数据, moduleSize:, errorLevel:)` | 二维码（Model 2，UTF-8） |
| `image(RasterImage)` | 位图 |
| `cut(mode:, feedLines:)` | 走纸后切纸 |
| `openDrawer(pin:)` | 弹钱箱 |
| `raw(字节)` | 发送任意自定义指令 |

每个方法结束后都会把样式恢复为默认值，调用顺序可以随意调整。`receipt.bytes` 返回完整的 `Uint8List`。

纸宽：`Paper.mm58`（384 点，32 个英文字符 / 16 个汉字）、`Paper.mm80`（576 点，48 / 24），其他规格用
`Paper(dots: ..., columns: ...)`。

## 编码

| 编码 | 适用 |
|---|---|
| `PrinterEncoding.gbk`（默认） | 国内销售的打印机（大多数 58/80mm 机型），中文和英文 |
| `PrinterEncoding.cp1252(n: 16)` | 不支持中文的海外机型，英法德西葡等语言；代码页编号以打印机手册为准 |
| `PrinterEncoding.ascii` | 纯 ASCII |

无法编码的字符会打印为 `?`。需要其他代码页时，继承 `PrinterEncoding` 即可。

## 图片（Flutter）

```dart
final data = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
final logo = RasterImage.fromRgba(
  data!.buffer.asUint8List(),
  uiImage.width,
  uiImage.height,
  maxWidth: Paper.mm58.dots, // 按纸宽缩放
);
receipt.image(logo);
```

## 蓝牙

本库只负责生成字节，发送交给项目里已有的蓝牙插件。BLE 单次写入受 MTU 限制，需要分块：

```dart
for (final chunk in receipt.chunks(180)) {
  await characteristic.write(chunk, withoutResponse: true);
}
```

## 开发

```bash
dart pub get
dart analyze
dart test
```

`lib/src/gbk_table.dart` 由 `python3 tool/gen_gbk_table.py` 根据 Python 自带的 GBK 编码生成，CI 会检查两者是否一致。

## 许可证

[MIT](LICENSE) © 2026 Yihan Qiu
