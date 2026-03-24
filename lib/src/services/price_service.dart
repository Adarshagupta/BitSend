import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PriceService {
  PriceService({this.endpoint = 'https://api.coinbase.com'});

  static const Duration _requestTimeout = Duration(seconds: 6);
  static const Map<String, double> _fixedUsdPrices = <String, double>{
    'USDC': 1,
    'USDT': 1,
    'USD': 1,
  };
  static const Map<String, String> _quoteAliases = <String, String>{
    'EURC': 'EUR',
    'EUROC': 'EUR',
    'WETH': 'ETH',
    'WBTC': 'BTC',
  };

  String endpoint;

  Future<Map<String, double>> fetchUsdPrices(Iterable<String> symbols) async {
    final Set<String> normalized = symbols
        .map((String symbol) => symbol.trim().toUpperCase())
        .where((String symbol) => symbol.isNotEmpty)
        .toSet();
    final Map<String, double> prices = <String, double>{};
    final Map<String, Future<double>> quoteRequests = <String, Future<double>>{};
    await Future.wait(
      normalized.map((String symbol) async {
        final double? fixedPrice = _fixedUsdPrices[symbol];
        if (fixedPrice != null) {
          prices[symbol] = fixedPrice;
          return;
        }
        final String quoteSymbol = _quoteAliases[symbol] ?? symbol;
        try {
          final double price = await quoteRequests.putIfAbsent(
            quoteSymbol,
            () => _fetchUsdPrice(quoteSymbol),
          );
          prices[symbol] = price;
        } catch (_) {
          // Ignore unsupported symbols so other asset prices can still refresh.
        }
      }),
    );
    return prices;
  }

  Future<double> _fetchUsdPrice(String symbol) async {
    final Uri uri = _buildUri(symbol);
    final http.Response response = await http
        .get(
          uri,
          headers: const <String, String>{'Accept': 'application/json'},
        )
        .timeout(_requestTimeout);
    final String rawBody = response.body.trim();
    final Map<String, dynamic> json = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'USD price request failed (${response.statusCode}) for $symbol.',
      );
    }
    final Map<String, dynamic>? data = json['data'] as Map<String, dynamic>?;
    final Map<String, dynamic>? rates = data?['rates'] as Map<String, dynamic>?;
    final String? usdValue = rates?['USD'] as String?;
    final double? parsed = usdValue == null ? null : double.tryParse(usdValue);
    if (parsed == null || parsed <= 0) {
      throw FormatException('USD price is missing for $symbol.');
    }
    return parsed;
  }

  Uri _buildUri(String symbol) {
    final String trimmed = endpoint.trim();
    final Uri base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    return base.replace(
      path: '${base.path}v2/exchange-rates',
      queryParameters: <String, String>{'currency': symbol},
    );
  }
}
