import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'ethereum_service.dart';

class SwapService {
  SwapService({
    this.endpoint = 'https://api.0x.org',
    this.apiKey = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String nativeTokenAddress =
      '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
  static const Duration _requestTimeout = Duration(seconds: 10);

  final http.Client _client;
  String endpoint;
  String apiKey;

  static int? supportedChainIdFor(ChainKind chain, ChainNetwork network) {
    if (!network.isMainnet) {
      return null;
    }
    return switch (chain) {
      ChainKind.ethereum => EthereumService.mainnetChainId,
      ChainKind.base => EthereumService.baseMainnetChainId,
      ChainKind.bnb => EthereumService.bnbMainnetChainId,
      ChainKind.polygon => EthereumService.polygonMainnetChainId,
      ChainKind.solana => null,
    };
  }

  static String tokenAddressForAsset(TrackedAssetDefinition asset) {
    return asset.isNative ? nativeTokenAddress : asset.contractAddress!;
  }

  Future<SwapQuote> fetchPrice({
    required int chainId,
    required String sellTokenAddress,
    required String buyTokenAddress,
    required int sellAmountBaseUnits,
    required String takerAddress,
    int? slippageBps,
  }) {
    return _requestQuote(
      path: '/swap/allowance-holder/price',
      chainId: chainId,
      sellTokenAddress: sellTokenAddress,
      buyTokenAddress: buyTokenAddress,
      sellAmountBaseUnits: sellAmountBaseUnits,
      takerAddress: takerAddress,
      slippageBps: slippageBps,
      isFirmQuote: false,
    );
  }

  Future<SwapQuote> fetchQuote({
    required int chainId,
    required String sellTokenAddress,
    required String buyTokenAddress,
    required int sellAmountBaseUnits,
    required String takerAddress,
    int? slippageBps,
  }) {
    return _requestQuote(
      path: '/swap/allowance-holder/quote',
      chainId: chainId,
      sellTokenAddress: sellTokenAddress,
      buyTokenAddress: buyTokenAddress,
      sellAmountBaseUnits: sellAmountBaseUnits,
      takerAddress: takerAddress,
      slippageBps: slippageBps,
      isFirmQuote: true,
    );
  }

  Future<SwapQuote> _requestQuote({
    required String path,
    required int chainId,
    required String sellTokenAddress,
    required String buyTokenAddress,
    required int sellAmountBaseUnits,
    required String takerAddress,
    required bool isFirmQuote,
    int? slippageBps,
  }) async {
    final String trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const FormatException('Add your 0x API key in Settings first.');
    }
    final Uri uri = _buildUri(
      path: path,
      queryParameters: <String, String>{
        'chainId': '$chainId',
        'sellToken': sellTokenAddress,
        'buyToken': buyTokenAddress,
        'sellAmount': '$sellAmountBaseUnits',
        'taker': takerAddress,
        if (slippageBps != null) 'slippageBps': '$slippageBps',
      },
    );
    final http.Response response = await _client
        .get(uri, headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          '0x-api-key': trimmedKey,
          '0x-version': 'v2',
        })
        .timeout(_requestTimeout);
    final String rawBody = response.body.trim();
    final Map<String, dynamic> json = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(_errorMessageFor(response.statusCode, json));
    }
    return _parseQuote(json, isFirmQuote: isFirmQuote);
  }

  Uri _buildUri({
    required String path,
    required Map<String, String> queryParameters,
  }) {
    final String trimmed = endpoint.trim();
    final Uri base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    return base.replace(
      path: '${base.path}${path.startsWith('/') ? path.substring(1) : path}',
      queryParameters: queryParameters,
    );
  }

  SwapQuote _parseQuote(
    Map<String, dynamic> json, {
    required bool isFirmQuote,
  }) {
    final Map<String, dynamic>? issues = json['issues'] as Map<String, dynamic>?;
    final Map<String, dynamic>? allowance =
        issues?['allowance'] as Map<String, dynamic>?;
    final Map<String, dynamic>? balance =
        issues?['balance'] as Map<String, dynamic>?;
    final Map<String, dynamic>? route = json['route'] as Map<String, dynamic>?;
    final Map<String, dynamic>? fees = json['fees'] as Map<String, dynamic>?;
    final Map<String, dynamic>? zeroExFee =
        fees?['zeroExFee'] as Map<String, dynamic>?;
    final Map<String, dynamic>? gasFee =
        fees?['gasFee'] as Map<String, dynamic>?;
    final Map<String, dynamic>? transaction =
        json['transaction'] as Map<String, dynamic>?;
    return SwapQuote(
      sellTokenAddress: (json['sellToken'] as String? ?? '').trim(),
      buyTokenAddress: (json['buyToken'] as String? ?? '').trim(),
      sellAmountBaseUnits: _parseFlexibleInt(json['sellAmount']),
      buyAmountBaseUnits: _parseFlexibleInt(json['buyAmount']),
      minBuyAmountBaseUnits: _parseFlexibleInt(json['minBuyAmount']),
      liquidityAvailable: json['liquidityAvailable'] == true,
      routeFills: (route?['fills'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> item) => SwapRouteFill(
              fromTokenAddress: (item['from'] as String? ?? '').trim(),
              toTokenAddress: (item['to'] as String? ?? '').trim(),
              source: (item['source'] as String? ?? '').trim(),
              proportionBps: _parseFlexibleInt(item['proportionBps']),
            ),
          )
          .toList(growable: false),
      isFirmQuote: isFirmQuote,
      totalNetworkFeeBaseUnits: json['totalNetworkFee'] == null
          ? null
          : _parseFlexibleInt(json['totalNetworkFee']),
      zeroExFee: zeroExFee == null
          ? null
          : SwapFeeAmount(
              amountBaseUnits: _parseFlexibleInt(zeroExFee['amount']),
              tokenAddress: (zeroExFee['token'] as String? ?? '').trim(),
              type: (zeroExFee['type'] as String? ?? '').trim(),
            ),
      gasFee: gasFee == null
          ? null
          : SwapFeeAmount(
              amountBaseUnits: _parseFlexibleInt(gasFee['amount']),
              tokenAddress: (gasFee['token'] as String? ?? '').trim(),
              type: (gasFee['type'] as String? ?? '').trim(),
            ),
      allowanceIssue: allowance == null
          ? null
          : SwapAllowanceIssue(
              actualBaseUnits: _parseFlexibleInt(allowance['actual']),
              spenderAddress: (allowance['spender'] as String? ?? '').trim(),
            ),
      balanceIssue: balance == null
          ? null
          : SwapBalanceIssue(
              tokenAddress: (balance['token'] as String? ?? '').trim(),
              actualBaseUnits: _parseFlexibleInt(balance['actual']),
              expectedBaseUnits: _parseFlexibleInt(balance['expected']),
            ),
      transaction: transaction == null
          ? null
          : SwapTransactionRequest(
              toAddress: (transaction['to'] as String? ?? '').trim(),
              dataHex: (transaction['data'] as String? ?? '0x').trim(),
              gasLimit: _parseFlexibleInt(transaction['gas']),
              gasPriceWei: _parseFlexibleInt(transaction['gasPrice']),
              valueBaseUnits: _parseFlexibleInt(transaction['value']),
            ),
      zid: (json['zid'] as String?)?.trim(),
    );
  }

  String _errorMessageFor(int statusCode, Map<String, dynamic> json) {
    final String? reason = (json['reason'] as String?)?.trim();
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    final String? message = (json['message'] as String?)?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    final List<dynamic>? validationErrors =
        json['validationErrors'] as List<dynamic>?;
    if (validationErrors != null && validationErrors.isNotEmpty) {
      final Map<String, dynamic>? first = validationErrors.first
          as Map<String, dynamic>?;
      final String? field = (first?['field'] as String?)?.trim();
      final String? description = (first?['reason'] as String?)?.trim();
      if (field != null &&
          field.isNotEmpty &&
          description != null &&
          description.isNotEmpty) {
        return '$field: $description';
      }
      if (description != null && description.isNotEmpty) {
        return description;
      }
    }
    return 'Swap request failed ($statusCode).';
  }
}

int _parseFlexibleInt(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is BigInt) {
    return value.toInt();
  }
  final String text = value.toString().trim();
  if (text.isEmpty) {
    return 0;
  }
  return int.parse(text);
}
