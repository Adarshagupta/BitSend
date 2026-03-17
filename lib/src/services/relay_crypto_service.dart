import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';

import '../models/app_models.dart';

class RelayCryptoService {
  RelayCryptoService({AesGcm? algorithm, Random? random})
    : _algorithm = algorithm ?? AesGcm.with256bits(),
      _random = random ?? Random.secure();

  final AesGcm _algorithm;
  final Random _random;

  Future<RelayCapsule> encryptPacket({
    required UltrasonicTransferPacket packet,
    required String relayId,
    required String sessionToken,
  }) async {
    final Uint8List nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => _random.nextInt(256)),
    );
    final SecretKey key = _deriveKey(
      sessionToken: sessionToken,
      relayId: relayId,
    );
    final SecretBox box = await _algorithm.encrypt(
      packet.toBytes(),
      secretKey: key,
      nonce: nonce,
    );
    return RelayCapsule(
      version: RelayCapsule.currentVersion,
      relayId: relayId,
      createdAt: packet.createdAt,
      nonceBase64: base64Encode(box.nonce),
      encryptedPacketBase64: base64Encode(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
    );
  }

  Future<UltrasonicTransferPacket> decryptCapsule({
    required RelayCapsule capsule,
    required String sessionToken,
  }) async {
    final SecretKey key = _deriveKey(
      sessionToken: sessionToken,
      relayId: capsule.relayId,
    );
    final Uint8List encrypted = Uint8List.fromList(
      base64Decode(capsule.encryptedPacketBase64),
    );
    if (encrypted.length < 16) {
      throw const FormatException('Relay capsule is too short.');
    }
    final SecretBox box = SecretBox(
      encrypted.sublist(0, encrypted.length - 16),
      nonce: base64Decode(capsule.nonceBase64),
      mac: Mac(encrypted.sublist(encrypted.length - 16)),
    );
    final List<int> bytes = await _algorithm.decrypt(
      box,
      secretKey: key,
    );
    return UltrasonicTransferPacket.fromBytes(Uint8List.fromList(bytes));
  }

  SecretKey _deriveKey({
    required String sessionToken,
    required String relayId,
  }) {
    final Digest digest = sha256.convert(
      utf8.encode('${sessionToken.trim().toLowerCase()}:$relayId'),
    );
    return SecretKey(Uint8List.fromList(digest.bytes));
  }
}
