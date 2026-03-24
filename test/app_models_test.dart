import 'dart:typed_data';

import 'package:bitsend/src/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BitGoBackendHealth', () {
    test('parses backend mode labels from health payloads', () {
      final BitGoBackendHealth live = BitGoBackendHealth.fromJson(
        const <String, dynamic>{
          'ok': true,
          'mode': 'live',
          'version': '2026.03.15.2',
        },
      );
      final BitGoBackendHealth mock = BitGoBackendHealth.fromJson(
        const <String, dynamic>{'ok': true, 'mode': 'mock'},
      );

      expect(live.mode, BitGoBackendMode.live);
      expect(live.mode.isLive, isTrue);
      expect(live.version, '2026.03.15.2');
      expect(mock.mode, BitGoBackendMode.mock);
      expect(mock.mode.label, 'Mock');
    });
  });

  group('ChainKind labels', () {
    test('keeps Base copy distinct from Ethereum', () {
      expect(ChainKind.base.shortLabel, 'Base ETH');
      expect(
        ChainKind.base.addressScopeNoteFor(ChainNetwork.testnet),
        contains('same address format'),
      );
      expect(
        ChainKind.ethereum.addressScopeNoteFor(ChainNetwork.testnet),
        contains('same address format'),
      );
    });

    test('adds BNB Chain and Polygon network copy', () {
      expect(ChainKind.bnb.shortLabel, 'BNB');
      expect(ChainNetwork.mainnet.labelFor(ChainKind.bnb), 'BNB Chain Mainnet');
      expect(
        ChainKind.bnb.addressScopeNoteFor(ChainNetwork.mainnet),
        contains('same address format'),
      );
      expect(ChainKind.polygon.shortLabel, 'POL');
      expect(ChainNetwork.testnet.shortLabelFor(ChainKind.polygon), 'Amoy');
      expect(
        ChainKind.polygon.addressScopeNoteFor(ChainNetwork.testnet),
        contains('same address format'),
      );
    });
  });

  group('trackedAssetsForScope', () {
    test('includes EURC on Ethereum Sepolia', () {
      final List<TrackedAssetDefinition> assets = trackedAssetsForScope(
        ChainKind.ethereum,
        ChainNetwork.testnet,
      );

      expect(
        assets.any(
          (TrackedAssetDefinition asset) =>
              asset.symbol == 'EURC' &&
              asset.contractAddress ==
                  '0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4',
        ),
        isTrue,
      );
    });

    test('includes native assets for BNB Chain and Polygon', () {
      final List<TrackedAssetDefinition> bnbAssets = trackedAssetsForScope(
        ChainKind.bnb,
        ChainNetwork.testnet,
      );
      final List<TrackedAssetDefinition> polygonAssets = trackedAssetsForScope(
        ChainKind.polygon,
        ChainNetwork.mainnet,
      );

      expect(
        bnbAssets.any(
          (TrackedAssetDefinition asset) =>
              asset.id == 'bnb:testnet:native' &&
              asset.symbol == 'BNB' &&
              asset.isNative,
        ),
        isTrue,
      );
      expect(
        polygonAssets.any(
          (TrackedAssetDefinition asset) =>
              asset.id == 'polygon:mainnet:native' &&
              asset.symbol == 'POL' &&
              asset.isNative,
        ),
        isTrue,
      );
    });

    test('includes BNB Chain mainnet USDT', () {
      final List<TrackedAssetDefinition> assets = trackedAssetsForScope(
        ChainKind.bnb,
        ChainNetwork.mainnet,
      );

      expect(
        assets.any(
          (TrackedAssetDefinition asset) =>
              asset.id == 'bnb:mainnet:usdt' &&
              asset.symbol == 'USDT' &&
              asset.contractAddress ==
                  '0x55d398326f99059fF775485246999027B3197955',
        ),
        isTrue,
      );
    });
  });

  group('Formatters.transferAmount', () {
    test('formats ERC-20 transfers with token symbols', () {
      const PendingTransfer transfer = PendingTransfer(
        transferId: 'token-transfer',
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        walletEngine: WalletEngine.local,
        direction: TransferDirection.outbound,
        status: TransferStatus.broadcastSubmitted,
        amountLamports: 1250000,
        senderAddress: '0x1111111111111111111111111111111111111111',
        receiverAddress: '0x2222222222222222222222222222222222222222',
        transport: TransportKind.online,
        createdAt: DateTime(2026, 3, 20, 10),
        updatedAt: DateTime(2026, 3, 20, 10),
        assetId: 'ethereum:testnet:eurc',
        assetSymbol: 'EURC',
        assetDisplayName: 'Euro Coin',
        assetDecimals: 6,
        assetContractAddress: '0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4',
        isNativeAsset: false,
      );

      expect(Formatters.transferAmount(transfer), '1.250 EURC');
    });

    test('formats tiny native balances as less than the visible threshold', () {
      expect(Formatters.asset(0.000009, ChainKind.bnb), 'BNB <0.0001');
      expect(Formatters.asset(0.000009, ChainKind.ethereum), 'Ξ<0.0001');
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

      final ReceiverInvitePayload parsed = ReceiverInvitePayload
          .fromPairCodeData(
        payload.toPairCodeData(),
      );

      expect(payload.toJson()['type'], ReceiverInvitePayload.type);
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

      final ReceiverInvitePayload parsed = ReceiverInvitePayload
          .fromPairCodeData(
        payload.toPairCodeData(),
      );

      expect(parsed.chain, ChainKind.base);
      expect(parsed.network, ChainNetwork.testnet);
      expect(parsed.transport, TransportKind.ble);
      expect(parsed.address, payload.address);
    });

    test('parses Polygon Amoy QR payloads', () {
      const ReceiverInvitePayload payload = ReceiverInvitePayload(
        chain: ChainKind.polygon,
        network: ChainNetwork.testnet,
        transport: TransportKind.hotspot,
        address: '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
        displayAddress: '0x7f6f...7161',
        endpoint: 'http://192.168.1.22:8787',
      );

      final ReceiverInvitePayload parsed = ReceiverInvitePayload
          .fromPairCodeData(
        payload.toPairCodeData(),
      );

      expect(parsed.chain, ChainKind.polygon);
      expect(parsed.network, ChainNetwork.testnet);
      expect(parsed.transport, TransportKind.hotspot);
      expect(parsed.endpoint, payload.endpoint);
    });

    test('round-trips ultrasonic payloads with session and relay fields', () {
      const ReceiverInvitePayload payload = ReceiverInvitePayload(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        transport: TransportKind.ultrasonic,
        address: '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
        displayAddress: '0x7f6f...7161',
        sessionToken: '00112233445566778899aabbccddeeff',
        relayId: 'relay-session-1',
      );

      final ReceiverInvitePayload parsed = ReceiverInvitePayload
          .fromPairCodeData(
        payload.toPairCodeData(),
      );

      expect(parsed.transport, TransportKind.ultrasonic);
      expect(parsed.sessionToken, payload.sessionToken);
      expect(parsed.relayId, payload.relayId);
    });

    test('accepts legacy version 1 receiver payloads', () {
      final ReceiverInvitePayload parsed = ReceiverInvitePayload
          .fromPairCodeData(
        '{"type":"bitsend.receiver","version":1,"chain":"solana","network":"solana-devnet","transport":"hotspot","address":"5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z","displayAddress":"5g7h...Qk1Z","endpoint":"http://192.168.1.22:8787"}',
      );

      expect(parsed.transport, TransportKind.hotspot);
      expect(parsed.endpoint, 'http://192.168.1.22:8787');
    });
  });

  group('SendDraft.hasReceiver', () {
    test('requires a session token for ultrasonic handoff', () {
      expect(
        const SendDraft(
          transport: TransportKind.ultrasonic,
          receiverAddress: '0x1111111111111111111111111111111111111111',
        ).hasReceiver,
        isFalse,
      );
      expect(
        const SendDraft(
          transport: TransportKind.ultrasonic,
          receiverAddress: '0x1111111111111111111111111111111111111111',
          receiverSessionToken: '00112233445566778899aabbccddeeff',
        ).hasReceiver,
        isTrue,
      );
    });
  });

  group('DirectTransferQrPayload', () {
    test('parses a plain Solana wallet QR', () {
      final DirectTransferQrPayload parsed = DirectTransferQrPayload.fromQrData(
        '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        preferredChain: ChainKind.solana,
        preferredNetwork: ChainNetwork.testnet,
      );

      expect(parsed.chain, ChainKind.solana);
      expect(parsed.network, ChainNetwork.testnet);
      expect(
        parsed.address,
        '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
      );
      expect(parsed.amount, isNull);
    });

    test('parses an Ethereum payment URI with value', () {
      final DirectTransferQrPayload parsed = DirectTransferQrPayload.fromQrData(
        'ethereum:0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161@11155111?value=125000000000000000&label=Alice',
        preferredChain: ChainKind.ethereum,
        preferredNetwork: ChainNetwork.mainnet,
      );

      expect(parsed.chain, ChainKind.ethereum);
      expect(parsed.network, ChainNetwork.testnet);
      expect(parsed.displayAddress, '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161');
      expect(parsed.amount, closeTo(0.125, 0.0000001));
      expect(parsed.label, 'Alice');
    });

    test('parses a Base payment URI and keeps the selected tier', () {
      final DirectTransferQrPayload parsed = DirectTransferQrPayload.fromQrData(
        'base:0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161?amount=2.5',
        preferredChain: ChainKind.ethereum,
        preferredNetwork: ChainNetwork.mainnet,
      );

      expect(parsed.chain, ChainKind.base);
      expect(parsed.network, ChainNetwork.mainnet);
      expect(parsed.amount, 2.5);
    });

    test('parses a BNB payment URI and resolves BSC chain id', () {
      final DirectTransferQrPayload parsed = DirectTransferQrPayload.fromQrData(
        'bsc:0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161@56?amount=1.25',
        preferredChain: ChainKind.ethereum,
        preferredNetwork: ChainNetwork.testnet,
      );

      expect(parsed.chain, ChainKind.bnb);
      expect(parsed.network, ChainNetwork.mainnet);
      expect(parsed.amount, 1.25);
    });

    test('parses a Polygon payment URI and resolves Amoy chain id', () {
      final DirectTransferQrPayload parsed = DirectTransferQrPayload.fromQrData(
        'polygon:0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161@80002?amount=3.5',
        preferredChain: ChainKind.ethereum,
        preferredNetwork: ChainNetwork.mainnet,
      );

      expect(parsed.chain, ChainKind.polygon);
      expect(parsed.network, ChainNetwork.testnet);
      expect(parsed.amount, 3.5);
    });
  });

  group('DappSignRequest', () {
    test('parses personal_sign requests from JSON payloads', () {
      final DappSignRequest request = DappSignRequest.fromJsonString(
        '{"method":"personal_sign","chainId":"0xaa36a7","origin":"app.uniswap.org","params":["0x68656c6c6f","0x1111111111111111111111111111111111111111"]}',
        preferredChain: ChainKind.ethereum,
        preferredNetwork: ChainNetwork.mainnet,
      );

      expect(request.method, DappRequestMethod.personalSign);
      expect(request.chain, ChainKind.ethereum);
      expect(request.network, ChainNetwork.testnet);
      expect(request.origin, 'app.uniswap.org');
      expect(request.message, 'hello');
    });

    test('parses eth_sendTransaction requests', () {
      final DappSignRequest request = DappSignRequest.fromJsonString(
        '{"method":"eth_sendTransaction","chainId":84532,"params":[{"to":"0x1111111111111111111111111111111111111111","value":"0xde0b6b3a7640000","data":"0x"}]}',
        preferredChain: ChainKind.ethereum,
        preferredNetwork: ChainNetwork.testnet,
      );

      expect(request.method, DappRequestMethod.sendTransaction);
      expect(request.chain, ChainKind.base);
      expect(request.network, ChainNetwork.testnet);
      expect(request.toAddress, '0x1111111111111111111111111111111111111111');
      expect(request.valueBaseUnits, 1000000000000000000);
    });
  });

  group('Ultrasonic packets', () {
    test('round-trips a compact transfer packet', () {
      final UltrasonicTransferPacket packet = UltrasonicTransferPacket.create(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        transferId: '123e4567-e89b-12d3-a456-426614174000',
        createdAt: DateTime.utc(2026, 3, 14, 12),
        sessionToken: '00112233445566778899aabbccddeeff',
        signedTransactionBytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      );

      final UltrasonicTransferPacket parsed = UltrasonicTransferPacket.fromBytes(
        packet.toBytes(),
      );

      expect(packet.isChecksumValid, isTrue);
      expect(parsed.transferId, packet.transferId);
      expect(parsed.sessionToken, packet.sessionToken);
      expect(parsed.signedTransactionBytes, orderedEquals(<int>[1, 2, 3, 4, 5]));
    });

    test('round-trips an acknowledgement packet', () {
      final UltrasonicAckPacket packet = UltrasonicAckPacket.create(
        transferId: '123e4567-e89b-12d3-a456-426614174000',
        sessionToken: '00112233445566778899aabbccddeeff',
        accepted: true,
      );

      final UltrasonicAckPacket parsed = UltrasonicAckPacket.fromBytes(
        packet.toBytes(),
      );

      expect(parsed.isChecksumValid, isTrue);
      expect(parsed.transferId, packet.transferId);
      expect(parsed.sessionToken, packet.sessionToken);
      expect(parsed.accepted, isTrue);
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

  group('OfflineVoucherPayment', () {
    test('creates a deterministic tx id from voucher content', () {
      const OfflineVoucherLeaf voucher = OfflineVoucherLeaf(
        version: 1,
        escrowId: 'escrow-1',
        voucherId: 'voucher-1',
        amountBaseUnits: '1250000',
        expiryAt: DateTime.utc(2026, 3, 21, 18),
        nonce: 'nonce-1',
        receiverAddress: '0x1111111111111111111111111111111111111111',
      );
      const OfflineVoucherProofBundle proofBundle = OfflineVoucherProofBundle(
        version: 1,
        escrowId: 'escrow-1',
        voucherId: 'voucher-1',
        voucherRoot: 'voucher-root',
        voucherProof: <String>['node-a', 'node-b'],
        escrowStateRoot: 'state-root',
        escrowProof: <String>['root-a'],
        finalizedAt: DateTime.utc(2026, 3, 21, 12),
        proofWindowExpiresAt: DateTime.utc(2026, 3, 22, 12),
      );

      final OfflineVoucherPayment first = OfflineVoucherPayment.create(
        voucher: voucher,
        proofBundle: proofBundle,
        senderAddress: '0x2222222222222222222222222222222222222222',
        senderSignature: 'signature-1',
        transportHint: 'ble',
        createdAt: DateTime.utc(2026, 3, 21, 12, 30),
      );
      final OfflineVoucherPayment second = OfflineVoucherPayment.create(
        voucher: voucher,
        proofBundle: proofBundle,
        senderAddress: '0x2222222222222222222222222222222222222222',
        senderSignature: 'signature-1',
        transportHint: 'ble',
        createdAt: DateTime.utc(2026, 3, 21, 12, 30),
      );

      expect(first.txId, isNotEmpty);
      expect(second.txId, first.txId);
    });
  });

  group('OfflineVoucherClaimSubmission', () {
    test('round-trips through json', () {
      const OfflineVoucherClaimSubmission claim =
          OfflineVoucherClaimSubmission(
            version: 1,
            voucherId: 'voucher-1',
            txId: 'tx-1',
            escrowId: 'escrow-1',
            claimerAddress: '0x3333333333333333333333333333333333333333',
            createdAt: DateTime.utc(2026, 3, 21, 13),
          );

      final OfflineVoucherClaimSubmission parsed =
          OfflineVoucherClaimSubmission.fromJson(claim.toJson());

      expect(parsed.voucherId, claim.voucherId);
      expect(parsed.txId, claim.txId);
      expect(parsed.escrowId, claim.escrowId);
      expect(parsed.claimerAddress, claim.claimerAddress);
      expect(parsed.createdAt, claim.createdAt);
    });
  });

  group('OfflineVoucherClaimAttempt', () {
    test('round-trips queued claim metadata through json', () {
      final OfflineVoucherClaimAttempt original = OfflineVoucherClaimAttempt(
        version: 1,
        transferId: 'transfer-1',
        voucherId: 'voucher-1',
        txId: 'tx-1',
        escrowId: 'escrow-1',
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        accountSlot: 2,
        claimerAddress: '0x3333333333333333333333333333333333333333',
        settlementContractAddress:
            '0x4444444444444444444444444444444444444444',
        voucher: const OfflineVoucherLeaf(
          version: 1,
          escrowId: 'escrow-1',
          voucherId: 'voucher-1',
          amountBaseUnits: '1250000',
          expiryAt: DateTime.utc(2026, 3, 22, 12),
          nonce: '0x1234',
        ),
        assignmentSignatureHex: '0xabcd',
        voucherProof: const <String>['0xaaa', '0xbbb'],
        status: OfflineVoucherClaimStatus.submittedOnchain,
        submissionMode: OfflineVoucherClaimSubmissionMode.receiver,
        queuedAt: DateTime.utc(2026, 3, 21, 13),
        nextAttemptAt: DateTime.utc(2026, 3, 21, 13, 1),
        attemptCount: 2,
        lastAttemptedAt: DateTime.utc(2026, 3, 21, 13),
        submittedTransactionHash: '0xdeadbeef',
        sponsoredFallbackRequested: true,
        lastError: 'rpc timeout',
      );

      final OfflineVoucherClaimAttempt parsed =
          OfflineVoucherClaimAttempt.fromJson(original.toJson());

      expect(parsed.transferId, original.transferId);
      expect(parsed.voucherId, original.voucherId);
      expect(parsed.chain, ChainKind.ethereum);
      expect(parsed.accountSlot, 2);
      expect(
        parsed.submissionMode,
        OfflineVoucherClaimSubmissionMode.receiver,
      );
      expect(parsed.submittedTransactionHash, '0xdeadbeef');
      expect(parsed.sponsoredFallbackRequested, isTrue);
      expect(parsed.voucher.nonce, '0x1234');
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
