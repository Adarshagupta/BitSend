import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'transport_contract.dart';

class HotspotTransportService {
  static const int port = 8787;
  static const Duration _requestTimeout = Duration(seconds: 8);

  HttpServer? _server;

  bool get isListening => _server != null;

  Future<void> start({required EnvelopeHandler onEnvelope}) async {
    if (_server != null) {
      return;
    }

    final HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    unawaited(
      server.forEach((HttpRequest request) async {
        if (request.method != 'POST' || request.uri.path != '/v1/envelopes') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        try {
          final String body = await utf8.decoder.bind(request).join();
          final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
          final OfflineEnvelope envelope = OfflineEnvelope.fromJson(json);
          final TransportReceiveResult result = await onEnvelope(envelope);
          request.response.statusCode =
              result.accepted ? HttpStatus.ok : HttpStatus.conflict;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, Object?>{
            'accepted': result.accepted,
            'message': result.message,
          }));
        } catch (error) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, Object?>{
            'accepted': false,
            'message': error.toString(),
          }));
        } finally {
          await request.response.close();
        }
      }),
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> send({
    required Uri endpoint,
    required OfflineEnvelope envelope,
  }) async {
    final Uri requestUri = endpoint.replace(path: '/v1/envelopes');
    final http.Response response;
    try {
      response = await http
          .post(
            requestUri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(envelope.toJson()),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw HttpException(
        'Local transfer timed out. Confirm the receiver is listening and retry.',
        uri: requestUri,
      );
    }
    final String? receiverMessage = _messageFromResponse(response.body);
    if (response.statusCode >= 400) {
      throw HttpException(
        receiverMessage == null
            ? 'Local transfer failed (${response.statusCode}).'
            : 'Local transfer failed: $receiverMessage',
        uri: requestUri,
      );
    }
    if (receiverMessage == null) {
      return;
    }
    final bool accepted = _acceptedFromResponse(response.body) ?? true;
    if (!accepted) {
      throw HttpException(
        'Local transfer failed: $receiverMessage',
        uri: requestUri,
      );
    }
  }

  String? _messageFromResponse(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      final String? message = (json['message'] as String?)?.trim();
      return message == null || message.isEmpty ? null : message;
    } catch (_) {
      return null;
    }
  }

  bool? _acceptedFromResponse(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      return json['accepted'] as bool?;
    } catch (_) {
      return null;
    }
  }
}
