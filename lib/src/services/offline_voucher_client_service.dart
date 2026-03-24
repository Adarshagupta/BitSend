import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class OfflineVoucherClientService {
  OfflineVoucherClientService({
    required this.endpoint,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const Duration _requestTimeout = Duration(seconds: 8);

  final http.Client _client;
  final bool _ownsClient;

  String endpoint;

  Future<OfflineVoucherEscrowCommitment> registerEscrow(
    OfflineVoucherEscrowCommitment escrow,
  ) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/offline/escrows',
      body: escrow.toJson(),
    );
    return OfflineVoucherEscrowCommitment.fromJson(json);
  }

  Future<OfflineVoucherEscrowCommitment?> fetchEscrow(String escrowId) async {
    return _fetchOrNull<OfflineVoucherEscrowCommitment>(
      path: '/v1/offline/escrows/${Uri.encodeComponent(escrowId)}',
      parser: OfflineVoucherEscrowCommitment.fromJson,
    );
  }

  Future<OfflineVoucherProofBundle> registerProofBundle(
    OfflineVoucherProofBundle bundle,
  ) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/offline/proof-bundles',
      body: bundle.toJson(),
    );
    return OfflineVoucherProofBundle.fromJson(json);
  }

  Future<OfflineVoucherProofBundle?> fetchProofBundle(String voucherId) async {
    return _fetchOrNull<OfflineVoucherProofBundle>(
      path: '/v1/offline/proof-bundles/${Uri.encodeComponent(voucherId)}',
      parser: OfflineVoucherProofBundle.fromJson,
    );
  }

  Future<OfflineVoucherRelayMessage> uploadRelayMessage(
    OfflineVoucherRelayMessage message,
  ) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/offline/relay/messages',
      body: message.toJson(),
    );
    return OfflineVoucherRelayMessage.fromJson(json);
  }

  Future<OfflineVoucherRelayMessage?> fetchRelayMessage(String txId) async {
    return _fetchOrNull<OfflineVoucherRelayMessage>(
      path: '/v1/offline/relay/messages/${Uri.encodeComponent(txId)}',
      parser: OfflineVoucherRelayMessage.fromJson,
    );
  }

  Future<OfflineVoucherClaimRecord> submitClaim(
    OfflineVoucherClaimSubmission claim,
  ) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/offline/claims',
      body: claim.toJson(),
    );
    return OfflineVoucherClaimRecord.fromJson(json);
  }

  Future<OfflineVoucherClaimRecord> requestSponsoredClaim(
    OfflineVoucherClaimSubmission claim,
  ) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/offline/claims/sponsored',
      body: claim.toJson(),
    );
    return OfflineVoucherClaimRecord.fromJson(json);
  }

  Future<OfflineVoucherClaimRecord> updateClaimSettlement(
    OfflineVoucherClaimSettlementUpdate update,
  ) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/offline/claims/settlement',
      body: update.toJson(),
    );
    return OfflineVoucherClaimRecord.fromJson(json);
  }

  Future<OfflineVoucherClaimRecord?> fetchClaim(String voucherId) async {
    return _fetchOrNull<OfflineVoucherClaimRecord>(
      path: '/v1/offline/claims/${Uri.encodeComponent(voucherId)}',
      parser: OfflineVoucherClaimRecord.fromJson,
    );
  }

  Future<OfflineVoucherRefundEligibility?> fetchRefundEligibility(
    String escrowId,
  ) async {
    return _fetchOrNull<OfflineVoucherRefundEligibility>(
      path:
          '/v1/offline/escrows/${Uri.encodeComponent(escrowId)}/refund-eligibility',
      parser: OfflineVoucherRefundEligibility.fromJson,
    );
  }

  Future<T?> _fetchOrNull<T>({
    required String path,
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final Map<String, dynamic> json = await _request(method: 'GET', path: path);
      return parser(json);
    } on FormatException catch (error) {
      final String text = error.message.toLowerCase();
      if (
          text.contains('not found') ||
          text.contains('expired') ||
          text.contains('missing')) {
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      final Uri uri = _buildUri(path);
      final Map<String, String> headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      };
      final http.Response response = switch (method) {
        'POST' => await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout),
        'GET' => await _client.get(uri, headers: headers).timeout(_requestTimeout),
        _ => throw UnsupportedError('Unsupported offline voucher method: $method'),
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
            'Offline voucher backend request failed (${response.statusCode}).',
      );
    } on TimeoutException {
      throw const FormatException(
        'Offline voucher backend request timed out. Try again once connectivity is stable.',
      );
    }
  }

  Uri _buildUri(String path) {
    final String trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Set the backend endpoint in Settings before using offline voucher settlement.',
      );
    }
    final Uri base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return base.resolve(normalizedPath);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
