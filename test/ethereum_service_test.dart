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

    test('round-trips a signed BNB Chain testnet transfer envelope', () async {
      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://localhost:8545',
      )
        ..chain = ChainKind.bnb
        ..network = ChainNetwork.testnet;
      final EthPrivateKey sender = EthPrivateKey.fromInt(BigInt.from(10));
      final String senderAddress = (await sender.extractAddress()).hexEip55;
      final String receiverAddress =
          (await EthPrivateKey.fromInt(BigInt.from(11)).extractAddress())
              .hexEip55;

      final OfflineEnvelope envelope = await service.createSignedEnvelope(
        sender: sender,
        senderAddress: senderAddress,
        receiverAddress: receiverAddress,
        amountBaseUnits: BigInt.from(9100000000000000).toInt(),
        preparedContext: const EthereumPreparedContext(
          nonce: 5,
          gasPriceWei: 1200000000,
          chainId: EthereumService.bnbTestnetChainId,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'bnb-transfer-test',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.hotspot,
      );

      final ValidatedTransactionDetails details = service.validateEnvelope(
        envelope,
      );

      expect(details.chain, ChainKind.bnb);
      expect(details.network, ChainNetwork.testnet);
      expect(details.senderAddress, senderAddress);
      expect(details.receiverAddress, receiverAddress);
      expect(details.amountLamports, BigInt.from(9100000000000000).toInt());
      expect(
        service.explorerUrlFor(details.transactionSignature).host,
        'testnet.bscscan.com',
      );
    });

    test('round-trips a signed Polygon Amoy transfer envelope', () async {
      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://localhost:8545',
      )
        ..chain = ChainKind.polygon
        ..network = ChainNetwork.testnet;
      final EthPrivateKey sender = EthPrivateKey.fromInt(BigInt.from(12));
      final String senderAddress = (await sender.extractAddress()).hexEip55;
      final String receiverAddress =
          (await EthPrivateKey.fromInt(BigInt.from(13)).extractAddress())
              .hexEip55;

      final OfflineEnvelope envelope = await service.createSignedEnvelope(
        sender: sender,
        senderAddress: senderAddress,
        receiverAddress: receiverAddress,
        amountBaseUnits: BigInt.from(8300000000000000).toInt(),
        preparedContext: const EthereumPreparedContext(
          nonce: 7,
          gasPriceWei: 1300000000,
          chainId: EthereumService.polygonAmoyChainId,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'polygon-transfer-test',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.ble,
      );

      final ValidatedTransactionDetails details = service.validateEnvelope(
        envelope,
      );

      expect(details.chain, ChainKind.polygon);
      expect(details.network, ChainNetwork.testnet);
      expect(details.senderAddress, senderAddress);
      expect(details.receiverAddress, receiverAddress);
      expect(details.amountLamports, BigInt.from(8300000000000000).toInt());
      expect(
        service.explorerUrlFor(details.transactionSignature).host,
        'amoy.polygonscan.com',
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

  group('EthereumService.getTokenBalanceBaseUnits', () {
    test('reads an ERC-20 balance with eth_call', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        expect(payload['method'], 'eth_call');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result':
                '0x0000000000000000000000000000000000000000000000000000000007735940',
          }),
        );
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.address}:${server.port}',
      )
        ..chain = ChainKind.ethereum
        ..network = ChainNetwork.testnet;

      final int balance = await service.getTokenBalanceBaseUnits(
        ownerAddress: '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
        contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
      );

      expect(balance, 125000000);
    });
  });

  group('EthereumService.getTokenAllowanceBaseUnits', () {
    test('reads an ERC-20 allowance with eth_call', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        expect(payload['method'], 'eth_call');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result':
                '0x00000000000000000000000000000000000000000000000000000000000f4240',
          }),
        );
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.address}:${server.port}',
      )
        ..chain = ChainKind.ethereum
        ..network = ChainNetwork.testnet;

      final int allowance = await service.getTokenAllowanceBaseUnits(
        ownerAddress: '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
        spenderAddress: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
      );

      expect(allowance, 1000000);
    });
  });

  group('EthereumService.estimateTokenTransferGas', () {
    test('estimates ERC-20 transfer gas with eth_estimateGas', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        expect(payload['method'], 'eth_estimateGas');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result': '0xccc0',
          }),
        );
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.address}:${server.port}',
      )
        ..chain = ChainKind.ethereum
        ..network = ChainNetwork.testnet;

      final int gas = await service.estimateTokenTransferGas(
        senderAddress: '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161',
        receiverAddress: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4',
        amountBaseUnits: 1250000,
      );

      expect(gas, 52416);
    });
  });

  group('EthereumService ERC-20 discovery', () {
    test('discovers ERC-20 contracts from transfer logs', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      const String owner = '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161';
      const String incomingToken = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238';
      const String outgoingToken = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        if (payload['method'] == 'eth_blockNumber') {
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': '0x64',
            }),
          );
        } else if (payload['method'] == 'eth_getLogs') {
          final Map<String, dynamic> filter =
              (payload['params'] as List<dynamic>).single
                  as Map<String, dynamic>;
          final List<dynamic> topics = filter['topics'] as List<dynamic>;
          final bool incoming = topics.length >= 3 && topics[2] != null;
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': incoming
                  ? <Map<String, String>>[
                      <String, String>{'address': incomingToken},
                    ]
                  : <Map<String, String>>[
                      <String, String>{'address': outgoingToken},
                    ],
            }),
          );
        } else {
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': const <Object?>[],
            }),
          );
        }
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.address}:${server.port}',
      )
        ..chain = ChainKind.ethereum
        ..network = ChainNetwork.testnet;

      final Set<String> contracts = await service.discoverErc20Contracts(
        ownerAddress: owner,
        fromBlock: 0,
        toBlock: 100,
        chunkSize: 200,
      );

      expect(contracts, containsAll(<String>[incomingToken, outgoingToken]));
    });

    test('describes ERC-20 metadata from contract calls', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        final Map<String, dynamic> call =
            ((payload['params'] as List<dynamic>).first as Map<String, dynamic>);
        final String data = (call['data'] as String).toLowerCase();
        request.response.headers.contentType = ContentType.json;
        final String result = switch (data.substring(0, 10)) {
          '0x95d89b41' => _encodedBytes32String('EURC'),
          '0x06fdde03' => _encodedBytes32String('Euro Coin'),
          '0x313ce567' => _encodedUintWord(6),
          _ => '0x',
        };
        request.response.write(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result': result,
          }),
        );
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.address}:${server.port}',
      )
        ..chain = ChainKind.ethereum
        ..network = ChainNetwork.testnet;

      final TrackedAssetDefinition asset = await service.describeErc20Asset(
        '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
      );

      expect(asset.symbol, 'EURC');
      expect(asset.displayName, 'Euro Coin');
      expect(asset.decimals, 6);
      expect(
        asset.contractAddress,
        '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
      );
    });
  });

  group('EthereumService ERC-721 discovery', () {
    test('discovers ERC-721 holdings from transfer logs', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      const String owner = '0x7f6fB8965F10E6F5463cd5C6c60008E64Ca07161';
      const String contract = '0x9999999999999999999999999999999999999999';
      server.listen((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> payload =
            jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        if (payload['method'] == 'eth_getLogs') {
          final Map<String, dynamic> filter =
              (payload['params'] as List<dynamic>).single
                  as Map<String, dynamic>;
          final List<dynamic> topics = filter['topics'] as List<dynamic>;
          final bool incoming = topics.length >= 3 && topics[2] != null;
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': incoming
                  ? <Map<String, Object?>>[
                      <String, Object?>{
                        'address': contract,
                        'topics': <String>[
                          '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
                          '0x000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                          '0x0000000000000000000000007f6fb8965f10e6f5463cd5c6c60008e64ca07161',
                          '0x000000000000000000000000000000000000000000000000000000000000002a',
                        ],
                      },
                    ]
                  : <Object?>[],
            }),
          );
        } else if (payload['method'] == 'eth_call') {
          final Map<String, dynamic> call =
              ((payload['params'] as List<dynamic>).first as Map<String, dynamic>);
          final String data = (call['data'] as String).toLowerCase();
          final String result = switch (data.substring(0, 10)) {
            '0x01ffc9a7' => _encodedUintWord(1),
            '0x06fdde03' => _encodedBytes32String('Demo Collection'),
            '0x95d89b41' => _encodedBytes32String('DEMO'),
            '0x6352211e' =>
              _encodedAddressWord(owner),
            '0xc87b56dd' => _encodedDynamicString('ipfs://demo/42'),
            _ => '0x',
          };
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': result,
            }),
          );
        } else {
          request.response.write(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': '0x64',
            }),
          );
        }
        await request.response.close();
      });

      final EthereumService service = EthereumService(
        rpcEndpoint: 'http://${server.address.address}:${server.port}',
      )
        ..chain = ChainKind.ethereum
        ..network = ChainNetwork.testnet;

      final List<NftHolding> holdings = await service.discoverErc721Holdings(
        ownerAddress: owner,
        fromBlock: 0,
        toBlock: 100,
        chunkSize: 200,
      );

      expect(holdings, hasLength(1));
      expect(holdings.single.collectionName, 'Demo Collection');
      expect(holdings.single.symbol, 'DEMO');
      expect(holdings.single.tokenId, '42');
      expect(holdings.single.tokenUri, 'ipfs://demo/42');
    });
  });
}

String _encodedAddressWord(String address) {
  return '0x${'0' * 24}${address.substring(2).toLowerCase()}';
}

String _encodedUintWord(int value) {
  return '0x${value.toRadixString(16).padLeft(64, '0')}';
}

String _encodedBytes32String(String value) {
  final String hexValue = utf8
      .encode(value)
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '0x${hexValue.padRight(64, '0')}';
}

String _encodedDynamicString(String value) {
  final String dataHex = utf8
      .encode(value)
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  final String paddedData = dataHex.padRight(((dataHex.length + 63) ~/ 64) * 64, '0');
  return '0x'
      '${(32).toRadixString(16).padLeft(64, '0')}'
      '${(value.length).toRadixString(16).padLeft(64, '0')}'
      '$paddedData';
}
