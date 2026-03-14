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
    OfflineEnvelope? received;
    await service.start(
      onEnvelope: (OfflineEnvelope envelope) async {
        received = envelope;
        return const TransportReceiveResult(
          accepted: true,
          message: 'Stored successfully.',
        );
      },
    );

    final OfflineEnvelope envelope = _sampleEnvelope();
    await service.send(
      endpoint: Uri.parse('http://127.0.0.1:${HotspotTransportService.port}'),
      envelope: envelope,
    );

    expect(received?.transferId, envelope.transferId);
    expect(received?.receiverAddress, envelope.receiverAddress);
  });

  test('surfaces receiver rejection messages cleanly', () async {
    await service.start(
      onEnvelope: (_) async => const TransportReceiveResult(
        accepted: false,
        message: 'Signed transfer is not addressed to this wallet.',
      ),
    );

    expect(
      () => service.send(
        endpoint: Uri.parse('http://127.0.0.1:${HotspotTransportService.port}'),
        envelope: _sampleEnvelope(),
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
}

OfflineEnvelope _sampleEnvelope() {
  final DateTime createdAt = DateTime(2026, 3, 14, 12);
  return OfflineEnvelope.create(
    transferId: 'hotspot-test-transfer',
    createdAt: createdAt,
    senderAddress: 'Sender1111111111111111111111111111111111',
    receiverAddress: 'Receiver11111111111111111111111111111111',
    amountLamports: 250000000,
    signedTransactionBase64: 'ZW5jb2RlZA==',
    transportKind: TransportKind.hotspot,
  );
}
