import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class BitGoClientService {
  BitGoClientService({required this.endpoint});

  String endpoint;
  String? _sessionToken;

  String? get sessionToken => _sessionToken;
  bool get hasSession => _sessionToken != null && _sessionToken!.isNotEmpty;

  void clearSession() {
    _sessionToken = null;
  }

  Future<BitGoBackendHealth> fetchHealth() async {
    final Map<String, dynamic> json = await _request(
      method: 'GET',
      path: '/health',
    );
    return BitGoBackendHealth.fromJson(json);
  }

  Future<BitGoDemoSession> createDemoSession() async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/bitgo/session/demo',
    );
    final BitGoDemoSession session = BitGoDemoSession.fromJson(json);
    _sessionToken = session.sessionToken;
    return session;
  }

  Future<List<BitGoWalletSummary>> fetchWallets() async {
    final Map<String, dynamic> json = await _request(
      method: 'GET',
      path: '/v1/bitgo/wallets',
      requiresSession: true,
    );
    return ((json['wallets'] as List<dynamic>?) ?? const <dynamic>[])
        .map(
          (dynamic item) =>
              BitGoWalletSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<BitGoTransferSnapshot> submitTransfer({
    required ChainKind chain,
    required ChainNetwork network,
    required String walletId,
    required String receiverAddress,
    required int amountBaseUnits,
    required String clientTransferId,
  }) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/bitgo/transfers',
      requiresSession: true,
      body: <String, dynamic>{
        'chain': chain.name,
        'network': network.name,
        'walletId': walletId,
        'receiverAddress': receiverAddress,
        'amountBaseUnits': amountBaseUnits.toString(),
        'clientTransferId': clientTransferId,
      },
    );
    return BitGoTransferSnapshot.fromJson(json);
  }

  Future<BitGoTransferSnapshot> fetchTransfer(String clientTransferId) async {
    final Map<String, dynamic> json = await _request(
      method: 'GET',
      path: '/v1/bitgo/transfers/${Uri.encodeComponent(clientTransferId)}',
      requiresSession: true,
    );
    return BitGoTransferSnapshot.fromJson(json);
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    bool requiresSession = false,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = _buildUri(path);
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (requiresSession && hasSession)
        'Authorization': 'Bearer $_sessionToken',
    };
    final http.Response response = switch (method) {
      'POST' => await http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'GET' => await http.get(uri, headers: headers),
      _ => throw UnsupportedError('Unsupported BitGo client method: $method'),
    };
    final String rawBody = response.body.trim();
    final Map<String, dynamic> json = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    throw FormatException(
      (json['message'] as String?) ??
          (json['error'] as String?) ??
          'BitGo backend request failed (${response.statusCode}).',
    );
  }

  Uri _buildUri(String path) {
    final String trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Set the BitGo backend endpoint in Settings before using BitGo mode.',
      );
    }
    final Uri base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return base.resolve(normalizedPath);
  }
}
