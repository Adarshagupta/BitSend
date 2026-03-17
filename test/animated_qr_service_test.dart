import 'package:bitsend/src/services/animated_qr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes and reassembles animated QR payloads', () {
    const AnimatedQrService service = AnimatedQrService();
    final AnimatedQrAssembler assembler = AnimatedQrAssembler();
    final List<AnimatedQrFrame> frames = service.encodePayload(
      '{"relayId":"relay-session-1","createdAt":"2026-03-17T10:00:00.000Z","nonceBase64":"abc","encryptedPacketBase64":"def"}',
      maxChunkLength: 32,
    );

    AnimatedQrAssembleResult? result;
    for (final AnimatedQrFrame frame in frames.reversed) {
      result = assembler.addFrame(frame);
    }

    expect(frames.length, greaterThan(1));
    expect(result, isNotNull);
    expect(result!.complete, isTrue);
    expect(result.payload, contains('"relayId":"relay-session-1"'));
  });

  test('rejects mixed animated QR sessions', () {
    const AnimatedQrService service = AnimatedQrService();
    final AnimatedQrAssembler assembler = AnimatedQrAssembler();
    final List<AnimatedQrFrame> first = service.encodePayload(
      '{"relayId":"relay-a","nonceBase64":"abc","encryptedPacketBase64":"def"}',
      maxChunkLength: 24,
    );
    final List<AnimatedQrFrame> second = service.encodePayload(
      '{"relayId":"relay-b","nonceBase64":"ghi","encryptedPacketBase64":"jkl"}',
      maxChunkLength: 24,
    );

    assembler.addFrame(first.first);
    expect(
      () => assembler.addFrame(second.first),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('different transfer session'),
        ),
      ),
    );
  });
}
