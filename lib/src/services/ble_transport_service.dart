import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../models/app_models.dart';
import 'transport_contract.dart';

class BleTransportService {
  BleTransportService({
    CentralManager? centralManager,
    PeripheralManager? peripheralManager,
  })  : _centralManager = centralManager,
        _peripheralManager = peripheralManager;

  static final UUID serviceUuid =
      UUID.fromString('dc6f4626-f61d-4a6e-9d63-3fe2f0189a01');
  static final UUID writeCharacteristicUuid =
      UUID.fromString('dc6f4626-f61d-4a6e-9d63-3fe2f0189a02');
  static final UUID ackCharacteristicUuid =
      UUID.fromString('dc6f4626-f61d-4a6e-9d63-3fe2f0189a03');

  static const int _frameStart = 1;
  static const int _frameChunk = 2;
  static const int _frameEnd = 3;

  CentralManager? _centralManager;
  PeripheralManager? _peripheralManager;

  StreamSubscription<DiscoveredEventArgs>? _discoveredSubscription;
  StreamSubscription<GATTCharacteristicReadRequestedEventArgs>?
      _readRequestedSubscription;
  StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>?
      _writeRequestedSubscription;

  final Map<String, Peripheral> _discoveredPeripherals = <String, Peripheral>{};
  final Map<String, ReceiverDiscoveryItem> _receivers = <String, ReceiverDiscoveryItem>{};
  final Map<String, _BleInboundSession> _sessions = <String, _BleInboundSession>{};
  final Map<String, Uint8List> _acks = <String, Uint8List>{};

  EnvelopeHandler? _onEnvelope;
  bool _advertising = false;
  bool _discovering = false;

  bool get isListening => _advertising;
  bool get isDiscovering => _discovering;

