import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import '../models/app_models.dart';

class EthereumService {
  EthereumService({required String rpcEndpoint}) : _rpcEndpoint = rpcEndpoint;

  static const int sepoliaChainId = 11155111;
  static const int transferGasLimit = 21000;
  static const Duration _defaultConfirmationTimeout = Duration(seconds: 75);

  String _rpcEndpoint;

  String get rpcEndpoint => _rpcEndpoint;

  set rpcEndpoint(String value) {
    _rpcEndpoint = value;
  }

  Future<T> _withClient<T>(Future<T> Function(Web3Client client) action) async {
    final http.Client httpClient = http.Client();
    final Web3Client client = Web3Client(_rpcEndpoint, httpClient);
    try {
      return await action(client);
    } finally {
      client.dispose();
      httpClient.close();
    }
  }

  bool isValidAddress(String address) {
    final String normalized = address.trim();
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalized)) {
      return false;
    }
    try {
      EthereumAddress.fromHex(normalized);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isReachable() async {
    try {
      await _withClient((Web3Client client) => client.getBlockNumber());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> getBalanceBaseUnits(String address) async {
    final EthereumAddress account = EthereumAddress.fromHex(address);
    final EtherAmount balance = await _withClient(
      (Web3Client client) => client.getBalance(account),
    );
    return balance.getInWei.toInt();
  }

  Future<EthereumPreparedContext> prepareTransferContext(
    String senderAddress,
  ) async {
    final EthereumAddress sender = EthereumAddress.fromHex(senderAddress);
    return _withClient((Web3Client client) async {
      final int nonce = await client.getTransactionCount(
        sender,
        atBlock: const BlockNum.pending(),
      );
      final EtherAmount gasPrice = await client.getGasPrice();
      return EthereumPreparedContext(
        nonce: nonce,
        gasPriceWei: gasPrice.getInWei.toInt(),
        chainId: sepoliaChainId,
        fetchedAt: DateTime.now(),
      );
    });
  }

  Future<OfflineEnvelope> createSignedEnvelope({
    required EthPrivateKey sender,
    required String senderAddress,
    required String receiverAddress,
    required int amountBaseUnits,
    required EthereumPreparedContext preparedContext,
    required String transferId,
    required DateTime createdAt,
    required TransportKind transportKind,
  }) async {
    final Uint8List signed = await _withClient(
      (Web3Client client) => client.signTransaction(
        sender,
        Transaction(
          to: EthereumAddress.fromHex(receiverAddress),
          value: EtherAmount.inWei(BigInt.from(amountBaseUnits)),
          nonce: preparedContext.nonce,
          gasPrice: EtherAmount.inWei(BigInt.from(preparedContext.gasPriceWei)),
          maxGas: transferGasLimit,
        ),
        chainId: preparedContext.chainId,
      ),
    );

    return OfflineEnvelope.create(
      transferId: transferId,
      createdAt: createdAt,
      chain: ChainKind.ethereum,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      amountLamports: amountBaseUnits,
      signedTransactionBase64: base64Encode(signed),
      transportKind: transportKind,
    );
  }

  ValidatedTransactionDetails validateEnvelope(OfflineEnvelope envelope) {
    if (envelope.version != 1) {
      throw const FormatException('Unsupported payload version.');
    }
    if (envelope.chain != ChainKind.ethereum) {
      throw const FormatException('Envelope is not an Ethereum transfer.');
    }
    if (!envelope.isChecksumValid) {
      throw const FormatException('Envelope checksum mismatch.');
    }
    if (!isValidAddress(envelope.senderAddress) ||
        !isValidAddress(envelope.receiverAddress)) {
      throw const FormatException('Envelope addresses are invalid.');
    }
    final Uint8List signedBytes = base64Decode(envelope.signedTransactionBase64);
    final String transactionHash = _hexFromBytes(
      web3_crypto.keccak256(signedBytes),
    );
    return ValidatedTransactionDetails(
      chain: ChainKind.ethereum,
      senderAddress: envelope.senderAddress,
      receiverAddress: envelope.receiverAddress,
      amountLamports: envelope.amountLamports,
      transactionSignature: transactionHash,
    );
  }

  Future<String> sendTransferNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String receiverAddress,
    required int amountBaseUnits,
  }) async {
    final EthereumPreparedContext context = await prepareTransferContext(
      senderAddress,
    );
    final OfflineEnvelope envelope = await createSignedEnvelope(
      sender: sender,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      amountBaseUnits: amountBaseUnits,
      preparedContext: context,
      transferId: 'direct-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      transportKind: TransportKind.hotspot,
    );
    return broadcastSignedTransaction(envelope.signedTransactionBase64);
  }

  Future<String> broadcastSignedTransaction(String encodedTransaction) async {
    final Uint8List signedBytes = base64Decode(encodedTransaction);
    try {
      return await _withClient(
        (Web3Client client) => client.sendRawTransaction(signedBytes),
      );
    } catch (error) {
      throw FormatException(_messageForBroadcastError(error));
    }
  }

  Future<TransactionReceipt?> getTransactionReceipt(String hash) {
    return _withClient(
      (Web3Client client) => client.getTransactionReceipt(hash),
    );
  }

  Future<void> waitForConfirmation(
    String hash, {
    Duration timeout = _defaultConfirmationTimeout,
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final TransactionReceipt? receipt = await getTransactionReceipt(hash);
      if (receipt != null) {
        if (receipt.status == false) {
          throw const FormatException(
            'Ethereum rejected the signed transfer during settlement.',
          );
        }
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw TimeoutException(
      'Timed out waiting for Ethereum confirmation.',
      timeout,
    );
  }

  Uri explorerUrlFor(String hash) {
    return Uri.parse('https://sepolia.etherscan.io/tx/$hash');
  }

  String _messageForBroadcastError(Object error) {
    final String message = error.toString().toLowerCase();
    if (message.contains('nonce too low')) {
      return 'The Ethereum nonce is stale. Refresh readiness and sign again.';
    }
    if (message.contains('replacement transaction underpriced')) {
      return 'Ethereum rejected the transfer because gas pricing is stale. Refresh readiness and resend.';
    }
    if (message.contains('insufficient funds')) {
      return 'The offline wallet balance is too low for the amount plus gas.';
    }
    if (message.contains('intrinsic gas too low')) {
      return 'Ethereum rejected the transfer because gas settings are too low.';
    }
    return 'Ethereum rejected the signed transfer. Refresh readiness and resend.';
  }

  String _hexFromBytes(List<int> bytes) {
    final StringBuffer buffer = StringBuffer('0x');
    for (final int byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
