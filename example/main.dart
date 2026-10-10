// Prints a sample receipt.
//
//   dart run example/main.dart 192.168.1.80   # send to a network printer
//   dart run example/main.dart                # write the bytes to receipt.bin
import 'dart:io';

import 'package:escpos_kit/escpos_kit.dart';

Future<void> main(List<String> args) async {
  final receipt = Receipt(paper: Paper.mm58)
    ..text('HARBORLANE CAFE',
        align: PosAlign.center, bold: true, size: TextSize.large)
    ..text('12 Harbour Road', align: PosAlign.center)
    ..divider()
    ..row(['Flat white', '4.50'])
    ..row(['Banana bread with walnuts', '3.20'])
    ..row(['拿铁 Latte', '5.00'])
    ..divider()
    ..row(['TOTAL', '12.70'], bold: true)
    ..feed()
    ..barcode('ORDER-1042', height: 60)
    ..qr('https://example.com/r/1042')
    ..text('Thank you!', align: PosAlign.center)
    ..cut();

  if (args.isEmpty) {
    File('receipt.bin').writeAsBytesSync(receipt.bytes);
    stdout.writeln('Wrote ${receipt.bytes.length} bytes to receipt.bin');
    return;
  }
  await NetworkPrinter(args.first).print(receipt);
  stdout.writeln('Sent to ${args.first}:9100');
}