  Future<List<ReceiverDiscoveryItem>> discover({
    Duration duration = const Duration(seconds: 4),
  }) async {
    final CentralManager manager = _central;
    _ensureCentralInitialized();
    await _authorizeManager(manager);
    _discoveredPeripherals.clear();
    _receivers.clear();
    _discovering = true;
    try {
      await manager.startDiscovery(serviceUUIDs: <UUID>[serviceUuid]);
      await Future<void>.delayed(duration);
      await manager.stopDiscovery();
    } finally {
      _discovering = false;
    }
    return _receivers.values.toList(growable: false)
      ..sort((ReceiverDiscoveryItem a, ReceiverDiscoveryItem b) {
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  }

  Future<void> start({
    required EnvelopeHandler onEnvelope,
    required String receiverDisplayAddress,
  }) async {
    if (_advertising) {
      return;
    }

    final PeripheralManager manager = _peripheral;
    _ensurePeripheralInitialized();
    await _authorizeManager(manager);
    _onEnvelope = onEnvelope;
    _sessions.clear();
    _acks.clear();

    await manager.removeAllServices();
    await manager.addService(
      GATTService(
        uuid: serviceUuid,
        isPrimary: true,
        includedServices: const <GATTService>[],
        characteristics: <GATTCharacteristic>[
          GATTCharacteristic.mutable(
            uuid: writeCharacteristicUuid,
            properties: <GATTCharacteristicProperty>[
              GATTCharacteristicProperty.write,
              GATTCharacteristicProperty.writeWithoutResponse,
            ],
            permissions: <GATTCharacteristicPermission>[
              GATTCharacteristicPermission.write,
            ],
            descriptors: const <GATTDescriptor>[],
          ),
          GATTCharacteristic.mutable(
            uuid: ackCharacteristicUuid,
            properties: <GATTCharacteristicProperty>[
              GATTCharacteristicProperty.read,
            ],
            permissions: <GATTCharacteristicPermission>[
              GATTCharacteristicPermission.read,
            ],
            descriptors: const <GATTDescriptor>[],
          ),
        ],
      ),
    );

    await manager.startAdvertising(
      Advertisement(
        name: Platform.isWindows ? null : _advertisementName(receiverDisplayAddress),
        serviceUUIDs: <UUID>[serviceUuid],
      ),
    );
    _advertising = true;
  }

  Future<void> stop() async {
    final PeripheralManager? manager = _peripheralManager;
    if (manager == null) {
      _advertising = false;
      _sessions.clear();
      _acks.clear();
      return;
    }
    if (_advertising) {
      await manager.stopAdvertising();
    }
    await manager.removeAllServices();
    _advertising = false;
    _sessions.clear();
    _acks.clear();
  }

  Future<void> send({
    required String peripheralId,
    required OfflineEnvelope envelope,
  }) async {
    final CentralManager manager = _central;
    _ensureCentralInitialized();
    await _authorizeManager(manager);
    final Peripheral? peripheral = _discoveredPeripherals[peripheralId];
    if (peripheral == null) {
      throw const FormatException('BLE receiver is not available. Scan again and retry.');
    }

    final Uint8List payload = Uint8List.fromList(
      utf8.encode(jsonEncode(envelope.toJson())),
    );

    try {
      await manager.connect(peripheral);
      if (Platform.isAndroid) {
        try {
          await manager.requestMTU(peripheral, mtu: 185);
        } catch (_) {
          // Continue with the default MTU when the platform rejects the request.
        }
      }
      final List<GATTService> services = await manager.discoverGATT(peripheral);
      final GATTService service = services.firstWhere(
        (GATTService item) => item.uuid == serviceUuid,
        orElse: () => throw const FormatException('bitsend BLE service not found.'),
      );
      final GATTCharacteristic writeCharacteristic = service.characteristics.firstWhere(
        (GATTCharacteristic item) => item.uuid == writeCharacteristicUuid,
        orElse: () => throw const FormatException('bitsend BLE write channel missing.'),
      );
      final GATTCharacteristic ackCharacteristic = service.characteristics.firstWhere(
        (GATTCharacteristic item) => item.uuid == ackCharacteristicUuid,
        orElse: () => throw const FormatException('bitsend BLE acknowledgement channel missing.'),
      );

      final int maxLength = await manager.getMaximumWriteLength(
        peripheral,
        type: GATTCharacteristicWriteType.withResponse,
      );
      final int chunkLength = maxLength <= 1 ? 1 : maxLength - 1;

      await manager.writeCharacteristic(
        peripheral,
        writeCharacteristic,
        value: _startFrame(payload.length),
        type: GATTCharacteristicWriteType.withResponse,
      );

      for (int offset = 0; offset < payload.length; offset += chunkLength) {
        final int end = (offset + chunkLength).clamp(0, payload.length);
        final Uint8List frame = Uint8List.fromList(
          <int>[_frameChunk, ...payload.sublist(offset, end)],
        );
        await manager.writeCharacteristic(
          peripheral,
          writeCharacteristic,
          value: frame,
          type: GATTCharacteristicWriteType.withResponse,
        );
      }

      await manager.writeCharacteristic(
        peripheral,
        writeCharacteristic,
        value: Uint8List.fromList(const <int>[_frameEnd]),
        type: GATTCharacteristicWriteType.withResponse,
      );

      final Uint8List ackBytes = await manager.readCharacteristic(
        peripheral,
        ackCharacteristic,
      );
      final Map<String, dynamic> ack = jsonDecode(utf8.decode(ackBytes)) as Map<String, dynamic>;
      if (ack['accepted'] != true) {
        throw FormatException(ack['message'] as String? ?? 'BLE transfer rejected.');
      }
    } finally {
      try {
        await manager.disconnect(peripheral);
      } catch (_) {
        // Ignore disconnect races when the OS already closed the connection.
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _discoveredSubscription?.cancel();
    await _readRequestedSubscription?.cancel();
    await _writeRequestedSubscription?.cancel();
  }

  Future<void> _authorizeManager(BluetoothLowEnergyManager manager) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (manager.state == BluetoothLowEnergyState.unauthorized) {
      await manager.authorize();
    }
  }

  CentralManager get _central => _centralManager ??= CentralManager();

  PeripheralManager get _peripheral => _peripheralManager ??= PeripheralManager();

  void _ensureCentralInitialized() {
    _discoveredSubscription ??= _central.discovered.listen(_handleDiscovered);
  }

  void _ensurePeripheralInitialized() {
    _readRequestedSubscription ??=
        _peripheral.characteristicReadRequested.listen(_handleReadRequested);
    _writeRequestedSubscription ??=
        _peripheral.characteristicWriteRequested.listen(_handleWriteRequested);
  }

  void _handleDiscovered(DiscoveredEventArgs event) {
    final Advertisement advertisement = event.advertisement;
    if (!advertisement.serviceUUIDs.contains(serviceUuid)) {
      return;
    }
    final String id = event.peripheral.uuid.toString();
    _discoveredPeripherals[id] = event.peripheral;
    _receivers[id] = ReceiverDiscoveryItem(
      id: id,
      label: advertisement.name ?? 'bitsend BLE receiver',
      subtitle: id,
      transport: TransportKind.ble,
    );
  }

  Future<void> _handleReadRequested(
    GATTCharacteristicReadRequestedEventArgs event,
  ) async {
    final PeripheralManager manager = _peripheral;
    _ensurePeripheralInitialized();
    if (event.characteristic.uuid != ackCharacteristicUuid) {
      await manager.respondReadRequestWithError(
        event.request,
        error: GATTError.requestNotSupported,
      );
      return;
    }

    final String centralId = event.central.uuid.toString();
    final Uint8List value = _acks[centralId] ??
        _ackBytes(
          const TransportReceiveResult(
            accepted: false,
            message: 'No transfer processed for this connection yet.',
          ),
        );
    await manager.respondReadRequestWithValue(
      event.request,
      value: value,
    );
  }

  Future<void> _handleWriteRequested(
    GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final PeripheralManager manager = _peripheral;
    _ensurePeripheralInitialized();
    if (event.characteristic.uuid != writeCharacteristicUuid) {
      await manager.respondWriteRequestWithError(
        event.request,
        error: GATTError.requestNotSupported,
      );
      return;
    }

    if (event.request.offset != 0) {
      await manager.respondWriteRequestWithError(
        event.request,
        error: GATTError.invalidOffset,
      );
      return;
    }

    final Uint8List value = event.request.value;
    if (value.isEmpty) {
      await manager.respondWriteRequestWithError(
        event.request,
        error: GATTError.invalidAttributeValueLength,
      );
      return;
    }

    final String centralId = event.central.uuid.toString();
    final int frameType = value.first;

    try {
      if (frameType == _frameStart) {
        if (value.length != 5) {
          throw const FormatException('Invalid BLE start frame.');
        }
        _sessions[centralId] = _BleInboundSession(expectedLength: _decodeLength(value));
        _acks.remove(centralId);
      } else if (frameType == _frameChunk) {
        final _BleInboundSession session = _sessions[centralId] ??
            (throw const FormatException('BLE session was not initialized.'));
        session.bytes.add(value.sublist(1));
      } else if (frameType == _frameEnd) {
        final _BleInboundSession session = _sessions.remove(centralId) ??
            (throw const FormatException('BLE session was not initialized.'));
        final Uint8List bytes = session.bytes.takeBytes();
        if (bytes.length != session.expectedLength) {
          throw FormatException(
            'BLE payload length mismatch: expected ${session.expectedLength}, received ${bytes.length}.',
          );
        }
        final Map<String, dynamic> payload =
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final OfflineEnvelope envelope = OfflineEnvelope.fromJson(payload);
        final TransportReceiveResult result = await (_onEnvelope?.call(envelope) ??
            Future<TransportReceiveResult>.value(
              const TransportReceiveResult(
                accepted: false,
                message: 'BLE receiver is not ready.',
              ),
            ));
        _acks[centralId] = _ackBytes(result);
      } else {
        throw const FormatException('Unknown BLE frame type.');
      }

      await manager.respondWriteRequest(event.request);
    } catch (error) {
      _acks[centralId] = _ackBytes(
        TransportReceiveResult(
          accepted: false,
          message: error.toString(),
        ),
      );
      await manager.respondWriteRequestWithError(
        event.request,
        error: GATTError.unlikelyError,
      );
    }
  }

  Uint8List _startFrame(int length) {
    final ByteData data = ByteData(5);
    data.setUint8(0, _frameStart);
    data.setUint32(1, length, Endian.big);
    return data.buffer.asUint8List();
  }

  int _decodeLength(Uint8List value) {
    final ByteData data = ByteData.sublistView(value);
    return data.getUint32(1, Endian.big);
  }

  Uint8List _ackBytes(TransportReceiveResult result) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'accepted': result.accepted,
          'message': result.message,
        }),
      ),
    );
  }

  String _advertisementName(String receiverDisplayAddress) {
    final String suffix = receiverDisplayAddress.replaceAll('.', '').replaceAll(' ', '');
    final String trimmed = suffix.length <= 4 ? suffix : suffix.substring(suffix.length - 4);
    return 'bitsend-$trimmed';
  }
}

class _BleInboundSession {
  _BleInboundSession({required this.expectedLength});

  final int expectedLength;
  final BytesBuilder bytes = BytesBuilder(copy: false);
}
