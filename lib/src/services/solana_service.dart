import 'dart:async';
import 'dart:typed_data';

import 'package:solana/dto.dart'
    show
        BalanceResult,
        ConfirmationStatus,
        LatestBlockhash,
        SignatureStatus,
        SignatureStatusesResult;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../models/app_models.dart';

class SolanaService {
  SolanaService({required String rpcEndpoint}) : _rpcEndpoint = rpcEndpoint;

  String _rpcEndpoint;

  String get rpcEndpoint => _rpcEndpoint;

  set rpcEndpoint(String value) {
    _rpcEndpoint = value;
  }

  static const Duration _defaultConfirmationTimeout = Duration(seconds: 60);
  static const Duration _defaultAirdropBalanceTimeout = Duration(seconds: 30);

  SolanaClient get client => SolanaClient(
        rpcUrl: Uri.parse(_rpcEndpoint),
        websocketUrl: _websocketEndpoint(_rpcEndpoint),
      );

  RpcClient get rpcClient => client.rpcClient;

  Future<bool> isDevnetReachable() async {
    try {
      await rpcClient.getLatestBlockhash(commitment: Commitment.confirmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> getBalanceLamports(String address) async {
    final BalanceResult result = await rpcClient.getBalance(
      address,
      commitment: Commitment.confirmed,
    );
    return result.value;
  }

  Future<String> requestAirdrop(
    String address, {
    double sol = 1,
    Duration confirmationTimeout = _defaultConfirmationTimeout,
    Duration balanceTimeout = _defaultAirdropBalanceTimeout,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final int lamports = (sol * lamportsPerSol).round();
    final int startingBalance = await getBalanceLamports(address);
    final String signature;
    try {
      signature = await submitAirdropRequest(address, lamports);
    } catch (error) {
      final String message = error.toString().toLowerCase();
      if (message.contains('429') ||
          message.contains('too many requests') ||
          message.contains('rate limit')) {
        throw const FormatException(
          'Devnet airdrop is rate limited right now. Wait a minute and try again.',
        );
      }
      rethrow;
    }

    try {
      await waitForConfirmation(
        signature,
        desiredStatus: ConfirmationStatus.confirmed,
        timeout: confirmationTimeout,
        pollInterval: pollInterval,
      );
    } on TimeoutException {
      await waitForBalanceIncrease(
        address,
        minimumBalanceLamports: startingBalance + lamports,
        timeout: balanceTimeout,
        pollInterval: pollInterval,
      );
    }
    return signature;
  }

  Future<String> submitAirdropRequest(String address, int lamports) {
    return rpcClient.requestAirdrop(
      address,
      lamports,
      commitment: Commitment.confirmed,
    );
  }

  Future<CachedBlockhash> getFreshBlockhash() async {
    final LatestBlockhash latest =
        (await rpcClient.getLatestBlockhash(commitment: Commitment.confirmed))
            .value;
    return CachedBlockhash(
      blockhash: latest.blockhash,
      lastValidBlockHeight: latest.lastValidBlockHeight,
      fetchedAt: DateTime.now(),
    );
  }

  Future<bool> isBlockhashValid(String blockhash) async {
    return (await rpcClient.isBlockhashValid(
      blockhash,
      commitment: Commitment.confirmed,
    ))
        .value;
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
    return rpcClient.sendTransaction(
      encodedTransaction,
      preflightCommitment: Commitment.confirmed,
    );
  }

  Future<SignatureStatus?> getSignatureStatus(String signature) async {
    final SignatureStatusesResult result = await rpcClient.getSignatureStatuses(
      <String>[signature],
      searchTransactionHistory: true,
    );
    if (result.value.isEmpty) {
      return null;
    }
    return result.value.first;
  }

  Future<void> waitForBalanceIncrease(
    String address, {
    required int minimumBalanceLamports,
    Duration timeout = _defaultAirdropBalanceTimeout,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await getBalanceLamports(address) >= minimumBalanceLamports) {
        return;
      }
      await Future<void>.delayed(pollInterval);
    }

    throw TimeoutException(
      'Timed out waiting for the devnet airdrop balance update.',
      timeout,
    );
  }

  Future<void> waitForConfirmation(
    String signature, {
    ConfirmationStatus desiredStatus = ConfirmationStatus.confirmed,
    Duration timeout = _defaultConfirmationTimeout,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final SignatureStatus? status = await getSignatureStatus(signature);
      if (status != null) {
        if (status.err != null) {
          throw StateError('Transaction failed: ${status.err}');
        }
        if (_hasReachedConfirmation(
          current: status.confirmationStatus,
          desired: desiredStatus,
        )) {
          return;
        }
      }
      await Future<void>.delayed(pollInterval);
    }

    throw TimeoutException('Timed out waiting for Solana confirmation.', timeout);
  }

  Uri explorerUrlFor(String signature) =>
      Uri.parse('https://explorer.solana.com/tx/$signature?cluster=devnet');

  bool _hasReachedConfirmation({
    required ConfirmationStatus current,
    required ConfirmationStatus desired,
  }) {
    return switch (desired) {
      ConfirmationStatus.processed => true,
      ConfirmationStatus.confirmed =>
        current == ConfirmationStatus.confirmed ||
            current == ConfirmationStatus.finalized,
      ConfirmationStatus.finalized => current == ConfirmationStatus.finalized,
    };
  }

  Uri _websocketEndpoint(String rpcEndpoint) {
    final Uri parsed = Uri.parse(rpcEndpoint);
    final String scheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    return parsed.replace(scheme: scheme);
  }
}
