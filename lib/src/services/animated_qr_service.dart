import 'dart:convert';

import 'package:crypto/crypto.dart';

class AnimatedQrFrame {
  const AnimatedQrFrame({
    required this.sessionId,
    required this.frameIndex,
    required this.frameCount,
    required this.payloadChecksum,
    required this.chunk,
  });

  static const String type = 'bitsend.animated_qr';
  static const int currentVersion = 1;

  final String sessionId;
  final int frameIndex;
  final int frameCount;
  final String payloadChecksum;
  final String chunk;

  Map<String, dynamic> toJson() => <String, dynamic>{
    't': type,
    'v': currentVersion,
    's': sessionId,
    'i': frameIndex,
    'n': frameCount,
    'c': payloadChecksum,
    'd': chunk,
  };

  String toQrData() => jsonEncode(toJson());

  factory AnimatedQrFrame.fromQrData(String raw) {
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    if ((json['t'] as String?) != type) {
      throw const FormatException('This QR code is not an animated Bitsend frame.');
    }
    final int version = (json['v'] as int?) ?? currentVersion;
    if (version != currentVersion) {
      throw const FormatException('Animated QR frame version is not supported.');
    }
    final String sessionId = (json['s'] as String? ?? '').trim();
    final int frameIndex = json['i'] as int? ?? -1;
    final int frameCount = json['n'] as int? ?? 0;
    final String payloadChecksum = (json['c'] as String? ?? '').trim();
    final String chunk = (json['d'] as String? ?? '').trim();
    if (sessionId.isEmpty ||
        frameIndex < 0 ||
        frameCount <= 0 ||
        payloadChecksum.isEmpty ||
        chunk.isEmpty) {
      throw const FormatException('Animated QR frame is incomplete.');
    }
    return AnimatedQrFrame(
      sessionId: sessionId,
      frameIndex: frameIndex,
      frameCount: frameCount,
      payloadChecksum: payloadChecksum,
      chunk: chunk,
    );
  }
}

class AnimatedQrAssembleResult {
  const AnimatedQrAssembleResult({
    required this.receivedFrames,
    required this.frameCount,
    this.payload,
  });

  final int receivedFrames;
  final int frameCount;
  final String? payload;

  bool get complete => payload != null;
}

class AnimatedQrAssembler {
  String? _sessionId;
  int? _frameCount;
  String? _payloadChecksum;
  final Map<int, String> _chunks = <int, String>{};

  AnimatedQrAssembleResult addFrame(AnimatedQrFrame frame) {
    _sessionId ??= frame.sessionId;
    _frameCount ??= frame.frameCount;
    _payloadChecksum ??= frame.payloadChecksum;

    if (_sessionId != frame.sessionId ||
        _frameCount != frame.frameCount ||
        _payloadChecksum != frame.payloadChecksum) {
      throw const FormatException(
        'Animated QR frames belong to a different transfer session.',
      );
    }
    if (frame.frameIndex >= frame.frameCount) {
      throw const FormatException('Animated QR frame index is out of range.');
    }

    _chunks.putIfAbsent(frame.frameIndex, () => frame.chunk);
    if (_chunks.length != frame.frameCount) {
      return AnimatedQrAssembleResult(
        receivedFrames: _chunks.length,
        frameCount: frame.frameCount,
      );
    }

    final String payload = List<String>.generate(
      frame.frameCount,
      (int index) => _chunks[index] ?? '',
    ).join();
    if (_computeChecksum(payload) != frame.payloadChecksum) {
      throw const FormatException('Animated QR payload checksum mismatch.');
    }
    return AnimatedQrAssembleResult(
      receivedFrames: _chunks.length,
      frameCount: frame.frameCount,
      payload: payload,
    );
  }

  void reset() {
    _sessionId = null;
    _frameCount = null;
    _payloadChecksum = null;
    _chunks.clear();
  }
}

class AnimatedQrService {
  const AnimatedQrService();

  static const int defaultChunkLength = 160;

  List<AnimatedQrFrame> encodePayload(
    String payload, {
    int maxChunkLength = defaultChunkLength,
  }) {
    final String normalized = payload.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Animated QR payload cannot be empty.');
    }
    if (maxChunkLength < 32) {
      throw const FormatException('Animated QR chunk length is too small.');
    }

    final List<String> chunks = <String>[
      for (int start = 0; start < normalized.length; start += maxChunkLength)
        normalized.substring(
          start,
          start + maxChunkLength > normalized.length
              ? normalized.length
              : start + maxChunkLength,
        ),
    ];
    final String checksum = _computeChecksum(normalized);
    final String sessionId = checksum.substring(0, 12);
    return List<AnimatedQrFrame>.generate(chunks.length, (int index) {
      return AnimatedQrFrame(
        sessionId: sessionId,
        frameIndex: index,
        frameCount: chunks.length,
        payloadChecksum: checksum,
        chunk: chunks[index],
      );
    });
  }
}

String _computeChecksum(String payload) {
  return sha256.convert(utf8.encode(payload)).toString();
}
