import 'receipt.dart';

/// Stand-in used on platforms without `dart:io` (the web), where raw TCP
/// sockets are not available. Building receipts still works there.
class NetworkPrinter {
  NetworkPrinter(
    this.host, {
    this.port = 9100,
    this.timeout = const Duration(seconds: 5),
  });

  final String host;
  final int port;
  final Duration timeout;

  Future<void> print(Receipt receipt) => send(receipt.bytes);

  Future<void> send(List<int> bytes) =>
      Future.error(UnsupportedError('NetworkPrinter needs dart:io'));
}
