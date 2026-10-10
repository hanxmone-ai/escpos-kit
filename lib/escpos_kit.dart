/// Build ESC/POS receipts in pure Dart and send them to thermal printers.
///
/// ```dart
/// import 'package:escpos_kit/escpos_kit.dart';
///
/// final receipt = Receipt(paper: Paper.mm58)
///   ..text('HARBORLANE CAFE', align: PosAlign.center, bold: true)
///   ..row(['Flat white', '4.50'])
///   ..cut();
/// await NetworkPrinter('192.168.1.80').print(receipt);
/// ```
library;

export 'src/commands.dart'
    show
        BarcodeText,
        BarcodeType,
        Cut,
        Font,
        PosAlign,
        QrErrorLevel,
        TextSize,
        Underline;
export 'src/encoding.dart';
export 'src/image.dart';
export 'src/layout.dart' show autoWidths, layoutRow, textWidth, wrapText;
export 'src/network.dart';
export 'src/receipt.dart';
