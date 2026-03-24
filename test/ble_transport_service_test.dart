import 'package:bitsend/src/services/ble_transport_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps busy advertising failures into accessory guidance', () {
    final Object error = normalizeBleTransportError(
      StateError('Start advertising failed with error code: 2'),
      stage: BleFailureStage.advertise,
    );

    expect(error, isA<FormatException>());
    expect(
      (error as FormatException).message,
      contains('Disconnect AirPods or other Bluetooth devices'),
    );
  });

  test('maps noisy GATT disconnects into a stable connection message', () {
    final Object error = normalizeBleTransportError(
      StateError('GATT is disconnected with status: 133'),
      stage: BleFailureStage.transfer,
    );

    expect(error, isA<FormatException>());
    expect(
      (error as FormatException).message,
      contains('Bluetooth connection could not be established'),
    );
  });

  test('maps scan throttling into a retry message', () {
    final Object error = normalizeBleTransportError(
      StateError('Start discovery failed with error code: 6'),
      stage: BleFailureStage.scan,
    );

    expect(error, isA<FormatException>());
    expect(
      (error as FormatException).message,
      contains('started too often'),
    );
  });
}
