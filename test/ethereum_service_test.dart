import 'dart:convert';
import 'dart:io';

import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/ethereum_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  group('EthereumService.validateEnvelope', () {
    test('round-trips a signed Sepolia transfer envelope', () async {
      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://localhost:8545',
      )..network = ChainNetwork.testnet;
      final EthPrivateKey sender = EthPrivateKey.fromInt(BigInt.one);
      final String senderAddress = (await sender.extractAddress()).hexEip55;
      final String receiverAddress =
          (await EthPrivateKey.fromInt(BigInt.two).extractAddress()).hexEip55;

      final OfflineEnvelope envelope = await service.createSignedEnvelope(
        sender: sender,
        senderAddress: senderAddress,
        receiverAddress: receiverAddress,
        amountBaseUnits: BigInt.from(15000000000000000).toInt(),
        preparedContext: const EthereumPreparedContext(
          nonce: 4,
          gasPriceWei: 2000000000,
          chainId: EthereumService.sepoliaChainId,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'eth-transfer-test',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.hotspot,
      );

      final ValidatedTransactionDetails details = service.validateEnvelope(
        envelope,
      );

      expect(details.chain, ChainKind.ethereum);
      expect(details.network, ChainNetwork.testnet);
      expect(details.senderAddress, senderAddress);
      expect(details.receiverAddress, receiverAddress);
      expect(details.amountLamports, BigInt.from(15000000000000000).toInt());
      expect(details.transactionSignature, startsWith('0x'));
    });

    test('round-trips a signed Base Sepolia transfer envelope', () async {
      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://localhost:8545',
      )
        ..chain = ChainKind.base
        ..network = ChainNetwork.testnet;
      final EthPrivateKey sender = EthPrivateKey.fromInt(BigInt.from(6));
      final String senderAddress = (await sender.extractAddress()).hexEip55;
      final String receiverAddress =
          (await EthPrivateKey.fromInt(BigInt.from(7)).extractAddress())
              .hexEip55;

      final OfflineEnvelope envelope = await service.createSignedEnvelope(
        sender: sender,
        senderAddress: senderAddress,
        receiverAddress: receiverAddress,
        amountBaseUnits: BigInt.from(7000000000000000).toInt(),
        preparedContext: const EthereumPreparedContext(
          nonce: 3,
          gasPriceWei: 1500000000,
          chainId: EthereumService.baseSepoliaChainId,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'base-transfer-test',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.hotspot,
      );

      final ValidatedTransactionDetails details = service.validateEnvelope(
        envelope,
      );

      expect(details.chain, ChainKind.base);
      expect(details.network, ChainNetwork.testnet);
      expect(details.senderAddress, senderAddress);
      expect(details.receiverAddress, receiverAddress);
      expect(details.amountLamports, BigInt.from(7000000000000000).toInt());
      expect(
        service.explorerUrlFor(details.transactionSignature).host,
        'sepolia.basescan.org',
      );
    });

    test('validates raw signed transaction bytes', () async {
      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://localhost:8545',
      )..network = ChainNetwork.testnet;
      final EthPrivateKey sender = EthPrivateKey.fromInt(BigInt.from(8));
      final String senderAddress = (await sender.extractAddress()).hexEip55;
      final String receiverAddress =
          (await EthPrivateKey.fromInt(BigInt.from(9)).extractAddress())
              .hexEip55;

      final OfflineEnvelope envelope = await service.createSignedEnvelope(
        sender: sender,
        senderAddress: senderAddress,
        receiverAddress: receiverAddress,
        amountBaseUnits: BigInt.from(3100000000000000).toInt(),
        preparedContext: const EthereumPreparedContext(
          nonce: 2,
          gasPriceWei: 2000000000,
          chainId: EthereumService.sepoliaChainId,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'eth-bytes-test',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.ultrasonic,
      );

      final ValidatedTransactionDetails details =
          service.validateSignedTransactionBytes(
            base64Decode(envelope.signedTransactionBase64),
          );

      expect(details.senderAddress, senderAddress);
      expect(details.receiverAddress, receiverAddress);
      expect(details.amountLamports, BigInt.from(3100000000000000).toInt());
      expect(details.transactionSignature, startsWith('0x'));
    });

    test('rejects a tampered receiver even when checksum is recomputed', () async {
      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://localhost:8545',
      )..network = ChainNetwork.testnet;
      final EthPrivateKey sender = EthPrivateKey.fromInt(BigInt.from(3));
      final String senderAddress = (await sender.extractAddress()).hexEip55;
      final String receiverAddress =
          (await EthPrivateKey.fromInt(BigInt.from(4)).extractAddress())
              .hexEip55;
      final String fakeReceiver =
          (await EthPrivateKey.fromInt(BigInt.from(5)).extractAddress())
              .hexEip55;

      final OfflineEnvelope envelope = await service.createSignedEnvelope(
        sender: sender,
        senderAddress: senderAddress,
        receiverAddress: receiverAddress,
        amountBaseUnits: BigInt.from(4200000000000000).toInt(),
        preparedContext: const EthereumPreparedContext(
          nonce: 1,
          gasPriceWei: 3000000000,
          chainId: EthereumService.sepoliaChainId,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'eth-transfer-tamper',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.ble,
      );

      final OfflineEnvelope tamperedUnsigned = OfflineEnvelope(
        version: envelope.version,
        chain: envelope.chain,
        network: envelope.network,
        transferId: envelope.transferId,
        createdAt: envelope.createdAt,
        senderAddress: envelope.senderAddress,
        receiverAddress: fakeReceiver,
        amountLamports: envelope.amountLamports,
        signedTransactionBase64: envelope.signedTransactionBase64,
        transportHint: envelope.transportHint,
        integrityChecksum: '',
      );
      final OfflineEnvelope tampered = OfflineEnvelope(
        version: tamperedUnsigned.version,
        chain: tamperedUnsigned.chain,
        network: tamperedUnsigned.network,
        transferId: tamperedUnsigned.transferId,
        createdAt: tamperedUnsigned.createdAt,
        senderAddress: tamperedUnsigned.senderAddress,
        receiverAddress: tamperedUnsigned.receiverAddress,
        amountLamports: tamperedUnsigned.amountLamports,
        signedTransactionBase64: tamperedUnsigned.signedTransactionBase64,
        transportHint: tamperedUnsigned.transportHint,
        integrityChecksum: tamperedUnsigned.computeChecksum(),
      );

      expect(
        () => service.validateEnvelope(tampered),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('Envelope receiver does not match'),
          ),
        ),
      );
    });
  });

  group('EthereumService.getTransactionReceipt', () {
    test('parses hex receipt fields from JSON-RPC correctly', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        expect(payload['method'], 'eth_getTransactionReceipt');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result': <String, Object?>{
              'transactionHash':
                  '0x959304811983768a6fd119399d731ebdc08d0e19b11b3f0a0000000000000000',
              'transactionIndex': '0x2',
              'blockHash':
                  '0x1111111111111111111111111111111111111111111111111111111111111111',
              'blockNumber': '0x10',
              'from': '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
              'to': '0x2B5AD5c4795c026514f8317c7a215E218dcCD6cF',
              'cumulativeGasUsed': '0x5208',
              'gasUsed': '0x5208',
              'effectiveGasPrice': '0x77359400',
              'status': '0x1',
              'logs': <Object?>[],
            },
          }),
        );
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.host}:${server.port}',
      )..network = ChainNetwork.testnet;

      final TransactionReceipt? receipt = await service.getTransactionReceipt(
        '0x959304811983768a6fd119399d731ebdc08d0e19b11b3f0a0000000000000000',
      );

      expect(receipt, isNotNull);
      expect(receipt!.status, isTrue);
      expect(receipt.blockNumber, const BlockNum.exact(16));
      expect(receipt.transactionIndex, 2);
      expect(receipt.cumulativeGasUsed, BigInt.from(21000));
      expect(receipt.effectiveGasPrice?.getInWei, BigInt.from(2000000000));
      expect(
        receipt.from?.hexEip55,
        '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
      );
      expect(
        receipt.to?.hexEip55,
        '0x2B5AD5c4795c026514f8317c7a215E218dcCD6cF',
      );
    });
  });

  group('EthereumService.resolveEnsAddress', () {
    test('resolves an ENS name through registry and resolver calls', () async {
      const String resolverAddress = '0x1111111111111111111111111111111111111111';
      const String resolvedAddress = '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161';
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      int ethCallCount = 0;
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        if (payload['method'] == 'eth_call') {
          ethCallCount += 1;
          final Map<String, dynamic> call =
              (payload['params'] as List<dynamic>).first as Map<String, dynamic>;
          if (ethCallCount == 1) {
            expect(
              (call['to'] as String).toLowerCase(),
              '0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e',
            );
            request.response.write(
              jsonEncode(<String, Object?>{
                'jsonrpc': '2.0',
                'id': payload['id'],
                'result': _encodedAddressWord(resolverAddress),
              }),
            );
          } else {
            expect((call['to'] as String).toLowerCase(), resolverAddress);
            request.response.write(
              jsonEncode(<String, Object?>{
                'jsonrpc': '2.0',
                'id': payload['id'],
                'result': _encodedAddressWord(resolvedAddress),
              }),
            );
          }
        } else {
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': null,
            }),
          );
        }
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.host}:${server.port}',
      )..network = ChainNetwork.mainnet;

      final String resolved = await service.resolveEnsAddress('Alice.eth');

      expect(resolved, resolvedAddress);
      expect(ethCallCount, 2);
    });
  });
}

String _encodedAddressWord(String address) {
  return '0x${'0' * 24}${address.substring(2).toLowerCase()}';
}
