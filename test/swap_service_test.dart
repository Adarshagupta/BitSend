import 'dart:convert';

import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/swap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SwapService', () {
    test('fetchPrice sends 0x headers and parses allowance quotes', () async {
      late http.Request capturedRequest;
      final SwapService service = SwapService(
        apiKey: 'test-0x-key',
        client: MockClient((http.Request request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'sellToken': '0x1111111111111111111111111111111111111111',
              'buyToken': '0x2222222222222222222222222222222222222222',
              'sellAmount': '1000000',
              'buyAmount': '995000',
              'minBuyAmount': '985000',
              'liquidityAvailable': true,
              'totalNetworkFee': '1200',
              'fees': <String, dynamic>{
                'zeroExFee': <String, dynamic>{
                  'amount': '25',
                  'token': '0x1111111111111111111111111111111111111111',
                  'type': 'volume',
                },
              },
              'issues': <String, dynamic>{
                'allowance': <String, dynamic>{
                  'actual': '0',
                  'spender': '0x3333333333333333333333333333333333333333',
                },
              },
              'route': <String, dynamic>{
                'fills': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'from': '0x1111111111111111111111111111111111111111',
                    'to': '0x2222222222222222222222222222222222222222',
                    'source': 'PancakeSwap_V2',
                    'proportionBps': '10000',
                  },
                ],
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      final SwapQuote quote = await service.fetchPrice(
        chainId: 56,
        sellTokenAddress: '0x1111111111111111111111111111111111111111',
        buyTokenAddress: '0x2222222222222222222222222222222222222222',
        sellAmountBaseUnits: 1000000,
        takerAddress: '0x4444444444444444444444444444444444444444',
        slippageBps: 100,
      );

      expect(capturedRequest.headers['0x-api-key'], 'test-0x-key');
      expect(capturedRequest.headers['0x-version'], 'v2');
      expect(capturedRequest.url.path, '/swap/allowance-holder/price');
      expect(capturedRequest.url.queryParameters['chainId'], '56');
      expect(capturedRequest.url.queryParameters['slippageBps'], '100');
      expect(quote.isFirmQuote, isFalse);
      expect(quote.requiresAllowance, isTrue);
      expect(quote.allowanceIssue?.spenderAddress,
          '0x3333333333333333333333333333333333333333');
      expect(quote.routeFills.single.source, 'PancakeSwap_V2');
      expect(quote.totalNetworkFeeBaseUnits, 1200);
      expect(quote.zeroExFee?.amountBaseUnits, 25);
    });

    test('fetchQuote parses executable transaction payloads', () async {
      final SwapService service = SwapService(
        apiKey: 'test-0x-key',
        client: MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'sellToken': SwapService.nativeTokenAddress,
              'buyToken': '0x2222222222222222222222222222222222222222',
              'sellAmount': '100000000000000000',
              'buyAmount': '250000',
              'minBuyAmount': '247500',
              'liquidityAvailable': true,
              'route': <String, dynamic>{
                'fills': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'from': SwapService.nativeTokenAddress,
                    'to': '0x2222222222222222222222222222222222222222',
                    'source': 'Uniswap_V3',
                    'proportionBps': '10000',
                  },
                ],
              },
              'transaction': <String, dynamic>{
                'to': '0x5555555555555555555555555555555555555555',
                'data': '0xabcdef',
                'gas': '210000',
                'gasPrice': '5000000000',
                'value': '100000000000000000',
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      final SwapQuote quote = await service.fetchQuote(
        chainId: 8453,
        sellTokenAddress: SwapService.nativeTokenAddress,
        buyTokenAddress: '0x2222222222222222222222222222222222222222',
        sellAmountBaseUnits: 100000000000000000,
        takerAddress: '0x4444444444444444444444444444444444444444',
      );

      expect(quote.isFirmQuote, isTrue);
      expect(quote.transaction, isNotNull);
      expect(
        quote.transaction?.toAddress,
        '0x5555555555555555555555555555555555555555',
      );
      expect(quote.transaction?.dataHex, '0xabcdef');
      expect(quote.transaction?.gasLimit, 210000);
      expect(quote.transaction?.gasPriceWei, 5000000000);
      expect(quote.transaction?.valueBaseUnits, 100000000000000000);
    });

    test('supported chains include Ethereum, Base, BNB, and Polygon mainnet', () {
      expect(
        SwapService.supportedChainIdFor(
          ChainKind.ethereum,
          ChainNetwork.mainnet,
        ),
        isNotNull,
      );
      expect(
        SwapService.supportedChainIdFor(ChainKind.base, ChainNetwork.mainnet),
        isNotNull,
      );
      expect(
        SwapService.supportedChainIdFor(ChainKind.bnb, ChainNetwork.mainnet),
        isNotNull,
      );
      expect(
        SwapService.supportedChainIdFor(
          ChainKind.polygon,
          ChainNetwork.mainnet,
        ),
        isNotNull,
      );
      expect(
        SwapService.supportedChainIdFor(
          ChainKind.ethereum,
          ChainNetwork.testnet,
        ),
        isNull,
      );
      expect(
        SwapService.supportedChainIdFor(ChainKind.solana, ChainNetwork.mainnet),
        isNull,
      );
    });
  });
}
