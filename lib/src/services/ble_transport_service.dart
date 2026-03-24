import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:solana/solana.dart' show isValidAddress;

import '../models/app_models.dart';
import 'transport_contract.dart';

enum BleFailureStage { scan, advertise, connect, transfer }

Object normalizeBleTransportError(
  Object error, {
  required BleFailureStage stage,
}) {
  if (error is FormatException ||
      error is SocketException ||
      error is TimeoutException ||
      error is UnsupportedError) {
    return error;
  }

  final String raw = error.toString();
  final String message = raw.toLowerCase();

  if (message.contains('start advertising failed with error code: 1')) {
    return const FormatException(
      'Bluetooth advertising payload was too large for this device. The receiver profile was simplified; try again.',
    );
  }
  if (message.contains('start advertising failed with error code: 2') ||
      message.contains('start advertising failed with error code: 4') ||
      message.contains('start discovery failed with error code: 2') ||
      message.contains('start discovery failed with error code: 3') ||
      message.contains('start discovery failed with error code: 5') ||
      message.contains('bluetoothleadvertiser') ||
      message.contains('bluetoothlescanner')) {
    return const FormatException(
      'Bluetooth is busy on this phone, often because another accessory or app is already using it. Disconnect AirPods or other Bluetooth devices, then try BLE again.',
    );
  }
  if (message.contains('start advertising failed with error code: 3')) {
    return const FormatException('Bluetooth receive is already running.');
  }
  if (message.contains('start advertising failed with error code: 5') ||
      message.contains('start discovery failed with error code: 4')) {
    return const FormatException(
      'Bluetooth Low Energy is not supported on this device.',
    );
  }
  if (message.contains('start discovery failed with error code: 1')) {
    return const FormatException('Bluetooth scan is already running.');
  }
  if (message.contains('start discovery failed with error code: 6')) {
    return const FormatException(
      'Bluetooth scan was started too often. Wait a few seconds and try again.',
    );
  }
  if (message.contains('connect failed with status: 133') ||
      message.contains('gatt is disconnected with status: 133') ||
      message.contains('connect failed with status: 8') ||
      message.contains('gatt is disconnected with status: 8') ||
      message.contains('connect failed with status: 62') ||
      message.contains('gatt is disconnected with status: 62') ||
      message.contains('connect failed with status: 257') ||
      message.contains('gatt is disconnected with status: 257')) {
    return const FormatException(
      'Bluetooth connection could not be established. If AirPods or another Bluetooth accessory is connected, disconnect it and try again.',
    );
  }
  if (message.contains('discover gatt failed with status:') ||
      message.contains('read characteristic failed with status:') ||
      message.contains('write characteristic failed with status:') ||
      message.contains('read descriptor failed with status:') ||
      message.contains('write descriptor failed with status:') ||
      message.contains('send response failed')) {
    return const FormatException(
      'Bluetooth transfer was interrupted. Keep both phones nearby and disconnect other active Bluetooth accessories, then try again.',
    );
  }
  if (message.contains('illegalstateexception')) {
    return switch (stage) {
      BleFailureStage.scan => const FormatException(
        'Bluetooth scan could not start cleanly. If another Bluetooth accessory is active, disconnect it and try again.',
      ),
      BleFailureStage.advertise => const FormatException(
        'Bluetooth receive could not start cleanly. If another Bluetooth accessory is active, disconnect it and try again.',
      ),
      BleFailureStage.connect => const FormatException(
        'Bluetooth connection failed. Disconnect other active Bluetooth accessories and try again.',
      ),
      BleFailureStage.transfer => const FormatException(
        'Bluetooth transfer failed. Disconnect other active Bluetooth accessories and retry.',
      ),
    };
  }

  return switch (stage) {
    BleFailureStage.scan => const FormatException(
      'Bluetooth scan failed. If another Bluetooth accessory is active, disconnect it and try again.',
    ),
    BleFailureStage.advertise => const FormatException(
      'Bluetooth receive failed to start. If another Bluetooth accessory is active, disconnect it and try again.',
    ),
    BleFailureStage.connect => const FormatException(
      'Bluetooth connection failed. Move the devices closer and try again.',
    ),
    BleFailureStage.transfer => const FormatException(
      'Bluetooth transfer failed. Keep both phones nearby and try again.',
    ),
  };
}

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
  static final UUID receiverInfoCharacteristicUuid =
      UUID.fromString('dc6f4626-f61d-4a6e-9d63-3fe2f0189a04');

  static const int _frameStart = 1;
  static const int _frameChunk = 2;
  static const int _frameEnd = 3;
  static const int _advertisementVersion = 1;
  static const Duration _discoveryTimeout = Duration(seconds: 8);
  static const Duration _discoveryPause = Duration(milliseconds: 320);
  static const Duration _connectTimeout = Duration(seconds: 8);
  static const Duration _gattTimeout = Duration(seconds: 8);
  static const Duration _ioTimeout = Duration(seconds: 8);
  static const Duration _disconnectTimeout = Duration(seconds: 4);

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

  TransportPayloadHandler? _onPayload;
  TransportActivityHandler? _onActivity;
  bool _advertising = false;
  bool _discovering = false;

  bool get isListening => _advertising;
  bool get isDiscovering => _discovering;

  Future<List<ReceiverDiscoveryItem>> discover({
    Duration duration = _discoveryTimeout,
  }) async {
    final CentralManager manager = _central;
    _ensureCentralInitialized();
    await _ensureManagerReady(manager);
    _discoveredPeripherals.clear();
    _receivers.clear();
    _discovering = true;
    try {
      final int passCount = duration >= const Duration(seconds: 8) ? 2 : 1;
      final int passMilliseconds =
          (duration.inMilliseconds / passCount).ceil();
      for (int pass = 0; pass < passCount; pass += 1) {
        await _withTimeout(
          manager.startDiscovery(serviceUUIDs: <UUID>[serviceUuid]),
          message: 'BLE scan could not start. Try again.',
          timeout: _ioTimeout,
        );
        await Future<void>.delayed(Duration(milliseconds: passMilliseconds));
        await _withTimeout(
          manager.stopDiscovery(),
          message: 'BLE scan could not stop cleanly.',
          timeout: _ioTimeout,
        );
        if (pass != passCount - 1) {
          await Future<void>.delayed(_discoveryPause);
        }
      }
      await _hydrateReceiverMetadata(manager);
    } catch (error) {
      throw normalizeBleTransportError(error, stage: BleFailureStage.scan);
    } finally {
      _discovering = false;
    }
    return _receivers.values.toList(growable: false)..sort(_compareReceivers);
  }

  Future<void> start({
    required TransportPayloadHandler onPayload,
    required String receiverDisplayAddress,
    required String receiverAddress,
    required ChainKind receiverChain,
    required ChainNetwork receiverNetwork,
    TransportActivityHandler? onActivity,
  }) async {
    if (_advertising) {
      return;
    }

    final PeripheralManager manager = _peripheral;
    _ensurePeripheralInitialized();
    await _ensureManagerReady(manager);
    _onPayload = onPayload;
    _onActivity = onActivity;
    _sessions.clear();
    _acks.clear();

    try {
      await manager.removeAllServices();
      await manager.addService(
        GATTService(
          uuid: serviceUuid,
          isPrimary: true,
          includedServices: const <GATTService>[],
          characteristics: <GATTCharacteristic>[
            GATTCharacteristic.immutable(
              uuid: receiverInfoCharacteristicUuid,
              value: _receiverInfoBytes(
                receiverChain: receiverChain,
                receiverNetwork: receiverNetwork,
                receiverAddress: receiverAddress,
                receiverDisplayAddress: receiverDisplayAddress,
              ),
              descriptors: const <GATTDescriptor>[],
            ),
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
          name: Platform.isWindows
              ? null
              : _advertisementName(receiverDisplayAddress, receiverAddress),
          serviceUUIDs: <UUID>[serviceUuid],
          serviceData: _advertisementServiceData(receiverAddress),
        ),
      );
    } catch (error) {
      _onPayload = null;
      _onActivity = null;
      _sessions.clear();
      _acks.clear();
      throw normalizeBleTransportError(error, stage: BleFailureStage.advertise);
    }
    _advertising = true;
  }

  Future<void> stop() async {
    final PeripheralManager? manager = _peripheralManager;
    if (manager == null) {
      _advertising = false;
      _sessions.clear();
      _acks.clear();
      _onActivity = null;
      return;
    }
    if (_advertising) {
      await manager.stopAdvertising();
    }
    await manager.removeAllServices();
    _advertising = false;
    _sessions.clear();
    _acks.clear();
    _onActivity = null;
  }

  Future<void> send({
    required String peripheralId,
    required OfflineTransportPayload payload,
  }) async {
    final CentralManager manager = _central;
    _ensureCentralInitialized();
    await _ensureManagerReady(manager);
    final Peripheral? peripheral = _discoveredPeripherals[peripheralId];
    if (peripheral == null) {
      throw const FormatException('BLE receiver is not available. Scan again and retry.');
    }

    final Uint8List payloadBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(payload.toJson())),
    );

    try {
      await _withTimeout(
        manager.connect(peripheral),
        message: 'BLE receiver connection timed out. Move the devices closer and try again.',
        timeout: _connectTimeout,
      );
      if (Platform.isAndroid) {
        try {
          await _withTimeout(
            manager.requestMTU(peripheral, mtu: 185),
            message: 'BLE MTU request timed out.',
            timeout: _ioTimeout,
          );
        } catch (_) {
          // Continue with the default MTU when the platform rejects the request.
        }
      }
      final List<GATTService> services = await _withTimeout(
        manager.discoverGATT(peripheral),
        message: 'BLE service discovery timed out. Try again.',
        timeout: _gattTimeout,
      );
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

      final int maxLength = await _withTimeout(
        manager.getMaximumWriteLength(
          peripheral,
          type: GATTCharacteristicWriteType.withResponse,
        ),
        message: 'BLE write channel is not responding.',
        timeout: _ioTimeout,
      );
      final int chunkLength = maxLength <= 1 ? 1 : maxLength - 1;

      await _withTimeout(
        manager.writeCharacteristic(
          peripheral,
          writeCharacteristic,
          value: _startFrame(payloadBytes.length),
          type: GATTCharacteristicWriteType.withResponse,
        ),
        message: 'BLE transfer could not start. Try again.',
        timeout: _ioTimeout,
      );

      for (int offset = 0; offset < payloadBytes.length; offset += chunkLength) {
        final int end = (offset + chunkLength).clamp(0, payloadBytes.length);
        final Uint8List frame = Uint8List.fromList(
          <int>[_frameChunk, ...payloadBytes.sublist(offset, end)],
        );
        await _withTimeout(
          manager.writeCharacteristic(
            peripheral,
            writeCharacteristic,
            value: frame,
            type: GATTCharacteristicWriteType.withResponse,
          ),
          message: 'BLE transfer was interrupted while sending.',
          timeout: _ioTimeout,
        );
      }

      await _withTimeout(
        manager.writeCharacteristic(
          peripheral,
          writeCharacteristic,
          value: Uint8List.fromList(const <int>[_frameEnd]),
          type: GATTCharacteristicWriteType.withResponse,
        ),
        message: 'BLE transfer could not finish cleanly.',
        timeout: _ioTimeout,
      );

      final Uint8List ackBytes = await _withTimeout(
        manager.readCharacteristic(
          peripheral,
          ackCharacteristic,
        ),
        message: 'BLE receiver did not acknowledge the transfer.',
        timeout: _ioTimeout,
      );
      final Map<String, dynamic> ack = jsonDecode(utf8.decode(ackBytes)) as Map<String, dynamic>;
      if (ack['accepted'] != true) {
        throw FormatException(ack['message'] as String? ?? 'BLE transfer rejected.');
      }
    } catch (error) {
      throw normalizeBleTransportError(error, stage: BleFailureStage.transfer);
    } finally {
      try {
        await _withTimeout(
          manager.disconnect(peripheral),
          message: 'BLE disconnect timed out.',
          timeout: _disconnectTimeout,
        );
      } catch (_) {
        // Ignore disconnect races when the OS already closed the connection.
      }
    }
  }

  Future<void> dispose() async {
    if (_discovering) {
      try {
        await _withTimeout(
          _centralManager?.stopDiscovery() ?? Future<void>.value(),
          message: 'BLE scan stop timed out.',
          timeout: _ioTimeout,
        );
      } catch (_) {
        // Ignore stop races during disposal.
      }
      _discovering = false;
    }
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

  Future<void> _ensureManagerReady(BluetoothLowEnergyManager manager) async {
    await _authorizeManager(manager);
    if (manager.state == BluetoothLowEnergyState.unknown) {
      try {
        await manager.stateChanged.firstWhere(
          (BluetoothLowEnergyStateChangedEventArgs event) {
            return event.state != BluetoothLowEnergyState.unknown;
          },
        ).timeout(const Duration(seconds: 2));
      } catch (_) {
        // Fall through to the current manager state check below.
      }
    }

    switch (manager.state) {
      case BluetoothLowEnergyState.poweredOn:
        return;
      case BluetoothLowEnergyState.poweredOff:
        throw const SocketException('Bluetooth is turned off. Turn it on and try again.');
      case BluetoothLowEnergyState.unauthorized:
        throw const SocketException(
          'Bluetooth permission is not granted. Allow Bluetooth access and try again.',
        );
      case BluetoothLowEnergyState.unsupported:
        throw UnsupportedError('Bluetooth Low Energy is not supported on this device.');
      case BluetoothLowEnergyState.unknown:
        throw const SocketException('Bluetooth is still initializing. Try again.');
    }
  }

  CentralManager get _central => _centralManager ??= CentralManager();

  PeripheralManager get _peripheral => _peripheralManager ??= PeripheralManager();

  void _ensureCentralInitialized() {
    _discoveredSubscription ??= _central.discovered.listen(
      _handleDiscovered,
      onError: (_) {
        // Ignore malformed discovery events from the plugin; the UI can retry.
      },
    );
  }

  void _ensurePeripheralInitialized() {
    _readRequestedSubscription ??=
        _peripheral.characteristicReadRequested.listen(_handleReadRequested);
    _writeRequestedSubscription ??=
        _peripheral.characteristicWriteRequested.listen(_handleWriteRequested);
  }

  void _handleDiscovered(DiscoveredEventArgs event) {
    try {
      final Advertisement advertisement = event.advertisement;
      if (!_safeServiceUuids(advertisement).contains(serviceUuid)) {
        return;
      }
      final String id = event.peripheral.uuid.toString();
      _discoveredPeripherals[id] = event.peripheral;
      final ReceiverDiscoveryItem? existing = _receivers[id];
      final _AdvertisementReceiverHint? hint = _parseAdvertisementHint(
        advertisement,
      );
      final String? advertisedName = _safeAdvertisementName(advertisement);
      _receivers[id] = ReceiverDiscoveryItem(
        id: id,
        label:
            existing?.metadataVerified == true
                ? existing!.label
                : hint?.label ??
                    advertisedName ??
                    existing?.label ??
                    'bitsend BLE receiver',
        subtitle:
            existing?.metadataVerified == true
                ? existing!.subtitle
                : hint?.preview ??
                    existing?.subtitle ??
                    advertisedName ??
                    'Receiver nearby',
        transport: TransportKind.ble,
        address: existing?.address ?? '',
        rssi: _bestRssi(existing?.rssi, event.rssi),
        lastSeenAt: DateTime.now(),
        metadataVerified: existing?.metadataVerified ?? false,
      );
    } catch (_) {
      // Ignore malformed advertisements instead of surfacing a Flutter error box.
    }
  }

  Future<void> _hydrateReceiverMetadata(CentralManager manager) async {
    final List<MapEntry<String, Peripheral>> entries = _discoveredPeripherals.entries
        .toList(growable: false);
    for (final MapEntry<String, Peripheral> entry in entries) {
      final ReceiverDiscoveryItem? fallback = _receivers[entry.key];
      if (fallback == null) {
        continue;
      }
      _receivers[entry.key] = await _readReceiverMetadata(
        manager,
        peripheral: entry.value,
        fallback: fallback,
      );
    }
  }

  Future<ReceiverDiscoveryItem> _readReceiverMetadata(
    CentralManager manager, {
    required Peripheral peripheral,
    required ReceiverDiscoveryItem fallback,
  }) async {
    try {
      await _withTimeout(
        manager.connect(peripheral),
        message: 'BLE receiver connection timed out. Move the devices closer and try again.',
        timeout: _connectTimeout,
      );
      final List<GATTService> services = await _withTimeout(
        manager.discoverGATT(peripheral),
        message: 'BLE service discovery timed out. Try again.',
        timeout: _gattTimeout,
      );
      final GATTService service = services.firstWhere(
        (GATTService item) => item.uuid == serviceUuid,
      );
      final GATTCharacteristic infoCharacteristic = service.characteristics.firstWhere(
        (GATTCharacteristic item) => item.uuid == receiverInfoCharacteristicUuid,
      );
      final Uint8List infoBytes = await _withTimeout(
        manager.readCharacteristic(
          peripheral,
          infoCharacteristic,
        ),
        message: 'BLE receiver details timed out.',
        timeout: _ioTimeout,
      );
      final Map<String, dynamic> info =
          jsonDecode(utf8.decode(infoBytes)) as Map<String, dynamic>;
      final String address = (info['address'] as String? ?? '').trim();
      final String displayAddress = (info['displayAddress'] as String? ?? '')
          .trim();
      final ChainKind? chain = _parseChain(info['chain'] as String?);
      final ChainNetwork? network = _parseNetwork(info['network'] as String?);
      if (!_isRecognizedAddress(address)) {
        return fallback;
      }
      int? liveRssi = fallback.rssi;
      try {
        liveRssi = await _withTimeout(
          manager.readRSSI(peripheral),
          message: 'BLE signal read timed out.',
          timeout: _ioTimeout,
        );
      } catch (_) {
        liveRssi = fallback.rssi;
      }
      return ReceiverDiscoveryItem(
        id: fallback.id,
        label: _formatReceiverLabel(
          displayAddress.isEmpty ? fallback.label : displayAddress,
          chain,
          network,
        ),
        subtitle: address,
        transport: fallback.transport,
        address: address,
        rssi: _bestRssi(fallback.rssi, liveRssi),
        lastSeenAt: DateTime.now(),
        metadataVerified: true,
      );
    } catch (_) {
      return fallback;
    } finally {
      try {
        await _withTimeout(
          manager.disconnect(peripheral),
          message: 'BLE disconnect timed out.',
          timeout: _disconnectTimeout,
        );
      } catch (_) {
        // Ignore disconnect races when the OS already closed the connection.
      }
    }
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
    final int offset = event.request.offset;
    if (offset < 0 || offset > value.length) {
      await manager.respondReadRequestWithError(
        event.request,
        error: GATTError.invalidOffset,
      );
      return;
    }
    await manager.respondReadRequestWithValue(
      event.request,
      value: offset == 0 ? value : Uint8List.sublistView(value, offset),
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
        _onActivity?.call(
          const TransportActivityNotice(
            transport: TransportKind.ble,
            message: 'Bluetooth sender connected. Receiving handoff...',
          ),
        );
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
        final OfflineTransportPayload transportPayload =
            OfflineTransportPayload.fromJson(payload);
        final TransportReceiveResult result =
            await (_onPayload?.call(transportPayload) ??
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
      _sessions.remove(centralId);
      _acks[centralId] = _ackBytes(
        TransportReceiveResult(
          accepted: false,
          message: error.toString(),
        ),
      );
      await manager.respondWriteRequest(event.request);
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

  Uint8List _receiverInfoBytes({
    required ChainKind receiverChain,
    required ChainNetwork receiverNetwork,
    required String receiverAddress,
    required String receiverDisplayAddress,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, String>{
          'chain': receiverChain.name,
          'network': receiverNetwork.name,
          'address': receiverAddress,
          'displayAddress': receiverDisplayAddress,
        }),
      ),
    );
  }

  Map<UUID, Uint8List> _advertisementServiceData(String receiverAddress) {
    if (!Platform.isWindows) {
      return const <UUID, Uint8List>{};
    }
    return <UUID, Uint8List>{
      serviceUuid: _receiverAdvertisementBytes(receiverAddress),
    };
  }

  Uint8List _receiverAdvertisementBytes(String receiverAddress) {
    final String normalized = receiverAddress.trim();
    final String prefix = normalized.length <= 4
        ? normalized.padRight(4, '_')
        : normalized.substring(0, 4);
    final String suffix = normalized.length <= 4
        ? normalized.padLeft(4, '_')
        : normalized.substring(normalized.length - 4);
    return Uint8List.fromList(
      <int>[
        _advertisementVersion,
        ...utf8.encode(prefix),
        ...utf8.encode(suffix),
      ],
    );
  }

  _AdvertisementReceiverHint? _parseAdvertisementHint(
    Advertisement advertisement,
  ) {
    final Map<UUID, Uint8List> serviceData = _safeServiceData(advertisement);
    final Uint8List? bytes = serviceData[serviceUuid];
    if (bytes == null || bytes.length < 9) {
      return null;
    }
    if (bytes[0] != _advertisementVersion) {
      return null;
    }
    final String prefix = utf8.decode(bytes.sublist(1, 5)).replaceAll('_', '');
    final String suffix = utf8.decode(bytes.sublist(5, 9)).replaceAll('_', '');
    if (prefix.isEmpty && suffix.isEmpty) {
      return null;
    }
    final String preview = suffix.isEmpty ? prefix : '$prefix...$suffix';
    return _AdvertisementReceiverHint(label: 'bitsend $preview', preview: preview);
  }

  String? _safeAdvertisementName(Advertisement advertisement) {
    try {
      return advertisement.name;
    } on UnsupportedError {
      return null;
    }
  }

  Map<UUID, Uint8List> _safeServiceData(Advertisement advertisement) {
    try {
      return advertisement.serviceData;
    } on UnsupportedError {
      return const <UUID, Uint8List>{};
    }
  }

  List<UUID> _safeServiceUuids(Advertisement advertisement) {
    try {
      return advertisement.serviceUUIDs;
    } on UnsupportedError {
      return const <UUID>[];
    }
  }

  int? _bestRssi(int? current, int? candidate) {
    if (candidate == null) {
      return current;
    }
    if (current == null || candidate > current) {
      return candidate;
    }
    return current;
  }

  bool _isRecognizedAddress(String address) {
    final String normalized = address.trim();
    return isValidAddress(normalized) ||
        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalized);
  }

  ChainKind? _parseChain(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final ChainKind chain in ChainKind.values) {
      if (chain.name == raw) {
        return chain;
      }
    }
    return null;
  }

  ChainNetwork? _parseNetwork(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final ChainNetwork network in ChainNetwork.values) {
      if (network.name == raw) {
        return network;
      }
    }
    return null;
  }

  String _formatReceiverLabel(
    String label,
    ChainKind? chain,
    ChainNetwork? network,
  ) {
    if (chain == null || network == null) {
      return label;
    }
    return '$label · ${network.shortLabelFor(chain)} ${chain.shortLabel}';
  }

  int _compareReceivers(ReceiverDiscoveryItem a, ReceiverDiscoveryItem b) {
    if (a.metadataVerified != b.metadataVerified) {
      return a.metadataVerified ? -1 : 1;
    }
    final int rssiA = a.rssi ?? -999;
    final int rssiB = b.rssi ?? -999;
    if (rssiA != rssiB) {
      return rssiB.compareTo(rssiA);
    }
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  String _advertisementName(
    String receiverDisplayAddress,
    String receiverAddress,
  ) {
    final String compactDisplay = receiverDisplayAddress
        .replaceAll('.', '')
        .replaceAll(' ', '')
        .trim();
    final String display = compactDisplay.isEmpty
        ? receiverAddress
        : compactDisplay;
    final String prefix = display.length <= 4 ? display : display.substring(0, 4);
    final String suffix = display.length <= 4
        ? display
        : display.substring(display.length - 4);
    return 'bitsend-$prefix$suffix';
  }

  Future<T> _withTimeout<T>(
    Future<T> future, {
    required String message,
    required Duration timeout,
  }) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      throw TimeoutException(message, timeout);
    }
  }
}

class _BleInboundSession {
  _BleInboundSession({required this.expectedLength});

  final int expectedLength;
  final BytesBuilder bytes = BytesBuilder(copy: false);
}

class _AdvertisementReceiverHint {
  const _AdvertisementReceiverHint({
    required this.label,
    required this.preview,
  });

  final String label;
  final String preview;
}
