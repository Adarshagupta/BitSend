import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class RelayClientService {
  RelayClientService({required this.endpoint});

  static const Duration _requestTimeout = Duration(seconds: 8);

  String endpoint;

  Future<void> uploadCapsule(RelayCapsule capsule) async {
    await _request(
      method: 'POST',
      path: '/v1/relay/capsules',
      body: capsule.toJson(),
    );
  }

  Future<RelayCapsule?> fetchCapsule(String relayId) async {
    try {
      final Map<String, dynamic> json = await _request(
        method: 'GET',
        path: '/v1/relay/capsules/${Uri.encodeComponent(relayId)}',
      );
      return RelayCapsule.fromJson(json);
    } on FormatException catch (error) {
      final String text = error.message.toLowerCase();
      if (text.contains('not found') || text.contains('expired')) {
        return null;
      }
      rethrow;
    }
  }

  Uri relayImportUri(RelayCapsule capsule) {
    final Uri base = _buildUri('/relay/import');
    final String fragment = base64Url.encode(
      utf8.encode(jsonEncode(capsule.toJson())),
    );
    return base.replace(fragment: fragment);
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
        'POST' => await http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout),
        'GET' => await http.get(uri, headers: headers).timeout(_requestTimeout),
        _ => throw UnsupportedError('Unsupported relay client method: $method'),
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
            'Relay backend request failed (${response.statusCode}).',
      );
    } on TimeoutException {
      throw const FormatException(
        'Relay backend request timed out. Try again once connectivity is stable.',
      );
    }
  }

  Uri _buildUri(String path) {
    final String trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Set the backend endpoint in Settings before using relay delivery.',
      );
    }
    final Uri base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return base.resolve(normalizedPath);
  }
}
