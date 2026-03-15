import 'dart:convert';
import 'dart:io';

import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/fileverse_client_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishReceipt uses the longer publish timeout', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    server.listen((HttpRequest request) async {
      if (request.uri.path == '/v1/fileverse/session') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, String>{'sessionToken': 'test-session'}),
        );
        await request.response.close();
        return;
      }

      if (request.uri.path == '/v1/fileverse/receipts') {
        expect(request.headers.value('authorization'), 'Bearer test-session');
        await Future<void>.delayed(const Duration(milliseconds: 120));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'receiptId': 'ddoc-123',
            'receiptUrl': 'https://docs.fileverse.io/ddoc-123',
            'savedAt': '2026-03-15T02:30:00.000Z',
            'storageMode': 'fileverse',
            'message': 'Receipt details were saved to Fileverse.',
          }),
        );
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    final FileverseClientService service = FileverseClientService(
      endpoint: 'http://${server.address.host}:${server.port}',
      timeoutForPath: (String path) => path == '/v1/fileverse/receipts'
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 50),
    );

    await service.createSession();
    final FileverseReceiptSnapshot snapshot = await service.publishReceipt(
      transfer: _transfer(),
      receiptPngBase64:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnR6L8AAAAASUVORK5CYII=',
    );

    expect(snapshot.receiptId, 'ddoc-123');
    expect(snapshot.receiptUrl, 'https://docs.fileverse.io/ddoc-123');
    expect(snapshot.storageMode, 'fileverse');
  });
}

PendingTransfer _transfer() {
  final DateTime now = DateTime(2026, 3, 15, 2, 30);
  return PendingTransfer(
    transferId: 'fileverse-timeout-test',
    chain: ChainKind.solana,
    network: ChainNetwork.testnet,
    walletEngine: WalletEngine.local,
    direction: TransferDirection.outbound,
    status: TransferStatus.sentOffline,
    amountLamports: 1000,
    senderAddress: 'Sender1111111111111111111111111111111111',
    receiverAddress: 'Receiver11111111111111111111111111111111',
    transport: TransportKind.hotspot,
    createdAt: now,
    updatedAt: now,
  );
}
