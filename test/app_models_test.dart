import 'package:bitsend/src/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BitGoBackendHealth', () {
    test('parses backend mode labels from health payloads', () {
      final BitGoBackendHealth live = BitGoBackendHealth.fromJson(
        const <String, dynamic>{'ok': true, 'mode': 'live'},
      );
      final BitGoBackendHealth mock = BitGoBackendHealth.fromJson(
        const <String, dynamic>{'ok': true, 'mode': 'mock'},
      );

      expect(live.mode, BitGoBackendMode.live);
      expect(live.mode.isLive, isTrue);
      expect(mock.mode, BitGoBackendMode.mock);
      expect(mock.mode.label, 'Demo');
    });
  });

  group('ChainKind labels', () {
    test('keeps Base copy distinct from Ethereum', () {
      expect(ChainKind.base.shortLabel, 'Base ETH');
      expect(
        ChainKind.base.addressScopeNoteFor(ChainNetwork.testnet),
        contains('dedicated Base 0x address'),
      );
      expect(
        ChainKind.ethereum.addressScopeNoteFor(ChainNetwork.testnet),
        contains('dedicated Ethereum 0x address'),
      );
    });
  });

  group('BitGoWalletSummary', () {
    test('parses Base wallets from backend payloads', () {
      final BitGoWalletSummary wallet =
          BitGoWalletSummary.fromJson(const <String, dynamic>{
            'chain': 'base',
            'network': 'mainnet',
            'walletId': 'demo-base-mainnet',
            'address': '0x4444444444444444444444444444444444444444',
            'displayLabel': 'Demo Base ETH Mainnet',
            'balanceBaseUnits': '12000000000000000',
            'connectivityStatus': 'demo',
            'coin': 'baseeth',
          });

      expect(wallet.chain, ChainKind.base);
      expect(wallet.network, ChainNetwork.mainnet);
      expect(wallet.coin, 'baseeth');
      expect(wallet.balanceBaseUnits, 12000000000000000);
    });
  });

  group('ReceiverInvitePayload', () {
    test('round-trips hotspot payloads through QR text', () {
      const ReceiverInvitePayload payload = ReceiverInvitePayload(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
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

    test('parses Base Sepolia QR payloads', () {
      const ReceiverInvitePayload payload = ReceiverInvitePayload(
        chain: ChainKind.base,
        network: ChainNetwork.testnet,
        transport: TransportKind.ble,
        address: '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
        displayAddress: '0x7f6f...7161',
      );

      final ReceiverInvitePayload parsed = ReceiverInvitePayload.fromQrData(
        payload.toQrData(),
      );

      expect(parsed.chain, ChainKind.base);
      expect(parsed.network, ChainNetwork.testnet);
      expect(parsed.transport, TransportKind.ble);
      expect(parsed.address, payload.address);
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

    test('does not reserve offline funds for BitGo transfers', () {
      final PendingTransfer transfer = PendingTransfer(
        transferId: 'bitgo-outbound',
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        walletEngine: WalletEngine.bitgo,
        direction: TransferDirection.outbound,
        status: TransferStatus.broadcastSubmitted,
        amountLamports: 1000000000000000,
        senderAddress: '0x1111111111111111111111111111111111111111',
        receiverAddress: '0x2222222222222222222222222222222222222222',
        transport: TransportKind.hotspot,
        createdAt: DateTime(2026, 3, 14, 12),
        updatedAt: DateTime(2026, 3, 14, 12),
        bitgoWalletId: 'demo-wallet',
        bitgoTransferId: 'bitgo-transfer',
        backendStatus: 'submitted',
      );

      expect(transfer.reservesOfflineFunds, isFalse);
      expect(transfer.canBroadcast, isFalse);
    });

    test('round-trips Fileverse metadata through the DB map', () {
      final DateTime savedAt = DateTime(2026, 3, 14, 13, 45);
      final PendingTransfer original =
          _transfer(
            direction: TransferDirection.inbound,
            status: TransferStatus.receivedPendingBroadcast,
          ).copyWith(
            fileverseReceiptId: 'fv-receipt-1',
            fileverseReceiptUrl: 'https://fileverse.example/receipt/1',
            fileverseSavedAt: savedAt,
          );

      final PendingTransfer parsed = PendingTransfer.fromDbMap(
        original.toDbMap(),
      );

      expect(parsed.fileverseReceiptId, 'fv-receipt-1');
      expect(parsed.fileverseReceiptUrl, 'https://fileverse.example/receipt/1');
      expect(parsed.fileverseSavedAt, savedAt);
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
    network: ChainNetwork.testnet,
    walletEngine: WalletEngine.local,
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
      network: ChainNetwork.testnet,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: 'Receiver11111111111111111111111111111111',
      amountLamports: 250000000,
      signedTransactionBase64: 'ZW5jb2RlZA==',
      transportKind: TransportKind.ble,
    ),
    transactionSignature: '5vzWQyrGExdHJ9pQxV7j1U8QGSoK8Vw1w2h4bB2ZvFQq1n3R9Y7',
  );
}
