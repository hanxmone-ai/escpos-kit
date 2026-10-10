import 'dart:async';
import 'dart:io';

import 'receipt.dart';

/// A printer on the local network that accepts raw ESC/POS on a TCP port,
/// usually 9100 ("RAW" or "JetDirect" printing).
class NetworkPrinter {
  NetworkPrinter(
    this.host, {
    this.port = 9100,
    this.timeout = const Duration(seconds: 5),
  });

  final String host;
  final int port;

  /// Limit for connecting and for sending.
  final Duration timeout;

  /// Prints [receipt].
  Future<void> print(Receipt receipt) => send(receipt.bytes);

  /// Opens a connection, writes [bytes] and closes it.
  ///
  /// Throws a [SocketException] when the printer cannot be reached and a
  /// [TimeoutException] when it stops accepting data.
  Future<void> send(List<int> bytes) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.add(bytes);
      await socket.flush().timeout(timeout);
      await socket.close().timeout(timeout, onTimeout: () => null);
    } finally {
      socket.destroy();
    }
  }
}
