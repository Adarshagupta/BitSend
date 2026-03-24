import 'dart:io';

import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/hotspot_transport_service.dart';
import 'package:bitsend/src/services/transport_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HotspotTransportService service;

  setUp(() {
    service = HotspotTransportService();
  });

  tearDown(() async {
    await service.stop();
  });

  test('delivers an envelope to a listening hotspot receiver', () async {
    OfflineTransportPayload? received;
    await service.start(
      onPayload: (OfflineTransportPayload payload) async {
        received = payload;
        return const TransportReceiveResult(
          accepted: true,
          message: 'Stored successfully.',
        );
      },
    );

    final OfflineEnvelope envelope = _sampleEnvelope();
    await service.send(
      endpoint: Uri.parse('http://127.0.0.1:${HotspotTransportService.port}'),
      payload: OfflineTransportPayload.envelope(envelope),
    );

    expect(received?.envelope?.transferId, envelope.transferId);
    expect(received?.envelope?.receiverAddress, envelope.receiverAddress);
  });

  test('surfaces receiver rejection messages cleanly', () async {
    await service.start(
      onPayload: (_) async => const TransportReceiveResult(
        accepted: false,
        message: 'Signed transfer is not addressed to this wallet.',
      ),
    );

    expect(
      () => service.send(
        endpoint: Uri.parse('http://127.0.0.1:${HotspotTransportService.port}'),
        payload: OfflineTransportPayload.envelope(_sampleEnvelope()),
      ),
      throwsA(
        isA<HttpException>().having(
          (HttpException error) => error.message,
          'message',
          contains('Signed transfer is not addressed to this wallet.'),
        ),
      ),
    );
  });

  test('maps connection refused into a receiver-not-listening message', () async {
    expect(
      () => service.send(
        endpoint: Uri.parse('http://127.0.0.1:1'),
        payload: OfflineTransportPayload.envelope(_sampleEnvelope()),
      ),
      throwsA(
        isA<HttpException>().having(
          (HttpException error) => error.message,
          'message',
          contains('Receiver is not listening on hotspot yet.'),
        ),
      ),
    );
  });
}

OfflineEnvelope _sampleEnvelope() {
  final DateTime createdAt = DateTime(2026, 3, 14, 12);
  return OfflineEnvelope.create(
    transferId: 'hotspot-test-transfer',
    createdAt: createdAt,
    chain: ChainKind.solana,
    network: ChainNetwork.testnet,
    senderAddress: 'Sender1111111111111111111111111111111111',
    receiverAddress: 'Receiver11111111111111111111111111111111',
    amountLamports: 250000000,
    signedTransactionBase64: 'ZW5jb2RlZA==',
    transportKind: TransportKind.hotspot,
  );
}
