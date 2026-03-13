import 'dart:async';
import 'dart:typed_data';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:solana/src/encoder/signed_tx.dart';
import 'package:solana/src/rpc/dto/dto.dart'
    show BalanceResult, LatestBlockhash, SignatureStatus, SignatureStatusesResult;

import '../models/app_models.dart';

class SolanaService {
  SolanaService({required String rpcEndpoint}) : _rpcEndpoint = rpcEndpoint;

  String _rpcEndpoint;

  String get rpcEndpoint => _rpcEndpoint;

  set rpcEndpoint(String value) {
    _rpcEndpoint = value;
  }

  SolanaClient get client => SolanaClient(
        rpcUrl: Uri.parse(_rpcEndpoint),
        websocketUrl: _websocketEndpoint(_rpcEndpoint),
      );

  Future<bool> isDevnetReachable() async {
    try {
      final String health = await client.rpcClient.getHealth();
      return health == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<int> getBalanceLamports(String address) async {
    final BalanceResult result =
        await client.rpcClient.getBalance(address, commitment: Commitment.confirmed);
    return result.value;
  }

  Future<void> requestAirdrop(String address, {double sol = 1}) async {
    await client.requestAirdrop(
      address: Ed25519HDPublicKey.fromBase58(address),
      lamports: (sol * lamportsPerSol).round(),
      commitment: Commitment.confirmed,
    );
  }

  Future<CachedBlockhash> getFreshBlockhash() async {
    final LatestBlockhash latest =
        (await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed)).value;
    return CachedBlockhash(
      blockhash: latest.blockhash,
      lastValidBlockHeight: latest.lastValidBlockHeight,
      fetchedAt: DateTime.now(),
    );
  }

  Future<OfflineEnvelope> createSignedEnvelope({
    required Ed25519HDKeyPair sender,
    required String receiverAddress,
    required int lamports,
    required CachedBlockhash cachedBlockhash,
    required String transferId,
    required DateTime createdAt,
    required TransportKind transportKind,
  }) async {
    final Message message = Message.only(
      SystemInstruction.transfer(
        fundingAccount: sender.publicKey,
        recipientAccount: Ed25519HDPublicKey.fromBase58(receiverAddress),
        lamports: lamports,
      ),
    );

    final SignedTx signedTx = await signTransaction(
      LatestBlockhash(
        blockhash: cachedBlockhash.blockhash,
        lastValidBlockHeight: cachedBlockhash.lastValidBlockHeight,
      ),
      message,
      <Ed25519HDKeyPair>[sender],
    );

    return OfflineEnvelope.create(
      transferId: transferId,
      createdAt: createdAt,
      senderAddress: sender.address,
      receiverAddress: receiverAddress,
      amountLamports: lamports,
      signedTransactionBase64: signedTx.encode(),
      transportKind: transportKind,
    );
  }

  Future<String> sendTransferNow({
    required Ed25519HDKeyPair sender,
    required String receiverAddress,
    required int lamports,
  }) async {
    final CachedBlockhash cachedBlockhash = await getFreshBlockhash();
    final Message message = Message.only(
      SystemInstruction.transfer(
        fundingAccount: sender.publicKey,
        recipientAccount: Ed25519HDPublicKey.fromBase58(receiverAddress),
        lamports: lamports,
      ),
    );

    final SignedTx signedTx = await signTransaction(
      LatestBlockhash(
        blockhash: cachedBlockhash.blockhash,
        lastValidBlockHeight: cachedBlockhash.lastValidBlockHeight,
      ),
      message,
      <Ed25519HDKeyPair>[sender],
    );

    return broadcastSignedTransaction(signedTx.encode());
  }

  ValidatedTransactionDetails validateEnvelope(OfflineEnvelope envelope) {
    if (envelope.version != 1) {
      throw const FormatException('Unsupported payload version.');
    }
    if (!envelope.isChecksumValid) {
      throw const FormatException('Envelope checksum mismatch.');
    }
    if (!isValidAddress(envelope.senderAddress) || !isValidAddress(envelope.receiverAddress)) {
      throw const FormatException('Envelope addresses are invalid.');
    }

    final SignedTx signedTx = SignedTx.decode(envelope.signedTransactionBase64);
    final Message message = signedTx.decompileMessage();
    if (message.instructions.length != 1) {
      throw const FormatException('Only single transfer transactions are supported.');
    }

    final Instruction instruction = message.instructions.single;
    if (instruction.programId.toBase58() != SystemProgram.programId) {
      throw const FormatException('Transaction is not a system transfer.');
    }
    if (instruction.accounts.length < 2) {
      throw const FormatException('Transfer accounts are incomplete.');
    }

    final String senderAddress = instruction.accounts.first.pubKey.toBase58();
    final String receiverAddress = instruction.accounts[1].pubKey.toBase58();
    final List<int> data = instruction.data.toList();
    if (data.length < 12) {
      throw const FormatException('Transfer instruction data is malformed.');
    }
    const List<int> transferPrefix = <int>[2, 0, 0, 0];
    for (int i = 0; i < transferPrefix.length; i++) {
      if (data[i] != transferPrefix[i]) {
        throw const FormatException('Transaction is not a standard transfer instruction.');
      }
    }

    final ByteData byteData = ByteData.sublistView(Uint8List.fromList(data.sublist(4, 12)));
    final int amountLamports = byteData.getUint64(0, Endian.little);

    if (senderAddress != envelope.senderAddress) {
      throw const FormatException('Envelope sender does not match the signed transaction.');
    }
    if (receiverAddress != envelope.receiverAddress) {
      throw const FormatException('Envelope receiver does not match the signed transaction.');
    }
    if (amountLamports != envelope.amountLamports) {
      throw const FormatException('Envelope amount does not match the signed transaction.');
    }

    return ValidatedTransactionDetails(
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      amountLamports: amountLamports,
      transactionSignature: signedTx.id,
    );
  }

  Future<String> broadcastSignedTransaction(String encodedTransaction) async {
    return client.rpcClient.sendTransaction(
      encodedTransaction,
      preflightCommitment: Commitment.confirmed,
    );
  }

  Future<SignatureStatus?> getSignatureStatus(String signature) async {
    final SignatureStatusesResult result =
        await client.rpcClient.getSignatureStatuses(<String>[signature], searchTransactionHistory: true);
    if (result.value.isEmpty) {
      return null;
    }
    return result.value.first;
  }

  Future<void> waitForConfirmation(
    String signature, {
    Duration timeout = const Duration(seconds: 25),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final SignatureStatus? status = await getSignatureStatus(signature);
      if (status != null) {
        if (status.err != null) {
          throw StateError('Transaction failed: ${status.err}');
        }
        if (status.confirmationStatus == Commitment.confirmed ||
            status.confirmationStatus == Commitment.finalized) {
          return;
        }
      }
      await Future<void>.delayed(pollInterval);
    }

    throw TimeoutException('Timed out waiting for Solana confirmation.', timeout);
  }

  Uri explorerUrlFor(String signature) =>
      Uri.parse('https://explorer.solana.com/tx/$signature?cluster=devnet');

  Uri _websocketEndpoint(String rpcEndpoint) {
    final Uri parsed = Uri.parse(rpcEndpoint);
    final String scheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    return parsed.replace(scheme: scheme);
  }
}
