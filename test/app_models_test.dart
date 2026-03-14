import 'package:bitsend/src/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiverInvitePayload', () {
    test('round-trips hotspot payloads through QR text', () {
      const ReceiverInvitePayload payload = ReceiverInvitePayload(
        chain: ChainKind.solana,
        transport: TransportKind.hotspot,
        address: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        displayAddress: '5g7h...Qk1Z',
        endpoint: 'http://192.168.1.22:8787',
      );

      final ReceiverInvitePayload parsed = ReceiverInvitePayload.fromQrData(
        payload.toQrData(),
      );

      expect(parsed.transport, TransportKind.hotspot);
      expect(parsed.address, payload.address);
      expect(parsed.displayAddress, payload.displayAddress);
      expect(parsed.endpoint, payload.endpoint);
    });
  });

  group('PendingTransfer helpers', () {
    test('keeps outbound funds reserved until settlement is finished', () {
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.sentOffline,
        ).reservesOfflineFunds,
        isTrue,
      );
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.broadcasting,
        ).reservesOfflineFunds,
        isTrue,
      );
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.broadcastSubmitted,
        ).reservesOfflineFunds,
        isTrue,
      );
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.broadcastFailed,
        ).reservesOfflineFunds,
        isTrue,
      );
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.confirmed,
        ).reservesOfflineFunds,
        isFalse,
      );
      expect(
        _transfer(
          direction: TransferDirection.inbound,
          status: TransferStatus.broadcastSubmitted,
        ).reservesOfflineFunds,
        isFalse,
      );
    });

    test('allows any device to broadcast pending signed transfers', () {
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.sentOffline,
        ).canBroadcast,
        isTrue,
      );
      expect(
        _transfer(
          direction: TransferDirection.inbound,
          status: TransferStatus.receivedPendingBroadcast,
        ).canBroadcast,
        isTrue,
      );
      expect(
        _transfer(
          direction: TransferDirection.outbound,
          status: TransferStatus.confirmed,
        ).canBroadcast,
        isFalse,
      );
    });
  });
}

PendingTransfer _transfer({
  required TransferDirection direction,
  required TransferStatus status,
}) {
  final DateTime now = DateTime(2026, 3, 14, 12);
  return PendingTransfer(
    transferId: 'transfer-${direction.name}-${status.name}',
    chain: ChainKind.solana,
    direction: direction,
    status: status,
    amountLamports: 250000000,
    senderAddress: 'Sender1111111111111111111111111111111111',
    receiverAddress: 'Receiver11111111111111111111111111111111',
    transport: TransportKind.ble,
    createdAt: now,
    updatedAt: now,
    envelope: OfflineEnvelope.create(
      transferId: 'transfer-${direction.name}-${status.name}',
      createdAt: now,
      chain: ChainKind.solana,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: 'Receiver11111111111111111111111111111111',
      amountLamports: 250000000,
      signedTransactionBase64: 'ZW5jb2RlZA==',
      transportKind: TransportKind.ble,
    ),
    transactionSignature: '5vzWQyrGExdHJ9pQxV7j1U8QGSoK8Vw1w2h4bB2ZvFQq1n3R9Y7',
  );
}
