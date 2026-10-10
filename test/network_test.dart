import 'dart:async';
import 'dart:io';

import 'package:escpos_kit/escpos_kit.dart';
import 'package:test/test.dart';

void main() {
  test('sends the receipt bytes over TCP', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final received = Completer<List<int>>();
    server.listen((client) async {
      final data = <int>[];
      await client.forEach(data.addAll);
      await client.close();
      received.complete(data);
    });

    final receipt = Receipt()
      ..text('港湾咖啡', align: PosAlign.center)
      ..cut();
    await NetworkPrinter('127.0.0.1', port: server.port).print(receipt);

    expect(await received.future.timeout(const Duration(seconds: 5)), receipt.bytes);
  });

  test('reports a printer that is not listening', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    expect(
      NetworkPrinter('127.0.0.1', port: port, timeout: const Duration(seconds: 2)).send([0x1B, 0x40]),
      throwsA(isA<SocketException>()),
    );
  });
}
