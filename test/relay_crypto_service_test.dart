import 'dart:math';
import 'dart:typed_data';

import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/relay_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encrypts and decrypts relay capsules', () async {
    final RelayCryptoService service = RelayCryptoService(random: Random(7));
    final UltrasonicTransferPacket packet = UltrasonicTransferPacket.create(
      chain: ChainKind.ethereum,
      network: ChainNetwork.testnet,
      transferId: '123e4567-e89b-12d3-a456-426614174000',
      createdAt: DateTime.utc(2026, 3, 14, 12),
      sessionToken: '00112233445566778899aabbccddeeff',
      signedTransactionBytes: Uint8List.fromList(<int>[10, 20, 30, 40]),
    );

    final RelayCapsule capsule = await service.encryptPacket(
      packet: packet,
      relayId: 'relay-session-1',
      sessionToken: '00112233445566778899aabbccddeeff',
    );
    final UltrasonicTransferPacket decrypted = await service.decryptCapsule(
      capsule: capsule,
      sessionToken: '00112233445566778899aabbccddeeff',
    );

    expect(capsule.relayId, 'relay-session-1');
    expect(decrypted.transferId, packet.transferId);
    expect(decrypted.sessionToken, packet.sessionToken);
    expect(
      decrypted.signedTransactionBytes,
      orderedEquals(packet.signedTransactionBytes),
    );
  });
}
