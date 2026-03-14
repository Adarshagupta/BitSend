import 'package:bitsend/src/services/solana_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

void main() {
  group('SolanaService.requestAirdrop', () {
    test('falls back to balance polling when confirmation lags', () async {
      final _FakeAirdropSolanaService service = _FakeAirdropSolanaService(
        balances: <int>[500000000, 500000000, 1500000000],
        confirmationError: TimeoutException(
          'Timed out waiting for Solana confirmation.',
        ),
      );

      final String signature = await service.requestAirdrop(
        '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        pollInterval: Duration.zero,
        balanceTimeout: const Duration(milliseconds: 50),
        confirmationTimeout: const Duration(milliseconds: 1),
      );

      expect(signature, 'airdrop-signature');
      expect(service.submittedLamports, lamportsPerSol);
      expect(service.balanceReads, 3);
    });
  });

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

  group('SolanaService.validateEnvelope', () {
    test('validates an envelope created by the sender flow', () async {
      final SolanaService service = SolanaService(
        rpcEndpoint: 'https://api.devnet.solana.com',
      );
      final Ed25519HDKeyPair sender = await Ed25519HDKeyPair.random();
      final Ed25519HDKeyPair receiver = await Ed25519HDKeyPair.random();

      final envelope = await service.createSignedEnvelope(
        sender: sender,
        receiverAddress: receiver.address,
        lamports: 250000000,
        cachedBlockhash: CachedBlockhash(
          blockhash: '11111111111111111111111111111111',
          lastValidBlockHeight: 1,
          fetchedAt: DateTime(2026, 3, 14, 12),
        ),
        transferId: 'tx-validate',
        createdAt: DateTime(2026, 3, 14, 12),
        transportKind: TransportKind.hotspot,
      );

      final details = service.validateEnvelope(envelope);

      expect(details.senderAddress, sender.address);
      expect(details.receiverAddress, receiver.address);
      expect(details.amountLamports, 250000000);
      expect(details.transactionSignature, isNotEmpty);
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

class _FakeAirdropSolanaService extends SolanaService {
  _FakeAirdropSolanaService({
    required List<int> balances,
    this.confirmationError,
  }) : _balances = balances,
       super(rpcEndpoint: 'https://api.devnet.solana.com');

  final List<int> _balances;
  final Object? confirmationError;
  int balanceReads = 0;
  int? submittedLamports;

  @override
  Future<int> getBalanceLamports(String address) async {
    final int index = balanceReads < _balances.length
        ? balanceReads
        : _balances.length - 1;
    balanceReads += 1;
    return _balances[index];
  }

  @override
  Future<String> submitAirdropRequest(String address, int lamports) async {
    submittedLamports = lamports;
    return 'airdrop-signature';
  }

  @override
  Future<void> waitForConfirmation(
    String signature, {
    ConfirmationStatus desiredStatus = ConfirmationStatus.confirmed,
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    if (confirmationError != null) {
      throw confirmationError!;
    }
  }
}
