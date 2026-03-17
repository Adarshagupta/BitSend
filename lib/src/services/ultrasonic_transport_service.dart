import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import 'transport_contract.dart';

typedef UltrasonicPacketHandler =
    Future<TransportReceiveResult> Function(UltrasonicTransferPacket packet);

class UltrasonicTransportService {
  UltrasonicTransportService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('bitsend/ultrasonic'),
       _eventChannel =
           eventChannel ?? const EventChannel('bitsend/ultrasonic/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<dynamic>? _events;
  bool _listening = false;

  bool get isListening => _listening;

  Future<bool> isSupported() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return (await _methodChannel.invokeMethod<bool>('isSupported')) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> start({
    required String sessionToken,
    required UltrasonicPacketHandler onPacket,
    TransportActivityHandler? onActivity,
  }) async {
    throw UnsupportedError(
      'Direct ultrasonic handoff is not available on this build. Use Relay via browser courier or BLE.',
    );
  }

  Future<void> stop() async {
    _listening = false;
    _events = null;
    try {
      await _methodChannel.invokeMethod<void>('stopListener');
    } catch (_) {
      // The current build may not include a native ultrasonic bridge yet.
    }
  }

  Future<void> send({
    required UltrasonicTransferPacket packet,
  }) async {
    if (packet.toBytes().length > UltrasonicTransferPacket.maximumEncodedLength) {
      throw const FormatException(
        'Signed payload is too large for ultrasonic delivery. Use Relay via browser courier or BLE.',
      );
    }
    throw UnsupportedError(
      'Direct ultrasonic handoff is not available on this build. Use Relay via browser courier or BLE.',
    );
  }
}
