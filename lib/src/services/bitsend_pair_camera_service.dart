import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BitsendPairCameraService {
  BitsendPairCameraService({MethodChannel? methodChannel})
    : _methodChannel =
          methodChannel ?? const MethodChannel('bitsend/pair_camera');

  final MethodChannel _methodChannel;

  Future<Uint8List> capturePreview() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Custom Bitsend Pair capture is only available on Android in this build.',
      );
    }
    final Uint8List? bytes = await _methodChannel
        .invokeMethod<Uint8List>('capturePreview');
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Camera capture returned no image data.');
    }
    return bytes;
  }
}
