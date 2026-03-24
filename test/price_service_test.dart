import 'dart:convert';
import 'dart:io';

import 'package:bitsend/src/services/price_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PriceService.fetchUsdPrices', () {
    test('reads USD prices from Coinbase exchange-rates responses', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String? currency = request.uri.queryParameters['currency'];
        final String rate = switch (currency) {
          'ETH' => '3500.12',
          'SOL' => '145.5',
          _ => '1.0',
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'currency': currency,
              'rates': <String, String>{'USD': rate},
            },
          }),
        );
        await request.response.close();
      });

      final PriceService service = PriceService(
        endpoint: 'http://${server.address.address}:${server.port}',
      );
      final Map<String, double> prices = await service.fetchUsdPrices(
        <String>{'ETH', 'SOL', 'USDC'},
      );

      expect(prices['ETH'], 3500.12);
      expect(prices['SOL'], 145.5);
      expect(prices['USDC'], 1);
    });

    test('keeps supported prices when some ERC-20 symbols are unsupported', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        final String? currency = request.uri.queryParameters['currency'];
        if (currency == 'UNKNOWN') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        final String rate = switch (currency) {
          'ETH' => '3500.12',
          'EUR' => '1.08',
          _ => '1.0',
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'currency': currency,
              'rates': <String, String>{'USD': rate},
            },
          }),
        );
        await request.response.close();
      });

      final PriceService service = PriceService(
        endpoint: 'http://${server.address.address}:${server.port}',
      );
      final Map<String, double> prices = await service.fetchUsdPrices(
        <String>{'ETH', 'EURC', 'UNKNOWN'},
      );

      expect(prices['ETH'], 3500.12);
      expect(prices['EURC'], 1.08);
      expect(prices.containsKey('UNKNOWN'), isFalse);
    });
  });
}
