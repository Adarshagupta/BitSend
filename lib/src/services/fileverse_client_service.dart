import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class FileverseClientService {
  FileverseClientService({required this.endpoint});

  static const Duration _requestTimeout = Duration(seconds: 8);

  String endpoint;
  String? _sessionToken;

  bool get hasSession => _sessionToken != null && _sessionToken!.isNotEmpty;

  void clearSession() {
    _sessionToken = null;
  }

  Future<FileverseDemoSession> createSession() async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/fileverse/session',
    );
    final FileverseDemoSession session = FileverseDemoSession.fromJson(json);
    _sessionToken = session.sessionToken;
    return session;
  }

  Future<FileverseDemoSession> createDemoSession() => createSession();

  Future<FileverseReceiptSnapshot> publishReceipt({
    required PendingTransfer transfer,
    required String receiptPngBase64,
  }) async {
    final Map<String, dynamic> json = await _request(
      method: 'POST',
      path: '/v1/fileverse/receipts',
      requiresSession: true,
      body: <String, dynamic>{
        'transferId': transfer.transferId,
        'chain': transfer.chain.name,
        'network': transfer.network.name,
        'walletEngine': transfer.walletEngine.name,
        'direction': transfer.direction.name,
        'status': transfer.status.name,
        'amountBaseUnits': transfer.amountLamports.toString(),
        'amountLabel': Formatters.asset(transfer.amountSol, transfer.chain),
        'senderAddress': transfer.senderAddress,
        'receiverAddress': transfer.receiverAddress,
        'transport': transfer.transport.name,
        'updatedAt': transfer.updatedAt.toIso8601String(),
        'createdAt': transfer.createdAt.toIso8601String(),
        'transactionSignature': transfer.transactionSignature,
        'explorerUrl': transfer.explorerUrl,
        'receiptPngBase64': receiptPngBase64,
      },
    );
    return FileverseReceiptSnapshot.fromJson(json);
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    bool requiresSession = false,
    Map<String, dynamic>? body,
  }) async {
    try {
      final Uri uri = _buildUri(path);
      final Map<String, String> headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (requiresSession && hasSession)
          'Authorization': 'Bearer $_sessionToken',
      };
      final http.Response response = switch (method) {
        'POST' =>
          await http
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_requestTimeout),
        'GET' => await http.get(uri, headers: headers).timeout(_requestTimeout),
        _ => throw UnsupportedError(
          'Unsupported Fileverse client method: $method',
        ),
      };
      final String rawBody = response.body.trim();
      final Map<String, dynamic> json = rawBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json;
      }
      final String message =
          (json['message'] as String?) ??
          (json['error'] as String?) ??
          'Fileverse backend request failed (${response.statusCode}).';
      throw FormatException(_normalizeBackendMessage(message));
    } on TimeoutException {
      throw const FormatException(
        'Fileverse backend request timed out. Check the backend endpoint and try again.',
      );
    }
  }

  Uri _buildUri(String path) {
    final String trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Set the backend endpoint in Settings before using Fileverse.',
      );
    }
    final Uri base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return base.resolve(normalizedPath);
  }

  String _normalizeBackendMessage(String message) {
    final String normalized = message.trim();
    final String lower = normalized.toLowerCase();
    if (lower.contains('sqlite_toobig') ||
        lower.contains('string or blob too big')) {
      return 'Receipt image is too large for Fileverse storage. Try again and BitSend will upload a smaller copy.';
    }
    return normalized;
  }
}
