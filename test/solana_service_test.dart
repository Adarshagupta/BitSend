import 'package:bitsend/src/services/solana_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/dto.dart';

void main() {
  group('SolanaService.waitForConfirmation', () {
    test('waits until a signature reaches confirmed status', () async {
      final _FakeSolanaService service = _FakeSolanaService(
        <SignatureStatus?>[
          null,
          const SignatureStatus(
            slot: 1,
            confirmationStatus: ConfirmationStatus.processed,
            confirmations: 2,
          ),
          const SignatureStatus(
            slot: 2,
            confirmationStatus: ConfirmationStatus.confirmed,
            confirmations: 1,
          ),
        ],
      );

      await service.waitForConfirmation(
        'signature-1',
        timeout: const Duration(milliseconds: 50),
        pollInterval: Duration.zero,
      );

      expect(service.pollCount, 3);
    });

    test('waits for finalized when requested explicitly', () async {
      final _FakeSolanaService service = _FakeSolanaService(
        const <SignatureStatus?>[
          SignatureStatus(
            slot: 1,
            confirmationStatus: ConfirmationStatus.confirmed,
            confirmations: 1,
          ),
          SignatureStatus(
            slot: 2,
            confirmationStatus: ConfirmationStatus.finalized,
            confirmations: null,
          ),
        ],
      );

      await service.waitForConfirmation(
        'signature-2',
        desiredStatus: ConfirmationStatus.finalized,
        timeout: const Duration(milliseconds: 50),
        pollInterval: Duration.zero,
      );

      expect(service.pollCount, 2);
    });

    test('throws when the signature reports an RPC error', () async {
      final _FakeSolanaService service = _FakeSolanaService(
        const <SignatureStatus?>[
          SignatureStatus(
            slot: 1,
            confirmationStatus: ConfirmationStatus.processed,
            confirmations: 1,
            err: <String, dynamic>{'InstructionError': 'custom'},
          ),
        ],
      );

      expect(
        () => service.waitForConfirmation(
          'signature-3',
          timeout: const Duration(milliseconds: 50),
          pollInterval: Duration.zero,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeSolanaService extends SolanaService {
  _FakeSolanaService(this._statuses)
    : super(rpcEndpoint: 'https://api.devnet.solana.com');

  final List<SignatureStatus?> _statuses;
  int pollCount = 0;

  @override
  Future<SignatureStatus?> getSignatureStatus(String signature) async {
    if (_statuses.isEmpty) {
      pollCount += 1;
      return null;
    }
    final int index = pollCount < _statuses.length
        ? pollCount
        : _statuses.length - 1;
    pollCount += 1;
    return _statuses[index];
  }
}
