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
  static const int mainnetChainId = 1;
  static const int baseSepoliaChainId = 84532;
  static const int baseMainnetChainId = 8453;
  static const int bnbTestnetChainId = 97;
  static const int bnbMainnetChainId = 56;
  static const int polygonAmoyChainId = 80002;
  static const int polygonMainnetChainId = 137;
  static const int transferGasLimit = 21000;
  static const Duration _defaultConfirmationTimeout = Duration(seconds: 75);
  static final EthereumAddress _ensRegistryAddress = EthereumAddress.fromHex(
    '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e',
  );
  static final ContractFunction _ensResolverFunction = ContractAbi.fromJson(
    '''
[
  {
    "inputs":[{"internalType":"bytes32","name":"node","type":"bytes32"}],
    "name":"resolver",
    "outputs":[{"internalType":"address","name":"","type":"address"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
    'ENSRegistry',
  ).functions.single;
  static final ContractFunction _ensAddrFunction = ContractAbi.fromJson(
    '''
[
  {
    "inputs":[{"internalType":"bytes32","name":"node","type":"bytes32"}],
    "name":"addr",
    "outputs":[{"internalType":"address","name":"","type":"address"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
    'ENSResolver',
  ).functions.single;
  static final ContractFunction _ensTextFunction = ContractAbi.fromJson(
    '''
[
  {
    "inputs":[
      {"internalType":"bytes32","name":"node","type":"bytes32"},
      {"internalType":"string","name":"key","type":"string"}
    ],
    "name":"text",
    "outputs":[{"internalType":"string","name":"","type":"string"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
    'ENSResolver',
  ).functions.single;
  static final ContractFunction _ensSetTextFunction = ContractAbi.fromJson(
    '''
[
  {
    "inputs":[
      {"internalType":"bytes32","name":"node","type":"bytes32"},
      {"internalType":"string","name":"key","type":"string"},
      {"internalType":"string","name":"value","type":"string"}
    ],
    "name":"setText",
    "outputs":[],
    "stateMutability":"nonpayable",
    "type":"function"
  }
]
''',
    'ENSResolver',
  ).functions.single;
  static final ContractFunction _erc20BalanceOfFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": true,
    "inputs": [{"name":"account","type":"address"}],
    "name": "balanceOf",
    "outputs": [{"name":"","type":"uint256"}],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _erc20AllowanceFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": true,
    "inputs": [
      {"name":"owner","type":"address"},
      {"name":"spender","type":"address"}
    ],
    "name": "allowance",
    "outputs": [{"name":"","type":"uint256"}],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _erc20TransferFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": false,
    "inputs": [
      {"name":"to","type":"address"},
      {"name":"value","type":"uint256"}
    ],
    "name": "transfer",
    "outputs": [{"name":"","type":"bool"}],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _erc20ApproveFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": false,
    "inputs": [
      {"name":"spender","type":"address"},
      {"name":"value","type":"uint256"}
    ],
    "name": "approve",
    "outputs": [{"name":"","type":"bool"}],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _erc20DecimalsFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name":"","type":"uint8"}],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _erc20SymbolFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "symbol",
    "outputs": [{"name":"","type":"string"}],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _erc20NameFunction = ContractAbi.fromJson(
    '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "name",
    "outputs": [{"name":"","type":"string"}],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''',
    'ERC20',
  ).functions.single;
  static final ContractFunction _offlineVoucherCreateEscrowFunction =
      ContractAbi.fromJson(
        '''
[
  {
    "inputs": [
      {"internalType":"bytes32","name":"escrowId","type":"bytes32"},
      {"internalType":"address","name":"asset","type":"address"},
      {"internalType":"uint256","name":"amount","type":"uint256"},
      {"internalType":"uint64","name":"expiry","type":"uint64"},
      {"internalType":"bytes32","name":"voucherRoot","type":"bytes32"}
    ],
    "name":"createEscrow",
    "outputs":[],
    "stateMutability":"payable",
    "type":"function"
  }
]
''',
        'BitSendOfflineVoucherEscrow',
      ).functions.single;
  static final ContractFunction _offlineVoucherClaimFunction =
      ContractAbi.fromJson(
        '''
[
  {
    "inputs": [
      {"internalType":"bytes32","name":"escrowId","type":"bytes32"},
      {"internalType":"bytes32","name":"voucherId","type":"bytes32"},
      {"internalType":"uint256","name":"amount","type":"uint256"},
      {"internalType":"uint64","name":"voucherExpiry","type":"uint64"},
      {"internalType":"bytes32","name":"nonce","type":"bytes32"},
      {"internalType":"address","name":"receiver","type":"address"},
      {"internalType":"bytes","name":"ownerSignature","type":"bytes"},
      {"internalType":"bytes32[]","name":"voucherProof","type":"bytes32[]"}
    ],
    "name":"claimVoucher",
    "outputs":[],
    "stateMutability":"nonpayable",
    "type":"function"
  }
]
''',
        'BitSendOfflineVoucherEscrow',
      ).functions.single;
  static final ContractFunction _offlineVoucherRefundFunction =
      ContractAbi.fromJson(
        '''
[
  {
    "inputs":[{"internalType":"bytes32","name":"escrowId","type":"bytes32"}],
    "name":"refundExpiredEscrow",
    "outputs":[],
    "stateMutability":"nonpayable",
    "type":"function"
  }
]
''',
        'BitSendOfflineVoucherEscrow',
      ).functions.single;
  static final ContractFunction _offlineVoucherEscrowViewFunction =
      ContractAbi.fromJson(
        '''
[
  {
    "inputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],
    "name":"escrows",
    "outputs":[
      {"internalType":"address","name":"owner","type":"address"},
      {"internalType":"address","name":"asset","type":"address"},
      {"internalType":"uint256","name":"totalAmount","type":"uint256"},
      {"internalType":"uint256","name":"remainingAmount","type":"uint256"},
      {"internalType":"uint64","name":"expiry","type":"uint64"},
      {"internalType":"bytes32","name":"voucherRoot","type":"bytes32"},
      {"internalType":"bool","name":"refunded","type":"bool"}
    ],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
        'BitSendOfflineVoucherEscrow',
      ).functions.single;
  static final ContractFunction _offlineVoucherClaimedViewFunction =
      ContractAbi.fromJson(
        '''
[
  {
    "inputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],
    "name":"claimedVoucherIds",
    "outputs":[{"internalType":"bool","name":"","type":"bool"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
        'BitSendOfflineVoucherEscrow',
      ).functions.single;
  static final String _transferEventTopic = web3_crypto.bytesToHex(
    web3_crypto.keccak256(
      Uint8List.fromList(utf8.encode('Transfer(address,address,uint256)')),
    ),
    include0x: true,
  );
  static final ContractFunction _supportsInterfaceFunction =
      ContractAbi.fromJson(
        '''
[
  {
    "inputs":[{"name":"interfaceId","type":"bytes4"}],
    "name":"supportsInterface",
    "outputs":[{"name":"","type":"bool"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
        'ERC165',
      ).functions.single;
  static final ContractFunction _erc721OwnerOfFunction = ContractAbi.fromJson(
    '''
[
  {
    "inputs":[{"name":"tokenId","type":"uint256"}],
    "name":"ownerOf",
    "outputs":[{"name":"","type":"address"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
    'ERC721',
  ).functions.single;
  static final ContractFunction _erc721TokenUriFunction = ContractAbi.fromJson(
    '''
[
  {
    "inputs":[{"name":"tokenId","type":"uint256"}],
    "name":"tokenURI",
    "outputs":[{"name":"","type":"string"}],
    "stateMutability":"view",
    "type":"function"
  }
]
''',
    'ERC721',
  ).functions.single;

  String _rpcEndpoint;
  ChainKind chain = ChainKind.ethereum;
  ChainNetwork network = ChainNetwork.testnet;

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

  bool isEnsName(String value) {
    final String normalized = value.trim().toLowerCase();
    if (!normalized.endsWith('.eth') || normalized.contains(RegExp(r'\s'))) {
      return false;
    }
    final List<String> labels = normalized.split('.');
    return labels.length >= 2 &&
        labels.every(
          (String label) =>
              label.isNotEmpty &&
              RegExp(r'^[a-z0-9-]+$').hasMatch(label),
        );
  }

  Future<String> resolveEnsAddress(String name) async {
    final String normalized = name.trim().toLowerCase();
    if (!isEnsName(normalized)) {
      throw const FormatException('Enter a valid .eth name.');
    }

    final Uint8List node = _ensNamehash(normalized);
    final List<dynamic> registryResult = await _callViewFunction(
      contract: _ensRegistryAddress,
      function: _ensResolverFunction,
      params: <dynamic>[node],
    );
    final EthereumAddress resolver = registryResult.single as EthereumAddress;
    if (_isZeroAddress(resolver)) {
      throw const FormatException(
        'ENS name does not have a resolver on this network.',
      );
    }

    final List<dynamic> addressResult = await _callViewFunction(
      contract: resolver,
      function: _ensAddrFunction,
      params: <dynamic>[node],
    );
    final EthereumAddress resolved = addressResult.single as EthereumAddress;
    if (_isZeroAddress(resolved)) {
      throw const FormatException(
        'ENS name does not resolve to an Ethereum address.',
      );
    }
    return resolved.hexEip55;
  }

  Future<String> readEnsTextRecord({
    required String name,
    required String key,
  }) async {
    final String normalized = name.trim().toLowerCase();
    if (!isEnsName(normalized)) {
      throw const FormatException('Enter a valid .eth name.');
    }
    final Uint8List node = _ensNamehash(normalized);
    final EthereumAddress resolver = await _resolverForNode(node);
    final List<dynamic> record = await _callViewFunction(
      contract: resolver,
      function: _ensTextFunction,
      params: <dynamic>[node, key],
    );
    return (record.single as String).trim();
  }

  Future<EnsPaymentPreference> readEnsPaymentPreference(String name) async {
    final String normalized = name.trim().toLowerCase();
    Future<String> safeRead(String key) async {
      try {
        return await readEnsTextRecord(name: normalized, key: key);
      } catch (_) {
        return '';
      }
    }

    final List<String> values = await Future.wait(<Future<String>>[
      safeRead(EnsPaymentPreference.chainRecordKey),
      safeRead(EnsPaymentPreference.tokenRecordKey),
    ]);
    return EnsPaymentPreference(
      ensName: normalized,
      preferredChain: values[0],
      preferredToken: values[1],
    );
  }

  Future<List<String>> writeEnsPaymentPreference({
    required EthPrivateKey signer,
    required String name,
    String preferredChain = '',
    String preferredToken = '',
  }) async {
    final String normalized = name.trim().toLowerCase();
    if (!isEnsName(normalized)) {
      throw const FormatException('Enter a valid .eth name.');
    }
    final Uint8List node = _ensNamehash(normalized);
    final EthereumAddress resolver = await _resolverForNode(node);
    final Map<String, String> entries = <String, String>{
      EnsPaymentPreference.chainRecordKey: preferredChain.trim(),
      EnsPaymentPreference.tokenRecordKey: preferredToken.trim(),
    };
    if (entries.values.every((String value) => value.isEmpty)) {
      throw const FormatException('Enter at least one ENS preference to save.');
    }
    return _withClient((Web3Client client) async {
      final List<String> hashes = <String>[];
      for (final MapEntry<String, String> entry in entries.entries) {
        final String txHash = await client.sendTransaction(
          signer,
          Transaction(
            to: resolver,
            data: _ensSetTextFunction.encodeCall(<dynamic>[
              node,
              entry.key,
              entry.value,
            ]),
          ),
          chainId: _expectedChainId,
        );
        hashes.add(txHash);
      }
      return hashes;
    });
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

  Future<int> getTokenBalanceBaseUnits({
    required String ownerAddress,
    required String contractAddress,
  }) async {
    final List<dynamic> result = await _callViewFunction(
      contract: EthereumAddress.fromHex(contractAddress),
      function: _erc20BalanceOfFunction,
      params: <dynamic>[EthereumAddress.fromHex(ownerAddress)],
    );
    final BigInt balance = result.single as BigInt;
    return balance.toInt();
  }

  Future<int> getTokenAllowanceBaseUnits({
    required String ownerAddress,
    required String spenderAddress,
    required String contractAddress,
  }) async {
    final List<dynamic> result = await _callViewFunction(
      contract: EthereumAddress.fromHex(contractAddress),
      function: _erc20AllowanceFunction,
      params: <dynamic>[
        EthereumAddress.fromHex(ownerAddress),
        EthereumAddress.fromHex(spenderAddress),
      ],
    );
    final BigInt allowance = result.single as BigInt;
    return allowance.toInt();
  }

  Future<int> estimateContractCallGas({
    required String senderAddress,
    required String toAddress,
    String dataHex = '0x',
    int valueBaseUnits = 0,
  }) async {
    final Map<String, Object> payload = <String, Object>{
      'from': EthereumAddress.fromHex(senderAddress).hexEip55,
      'to': EthereumAddress.fromHex(toAddress).hexEip55,
    };
    if (dataHex.trim().isNotEmpty && dataHex.trim() != '0x') {
      payload['data'] = dataHex.trim();
    }
    if (valueBaseUnits > 0) {
      payload['value'] = '0x${valueBaseUnits.toRadixString(16)}';
    }
    final Object? result = await _rpcRequest('eth_estimateGas', <Object>[payload]);
    if (result is! String || result.isEmpty) {
      throw const FormatException(
        'Ethereum RPC returned malformed gas estimate.',
      );
    }
    return web3_crypto.hexToDartInt(result);
  }

  Future<int> estimateTokenTransferGas({
    required String senderAddress,
    required String receiverAddress,
    required String contractAddress,
    required int amountBaseUnits,
  }) async {
    final Object? result = await _rpcRequest(
      'eth_estimateGas',
      <Object>[
        <String, Object>{
          'from': EthereumAddress.fromHex(senderAddress).hexEip55,
          'to': EthereumAddress.fromHex(contractAddress).hexEip55,
          'data': web3_crypto.bytesToHex(
            _erc20TransferFunction.encodeCall(<dynamic>[
              EthereumAddress.fromHex(receiverAddress),
              BigInt.from(amountBaseUnits),
            ]),
            include0x: true,
          ),
        },
      ],
    );
    if (result is! String || result.isEmpty) {
      throw const FormatException(
        'Ethereum RPC returned malformed token gas estimate.',
      );
    }
    return web3_crypto.hexToDartInt(result);
  }

  Future<int> estimateTokenApprovalGas({
    required String senderAddress,
    required String spenderAddress,
    required String contractAddress,
    required int amountBaseUnits,
  }) {
    return estimateContractCallGas(
      senderAddress: senderAddress,
      toAddress: contractAddress,
      dataHex: web3_crypto.bytesToHex(
        _erc20ApproveFunction.encodeCall(<dynamic>[
          EthereumAddress.fromHex(spenderAddress),
          BigInt.from(amountBaseUnits),
        ]),
        include0x: true,
      ),
    );
  }

  Future<int> getBlockNumber() async {
    final Object? result = await _rpcRequest('eth_blockNumber', const <Object>[]);
    if (result is! String || result.isEmpty) {
      throw const FormatException('Ethereum RPC returned malformed block data.');
    }
    return web3_crypto.hexToDartInt(result);
  }

  Future<Set<String>> discoverErc20Contracts({
    required String ownerAddress,
    int? fromBlock,
    int? toBlock,
    int chunkSize = 100000,
  }) async {
    final String ownerTopic = _topicForAddress(ownerAddress);
    final int endBlock = toBlock ?? await getBlockNumber();
    final int startBlock = (() {
      final int candidate = fromBlock ?? endBlock - chunkSize + 1;
      return candidate < 0 ? 0 : candidate;
    })();
    final Set<String> contracts = <String>{};
    for (
      int chunkStart = startBlock;
      chunkStart <= endBlock;
      chunkStart += chunkSize
    ) {
      final int chunkEnd = (() {
        final int candidate = chunkStart + chunkSize - 1;
        return candidate > endBlock ? endBlock : candidate;
      })();
      final List<Map<String, dynamic>> incomingLogs = await _getLogs(
        fromBlock: chunkStart,
        toBlock: chunkEnd,
        topics: <Object?>[_transferEventTopic, null, ownerTopic],
      );
      final List<Map<String, dynamic>> outgoingLogs = await _getLogs(
        fromBlock: chunkStart,
        toBlock: chunkEnd,
        topics: <Object?>[_transferEventTopic, ownerTopic],
      );
      for (final Map<String, dynamic> log in <Map<String, dynamic>>[
        ...incomingLogs,
        ...outgoingLogs,
      ]) {
        final String address = ((log['address'] as String?) ?? '').trim();
        if (isValidAddress(address)) {
          contracts.add(EthereumAddress.fromHex(address).hexEip55);
        }
      }
    }
    return contracts;
  }

  Future<TrackedAssetDefinition> describeErc20Asset(
    String contractAddress,
  ) async {
    final EthereumAddress contract = EthereumAddress.fromHex(contractAddress);
    final String symbol =
        await _readErc20TextMetadata(
          contract: contract,
          function: _erc20SymbolFunction,
          fallback: contract.hexEip55.substring(0, 6),
        );
    final String name =
        await _readErc20TextMetadata(
          contract: contract,
          function: _erc20NameFunction,
          fallback: 'Token $symbol',
        );
    final int decimals = await _readErc20Decimals(contract);
    return TrackedAssetDefinition(
      id: '${chain.name}:${network.name}:${contract.hexEip55.toLowerCase()}',
      chain: chain,
      network: network,
      symbol: symbol,
      displayName: name,
      decimals: decimals,
      contractAddress: contract.hexEip55,
    );
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
        chainId: _expectedChainId,
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
      chain: chain,
      network: network,
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
    if (envelope.chain != chain) {
      throw FormatException('Envelope is not a ${chain.label} transfer.');
    }
    if (envelope.network != network) {
      throw FormatException(
        'Envelope network does not match the active ${chain.label} network.',
      );
    }
    if (!envelope.isChecksumValid) {
      throw const FormatException('Envelope checksum mismatch.');
    }
    if (!isValidAddress(envelope.senderAddress) ||
        !isValidAddress(envelope.receiverAddress)) {
      throw const FormatException('Envelope addresses are invalid.');
    }
    final ValidatedTransactionDetails details = validateSignedTransactionBytes(
      base64Decode(envelope.signedTransactionBase64),
    );
    if (details.senderAddress != envelope.senderAddress) {
      throw FormatException(
        'Envelope sender does not match the signed ${chain.label} transaction.',
      );
    }
    if (details.receiverAddress != envelope.receiverAddress) {
      throw FormatException(
        'Envelope receiver does not match the signed ${chain.label} transaction.',
      );
    }
    if (details.amountLamports != envelope.amountLamports) {
      throw FormatException(
        'Envelope amount does not match the signed ${chain.label} transaction.',
      );
    }
    return details;
  }

  ValidatedTransactionDetails validateSignedTransactionBytes(
    Uint8List signedBytes,
  ) {
    final _DecodedLegacyEthereumTransaction transaction =
        _decodeLegacySignedTransaction(signedBytes);
    if (transaction.chainId != _expectedChainId) {
      throw FormatException(
        'Signed transaction network does not match the active ${chain.label} network.',
      );
    }
    if (transaction.to == null) {
      throw const FormatException(
        'Contract creation transactions are not supported in offline handoff.',
      );
    }
    if (transaction.data.isNotEmpty) {
      throw FormatException(
        'Only simple ${chain.label} value transfers are supported.',
      );
    }
    final String transactionHash = _hexFromBytes(
      web3_crypto.keccak256(signedBytes),
    );
    return ValidatedTransactionDetails(
      chain: chain,
      network: network,
      senderAddress: transaction.from.hexEip55,
      receiverAddress: transaction.to!.hexEip55,
      amountLamports: transaction.value.toInt(),
      transactionSignature: transactionHash,
    );
  }

  Future<String> sendTransferNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String receiverAddress,
    required int amountBaseUnits,
    int? gasPriceWeiOverride,
  }) async {
    final EthereumPreparedContext context = await prepareTransferContext(
      senderAddress,
    );
    final EthereumPreparedContext effectiveContext =
        gasPriceWeiOverride == null
        ? context
        : EthereumPreparedContext(
            nonce: context.nonce,
            gasPriceWei: gasPriceWeiOverride,
            chainId: context.chainId,
            fetchedAt: context.fetchedAt,
          );
    final OfflineEnvelope envelope = await createSignedEnvelope(
      sender: sender,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      amountBaseUnits: amountBaseUnits,
      preparedContext: effectiveContext,
      transferId: 'direct-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      transportKind: TransportKind.hotspot,
    );
    return broadcastSignedTransaction(envelope.signedTransactionBase64);
  }

  Future<String> sendTokenTransferNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String receiverAddress,
    required String contractAddress,
    required int amountBaseUnits,
    int? gasPriceWeiOverride,
  }) async {
    final EthereumPreparedContext context = await prepareTransferContext(
      senderAddress,
    );
    final int gasLimit = await estimateTokenTransferGas(
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      contractAddress: contractAddress,
      amountBaseUnits: amountBaseUnits,
    );
    final Uint8List signed = await _withClient(
      (Web3Client client) => client.signTransaction(
        sender,
        Transaction(
          to: EthereumAddress.fromHex(contractAddress),
          nonce: context.nonce,
          gasPrice: EtherAmount.inWei(
            BigInt.from(gasPriceWeiOverride ?? context.gasPriceWei),
          ),
          maxGas: gasLimit,
          data: _erc20TransferFunction.encodeCall(<dynamic>[
            EthereumAddress.fromHex(receiverAddress),
            BigInt.from(amountBaseUnits),
          ]),
        ),
        chainId: context.chainId,
      ),
    );
    try {
      return await _withClient(
        (Web3Client client) => client.sendRawTransaction(signed),
      );
    } catch (error) {
      throw FormatException(_messageForBroadcastError(error));
    }
  }

  Future<String> sendContractTransactionNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String toAddress,
    String dataHex = '0x',
    int valueBaseUnits = 0,
    int? gasLimit,
    int? gasPriceWeiOverride,
  }) async {
    final EthereumPreparedContext context = await prepareTransferContext(
      senderAddress,
    );
    final int resolvedGasLimit =
        gasLimit ??
        await estimateContractCallGas(
          senderAddress: senderAddress,
          toAddress: toAddress,
          dataHex: dataHex,
          valueBaseUnits: valueBaseUnits,
        );
    final Uint8List signed = await _withClient(
      (Web3Client client) => client.signTransaction(
        sender,
        Transaction(
          to: EthereumAddress.fromHex(toAddress),
          value: valueBaseUnits <= 0
              ? null
              : EtherAmount.inWei(BigInt.from(valueBaseUnits)),
          nonce: context.nonce,
          gasPrice: EtherAmount.inWei(
            BigInt.from(gasPriceWeiOverride ?? context.gasPriceWei),
          ),
          maxGas: resolvedGasLimit,
          data: dataHex.trim().isEmpty || dataHex.trim() == '0x'
              ? null
              : web3_crypto.hexToBytes(dataHex),
        ),
        chainId: context.chainId,
      ),
    );
    try {
      return await _withClient(
        (Web3Client client) => client.sendRawTransaction(signed),
      );
    } catch (error) {
      throw FormatException(_messageForBroadcastError(error));
    }
  }

  Future<String> sendApproveNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String spenderAddress,
    required String contractAddress,
    required int amountBaseUnits,
    int? gasPriceWeiOverride,
  }) async {
    final int gasLimit = await estimateTokenApprovalGas(
      senderAddress: senderAddress,
      spenderAddress: spenderAddress,
      contractAddress: contractAddress,
      amountBaseUnits: amountBaseUnits,
    );
    return sendContractTransactionNow(
      sender: sender,
      senderAddress: senderAddress,
      toAddress: contractAddress,
      dataHex: web3_crypto.bytesToHex(
        _erc20ApproveFunction.encodeCall(<dynamic>[
          EthereumAddress.fromHex(spenderAddress),
          BigInt.from(amountBaseUnits),
        ]),
        include0x: true,
      ),
      gasLimit: gasLimit,
      gasPriceWeiOverride: gasPriceWeiOverride,
    );
  }

  Future<String> createOfflineVoucherEscrowNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String contractAddress,
    required String escrowId,
    String? assetContractAddress,
    required int amountBaseUnits,
    required DateTime expiryAt,
    required String voucherRoot,
    int? gasPriceWeiOverride,
  }) async {
    final bool nativeAsset =
        assetContractAddress == null || assetContractAddress.trim().isEmpty;
    return sendContractTransactionNow(
      sender: sender,
      senderAddress: senderAddress,
      toAddress: contractAddress,
      valueBaseUnits: nativeAsset ? amountBaseUnits : 0,
      dataHex: web3_crypto.bytesToHex(
        _offlineVoucherCreateEscrowFunction.encodeCall(<dynamic>[
          web3_crypto.hexToBytes(escrowId),
          EthereumAddress.fromHex(
            nativeAsset
                ? '0x0000000000000000000000000000000000000000'
                : assetContractAddress!,
          ),
          BigInt.from(amountBaseUnits),
          BigInt.from(expiryAt.toUtc().millisecondsSinceEpoch ~/ 1000),
          web3_crypto.hexToBytes(voucherRoot),
        ]),
        include0x: true,
      ),
      gasPriceWeiOverride: gasPriceWeiOverride,
    );
  }

  Future<String> claimOfflineVoucherNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String contractAddress,
    required OfflineVoucherLeaf voucher,
    required String receiverAddress,
    required String assignmentSignatureHex,
    required List<String> voucherProof,
    int? gasPriceWeiOverride,
  }) async {
    return sendContractTransactionNow(
      sender: sender,
      senderAddress: senderAddress,
      toAddress: contractAddress,
      dataHex: web3_crypto.bytesToHex(
        _offlineVoucherClaimFunction.encodeCall(<dynamic>[
          web3_crypto.hexToBytes(voucher.escrowId),
          web3_crypto.hexToBytes(voucher.voucherId),
          BigInt.parse(voucher.amountBaseUnits),
          BigInt.from(voucher.expiryAt.toUtc().millisecondsSinceEpoch ~/ 1000),
          web3_crypto.hexToBytes(voucher.nonce),
          EthereumAddress.fromHex(receiverAddress),
          web3_crypto.hexToBytes(assignmentSignatureHex),
          voucherProof.map(web3_crypto.hexToBytes).toList(growable: false),
        ]),
        include0x: true,
      ),
      gasPriceWeiOverride: gasPriceWeiOverride,
    );
  }

  Future<String> refundOfflineVoucherEscrowNow({
    required EthPrivateKey sender,
    required String senderAddress,
    required String contractAddress,
    required String escrowId,
    int? gasPriceWeiOverride,
  }) async {
    return sendContractTransactionNow(
      sender: sender,
      senderAddress: senderAddress,
      toAddress: contractAddress,
      dataHex: web3_crypto.bytesToHex(
        _offlineVoucherRefundFunction.encodeCall(<dynamic>[
          web3_crypto.hexToBytes(escrowId),
        ]),
        include0x: true,
      ),
      gasPriceWeiOverride: gasPriceWeiOverride,
    );
  }

  Future<OfflineVoucherOnChainEscrow?> getOfflineVoucherEscrow({
    required String contractAddress,
    required String escrowId,
  }) async {
    final List<dynamic> values = await _callViewFunction(
      contract: EthereumAddress.fromHex(contractAddress),
      function: _offlineVoucherEscrowViewFunction,
      params: <dynamic>[web3_crypto.hexToBytes(escrowId)],
    );
    final EthereumAddress owner = values[0] as EthereumAddress;
    if (owner.hexNo0x == '0000000000000000000000000000000000000000') {
      return null;
    }
    final EthereumAddress asset = values[1] as EthereumAddress;
    final BigInt totalAmount = values[2] as BigInt;
    final BigInt remainingAmount = values[3] as BigInt;
    final BigInt expiry = values[4] as BigInt;
    final Uint8List voucherRoot = values[5] as Uint8List;
    final bool refunded = values[6] as bool;
    return OfflineVoucherOnChainEscrow(
      ownerAddress: owner.hexEip55,
      assetContractAddress: asset.hexNo0x ==
              '0000000000000000000000000000000000000000'
          ? ''
          : asset.hexEip55,
      totalAmountBaseUnits: totalAmount.toString(),
      remainingAmountBaseUnits: remainingAmount.toString(),
      expiryAt: DateTime.fromMillisecondsSinceEpoch(
        expiry.toInt() * 1000,
        isUtc: true,
      ),
      voucherRoot: web3_crypto.bytesToHex(voucherRoot, include0x: true),
      refunded: refunded,
    );
  }

  Future<bool> isOfflineVoucherClaimed({
    required String contractAddress,
    required String voucherId,
  }) async {
    final List<dynamic> values = await _callViewFunction(
      contract: EthereumAddress.fromHex(contractAddress),
      function: _offlineVoucherClaimedViewFunction,
      params: <dynamic>[web3_crypto.hexToBytes(voucherId)],
    );
    return values.single as bool;
  }

  String signPersonalMessageHex({
    required EthPrivateKey signer,
    required String message,
  }) {
    return web3_crypto.bytesToHex(
      signer.signPersonalMessageToUint8List(
        Uint8List.fromList(utf8.encode(message)),
      ),
      include0x: true,
    );
  }

  String signPayloadHex({
    required EthPrivateKey signer,
    required Uint8List payload,
  }) {
    return web3_crypto.bytesToHex(
      signer.signToUint8List(payload),
      include0x: true,
    );
  }

  Future<List<NftHolding>> discoverErc721Holdings({
    required String ownerAddress,
    int? fromBlock,
    int? toBlock,
    int chunkSize = 100000,
  }) async {
    final String ownerTopic = _topicForAddress(ownerAddress);
    final int endBlock = toBlock ?? await getBlockNumber();
    final int startBlock = (() {
      final int candidate = fromBlock ?? endBlock - chunkSize + 1;
      return candidate < 0 ? 0 : candidate;
    })();
    final Map<String, Set<String>> ownedTokenIds = <String, Set<String>>{};
    for (
      int chunkStart = startBlock;
      chunkStart <= endBlock;
      chunkStart += chunkSize
    ) {
      final int chunkEnd = (() {
        final int candidate = chunkStart + chunkSize - 1;
        return candidate > endBlock ? endBlock : candidate;
      })();
      final List<Map<String, dynamic>> incomingLogs = await _getLogs(
        fromBlock: chunkStart,
        toBlock: chunkEnd,
        topics: <Object?>[_transferEventTopic, null, ownerTopic],
      );
      final List<Map<String, dynamic>> outgoingLogs = await _getLogs(
        fromBlock: chunkStart,
        toBlock: chunkEnd,
        topics: <Object?>[_transferEventTopic, ownerTopic],
      );
      for (final Map<String, dynamic> log in incomingLogs) {
        _applyErc721Log(log, ownedTokenIds, add: true);
      }
      for (final Map<String, dynamic> log in outgoingLogs) {
        _applyErc721Log(log, ownedTokenIds, add: false);
      }
    }

    final List<NftHolding> holdings = <NftHolding>[];
    for (final MapEntry<String, Set<String>> entry in ownedTokenIds.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      final EthereumAddress contract = EthereumAddress.fromHex(entry.key);
      if (!await _supportsErc721(contract)) {
        continue;
      }
      String collectionName = '';
      String symbol = '';
      try {
        collectionName = await _readErc20TextMetadata(
          contract: contract,
          function: _erc20NameFunction,
          fallback: 'NFT Collection',
        );
      } catch (_) {}
      try {
        symbol = await _readErc20TextMetadata(
          contract: contract,
          function: _erc20SymbolFunction,
          fallback: 'NFT',
        );
      } catch (_) {}
      for (final String tokenId in entry.value) {
        try {
          final EthereumAddress owner = await _ownerOf(
            contract: contract,
            tokenId: tokenId,
          );
          if (owner.hexEip55.toLowerCase() !=
              EthereumAddress.fromHex(ownerAddress).hexEip55.toLowerCase()) {
            continue;
          }
          holdings.add(
            NftHolding(
              chain: chain,
              network: network,
              contractAddress: contract.hexEip55,
              tokenId: tokenId,
              ownerAddress: owner.hexEip55,
              updatedAt: DateTime.now(),
              collectionName: collectionName,
              symbol: symbol,
              tokenUri: await _readTokenUri(contract: contract, tokenId: tokenId),
            ),
          );
        } catch (_) {
          // Skip tokens that can no longer be resolved.
        }
      }
    }
    holdings.sort((NftHolding a, NftHolding b) {
      final int collectionCompare = a.resolvedCollectionName.compareTo(
        b.resolvedCollectionName,
      );
      if (collectionCompare != 0) {
        return collectionCompare;
      }
      return a.tokenId.compareTo(b.tokenId);
    });
    return holdings;
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

  Future<TransactionReceipt?> getTransactionReceipt(String hash) async {
    final Object? response = await _rpcRequest(
      'eth_getTransactionReceipt',
      <Object>[hash],
    );
    if (response == null) {
      return null;
    }
    if (response is! Map<String, dynamic>) {
      throw const FormatException(
        'Ethereum RPC returned malformed receipt data.',
      );
    }
    return _parseTransactionReceipt(response);
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
          throw FormatException(
            '${chain.label} rejected the signed transfer during settlement.',
          );
        }
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw TimeoutException(
      'Timed out waiting for ${chain.label} confirmation.',
      timeout,
    );
  }

  Uri explorerUrlFor(String hash) {
    final String host = switch ((chain, network)) {
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'etherscan.io',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'sepolia.etherscan.io',
      (ChainKind.base, ChainNetwork.mainnet) => 'basescan.org',
      (ChainKind.base, ChainNetwork.testnet) => 'sepolia.basescan.org',
      (ChainKind.bnb, ChainNetwork.mainnet) => 'bscscan.com',
      (ChainKind.bnb, ChainNetwork.testnet) => 'testnet.bscscan.com',
      (ChainKind.polygon, ChainNetwork.mainnet) => 'polygonscan.com',
      (ChainKind.polygon, ChainNetwork.testnet) => 'amoy.polygonscan.com',
      (ChainKind.solana, _) => throw StateError(
        'EthereumService cannot build a Solana explorer URL.',
      ),
    };
    return Uri.parse('https://$host/tx/$hash');
  }

  Future<Object?> _rpcRequest(
    String method,
    List<Object> params,
  ) async {
    final http.Client client = http.Client();
    try {
      final http.Response response = await client
          .post(
            Uri.parse(_rpcEndpoint),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'jsonrpc': '2.0',
              'id': 1,
              'method': method,
              'params': params,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException(
          'Ethereum RPC request failed (${response.statusCode}).',
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Ethereum RPC returned a malformed response.',
        );
      }
      final Map<String, dynamic> payload = decoded;
      final Object? error = payload['error'];
      if (error is Map<String, dynamic>) {
        final Object? message = error['message'];
        throw FormatException(
          message is String && message.isNotEmpty
              ? message
              : 'Ethereum RPC request failed.',
        );
      }
      final Object? result = payload['result'];
      return result;
    } finally {
      client.close();
    }
  }

  Future<List<dynamic>> _callViewFunction({
    required EthereumAddress contract,
    required ContractFunction function,
    required List<dynamic> params,
  }) async {
    final Object? result = await _ethCallRaw(
      contract: contract,
      data: web3_crypto.bytesToHex(
        function.encodeCall(params),
        include0x: true,
      ),
    );
    if (result is! String || result.isEmpty) {
      throw const FormatException('Ethereum RPC returned malformed call data.');
    }
    return function.decodeReturnValues(result);
  }

  Future<Object?> _ethCallRaw({
    required EthereumAddress contract,
    required String data,
  }) {
    return _rpcRequest(
      'eth_call',
      <Object>[
        <String, Object>{'to': contract.hexEip55, 'data': data},
        'latest',
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _getLogs({
    required int fromBlock,
    required int toBlock,
    required List<Object?> topics,
  }) async {
    final Object? result = await _rpcRequest(
      'eth_getLogs',
      <Object>[
        <String, Object?>{
          'fromBlock': '0x${fromBlock.toRadixString(16)}',
          'toBlock': '0x${toBlock.toRadixString(16)}',
          'topics': topics,
        },
      ],
    );
    if (result is! List<dynamic>) {
      throw const FormatException('Ethereum RPC returned malformed log data.');
    }
    return result
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void _applyErc721Log(
    Map<String, dynamic> log,
    Map<String, Set<String>> ownedTokenIds, {
    required bool add,
  }) {
    final String address = ((log['address'] as String?) ?? '').trim();
    final List<dynamic> topics = (log['topics'] as List<dynamic>?) ?? const <dynamic>[];
    if (!isValidAddress(address) || topics.length < 4) {
      return;
    }
    final String tokenIdHex = '${topics[3] ?? ''}'.trim();
    if (!tokenIdHex.startsWith('0x')) {
      return;
    }
    final String normalizedAddress = EthereumAddress.fromHex(address).hexEip55;
    final String tokenId = BigInt.parse(tokenIdHex.substring(2), radix: 16)
        .toString();
    final Set<String> tokens = ownedTokenIds.putIfAbsent(
      normalizedAddress,
      () => <String>{},
    );
    if (add) {
      tokens.add(tokenId);
    } else {
      tokens.remove(tokenId);
    }
  }

  Future<bool> _supportsErc721(EthereumAddress contract) async {
    try {
      final List<dynamic> result = await _callViewFunction(
        contract: contract,
        function: _supportsInterfaceFunction,
        params: <dynamic>[Uint8List.fromList(const <int>[0x80, 0xac, 0x58, 0xcd])],
      );
      final Object value = result.single;
      if (value is bool) {
        return value;
      }
    } catch (_) {
      // Fall through.
    }
    return false;
  }

  Future<EthereumAddress> _ownerOf({
    required EthereumAddress contract,
    required String tokenId,
  }) async {
    final List<dynamic> result = await _callViewFunction(
      contract: contract,
      function: _erc721OwnerOfFunction,
      params: <dynamic>[BigInt.parse(tokenId)],
    );
    return result.single as EthereumAddress;
  }

  Future<String?> _readTokenUri({
    required EthereumAddress contract,
    required String tokenId,
  }) async {
    try {
      final List<dynamic> result = await _callViewFunction(
        contract: contract,
        function: _erc721TokenUriFunction,
        params: <dynamic>[BigInt.parse(tokenId)],
      );
      final String value = (result.single as String).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<String> _readErc20TextMetadata({
    required EthereumAddress contract,
    required ContractFunction function,
    required String fallback,
  }) async {
    try {
      final List<dynamic> values = await _callViewFunction(
        contract: contract,
        function: function,
        params: const <dynamic>[],
      );
      final String value = (values.single as String).trim();
      if (value.isNotEmpty) {
        return value;
      }
    } catch (_) {
      // Some contracts return bytes32 instead of string.
    }
    final String selector = function.name == 'symbol' ? '0x95d89b41' : '0x06fdde03';
    final Object? raw = await _ethCallRaw(contract: contract, data: selector);
    if (raw is String && raw.length >= 66) {
      final String decoded = _decodeBytes32String(raw);
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }
    return fallback;
  }

  Future<int> _readErc20Decimals(EthereumAddress contract) async {
    try {
      final List<dynamic> values = await _callViewFunction(
        contract: contract,
        function: _erc20DecimalsFunction,
        params: const <dynamic>[],
      );
      final Object value = values.single;
      if (value is BigInt) {
        return value.toInt();
      }
      if (value is int) {
        return value;
      }
    } catch (_) {
      // Ignore and fall back.
    }
    return 18;
  }

  String _decodeBytes32String(String rawHex) {
    try {
      final Uint8List bytes = Uint8List.fromList(web3_crypto.hexToBytes(rawHex));
      final List<int> compact = bytes.takeWhile((int byte) => byte != 0).toList(
        growable: false,
      );
      return utf8.decode(compact, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }

  String _topicForAddress(String address) {
    final String normalized = EthereumAddress.fromHex(address).hexNo0x.toLowerCase();
    return '0x${normalized.padLeft(64, '0')}';
  }

  Future<EthereumAddress> _resolverForNode(Uint8List node) async {
    final List<dynamic> registryResult = await _callViewFunction(
      contract: _ensRegistryAddress,
      function: _ensResolverFunction,
      params: <dynamic>[node],
    );
    final EthereumAddress resolver = registryResult.single as EthereumAddress;
    if (_isZeroAddress(resolver)) {
      throw const FormatException(
        'ENS name does not have a resolver on this network.',
      );
    }
    return resolver;
  }

  TransactionReceipt _parseTransactionReceipt(Map<String, dynamic> json) {
    String requiredHex(String key) {
      final Object? value = json[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
      throw FormatException('Ethereum receipt is missing "$key".');
    }

    String? optionalHex(String key) {
      final Object? value = json[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
      return null;
    }

    final String? from = optionalHex('from');
    final String? to = optionalHex('to');
    final String? gasUsed = optionalHex('gasUsed');
    final String? effectiveGasPrice = optionalHex('effectiveGasPrice');
    final String? contractAddress = optionalHex('contractAddress');
    final String? status = optionalHex('status');

    return TransactionReceipt(
      transactionHash: web3_crypto.hexToBytes(requiredHex('transactionHash')),
      transactionIndex: web3_crypto.hexToDartInt(
        requiredHex('transactionIndex'),
      ),
      blockHash: web3_crypto.hexToBytes(requiredHex('blockHash')),
      blockNumber: BlockNum.exact(
        web3_crypto.hexToDartInt(requiredHex('blockNumber')),
      ),
      from: _parseOptionalAddress(from),
      to: _parseOptionalAddress(to),
      cumulativeGasUsed: web3_crypto.hexToInt(requiredHex('cumulativeGasUsed')),
      gasUsed: gasUsed == null ? null : web3_crypto.hexToInt(gasUsed),
      effectiveGasPrice: effectiveGasPrice == null
          ? null
          : EtherAmount.inWei(web3_crypto.hexToInt(effectiveGasPrice)),
      contractAddress: _parseOptionalAddress(contractAddress),
      status: status == null ? null : web3_crypto.hexToDartInt(status) == 1,
      logs: (json['logs'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => FilterEvent.fromMap(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  EthereumAddress? _parseOptionalAddress(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return EthereumAddress.fromHex(value);
  }

  int get _expectedChainId =>
      switch ((chain, network)) {
        (ChainKind.ethereum, ChainNetwork.mainnet) => mainnetChainId,
        (ChainKind.ethereum, ChainNetwork.testnet) => sepoliaChainId,
        (ChainKind.base, ChainNetwork.mainnet) => baseMainnetChainId,
        (ChainKind.base, ChainNetwork.testnet) => baseSepoliaChainId,
        (ChainKind.bnb, ChainNetwork.mainnet) => bnbMainnetChainId,
        (ChainKind.bnb, ChainNetwork.testnet) => bnbTestnetChainId,
        (ChainKind.polygon, ChainNetwork.mainnet) => polygonMainnetChainId,
        (ChainKind.polygon, ChainNetwork.testnet) => polygonAmoyChainId,
        (ChainKind.solana, _) => throw StateError(
          'EthereumService cannot prepare Solana chain IDs.',
        ),
      };

  Uint8List _ensNamehash(String name) {
    Uint8List node = Uint8List(32);
    for (final String label in name.split('.').reversed) {
      final Uint8List labelHash = web3_crypto.keccak256(
        Uint8List.fromList(utf8.encode(label)),
      );
      node = Uint8List.fromList(
        web3_crypto.keccak256(Uint8List.fromList(<int>[
          ...node,
          ...labelHash,
        ])),
      );
    }
    return node;
  }

  bool _isZeroAddress(EthereumAddress address) {
    return address.hexNo0x == '0000000000000000000000000000000000000000';
  }

  _DecodedLegacyEthereumTransaction _decodeLegacySignedTransaction(
    Uint8List signedBytes,
  ) {
    if (signedBytes.isEmpty) {
      throw const FormatException('Signed Ethereum transaction is empty.');
    }
    if (signedBytes.first < 0xc0) {
      throw const FormatException(
        'Typed Ethereum transactions are not supported in offline handoff yet.',
      );
    }
    final Object decoded = _decodeRlp(signedBytes);
    if (decoded is! List<Object?> || decoded.length != 9) {
      throw const FormatException('Signed Ethereum transaction is malformed.');
    }

    final int nonce = _rlpInteger(decoded[0]).toInt();
    final BigInt gasPrice = _rlpInteger(decoded[1]);
    final BigInt gasLimit = _rlpInteger(decoded[2]);
    final Uint8List toBytes = _rlpBytes(decoded[3]);
    final BigInt value = _rlpInteger(decoded[4]);
    final Uint8List data = _rlpBytes(decoded[5]);
    final int rawV = _rlpInteger(decoded[6]).toInt();
    final BigInt r = _rlpInteger(decoded[7]);
    final BigInt s = _rlpInteger(decoded[8]);

    final ({int recoveryV, int chainId}) signatureMeta =
        _signatureMetaFromV(rawV);
    final EthereumAddress? to = toBytes.isEmpty
        ? null
        : EthereumAddress.fromHex(
            web3_crypto.bytesToHex(toBytes, include0x: true),
          );
    final Uint8List unsignedPayload = Uint8List.fromList(
      _encodeLegacyTransactionForSigning(
        nonce: nonce,
        gasPrice: gasPrice,
        gasLimit: gasLimit,
        toBytes: toBytes,
        value: value,
        data: data,
        chainId: signatureMeta.chainId,
      ),
    );
    final Uint8List messageHash = web3_crypto.keccak256(unsignedPayload);
    final Uint8List publicKey = web3_crypto.ecRecover(
      messageHash,
      web3_crypto.MsgSignature(r, s, signatureMeta.recoveryV),
    );
    final Uint8List senderAddressBytes = web3_crypto.publicKeyToAddress(
      publicKey,
    );
    final EthereumAddress from = EthereumAddress.fromHex(
      web3_crypto.bytesToHex(senderAddressBytes, include0x: true),
    );

    return _DecodedLegacyEthereumTransaction(
      nonce: nonce,
      gasPrice: gasPrice,
      gasLimit: gasLimit,
      to: to,
      value: value,
      data: data,
      from: from,
      chainId: signatureMeta.chainId,
    );
  }

  List<int> _encodeLegacyTransactionForSigning({
    required int nonce,
    required BigInt gasPrice,
    required BigInt gasLimit,
    required Uint8List toBytes,
    required BigInt value,
    required Uint8List data,
    required int chainId,
  }) {
    return encode(<Object>[
      nonce,
      gasPrice,
      gasLimit,
      toBytes.isEmpty ? '' : toBytes,
      value,
      data,
      chainId,
      0,
      0,
    ]);
  }

  ({int recoveryV, int chainId}) _signatureMetaFromV(int rawV) {
    if (rawV == 27 || rawV == 28) {
      throw const FormatException(
        'Signed Ethereum transaction is missing replay protection.',
      );
    }
    if (rawV < 35) {
      throw const FormatException('Signed Ethereum signature is malformed.');
    }
    final int parity = (rawV - 35) % 2;
    final int chainId = (rawV - 35 - parity) ~/ 2;
    return (recoveryV: 27 + parity, chainId: chainId);
  }

  Uint8List _rlpBytes(Object? value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    throw const FormatException('Signed Ethereum transaction is malformed.');
  }

  BigInt _rlpInteger(Object? value) {
    final Uint8List bytes = _rlpBytes(value);
    if (bytes.isEmpty) {
      return BigInt.zero;
    }
    return web3_crypto.bytesToUnsignedInt(bytes);
  }

  Object _decodeRlp(Uint8List bytes) {
    final _RlpItem item = _decodeRlpItem(bytes, 0);
    if (item.nextOffset != bytes.length) {
      throw const FormatException('Signed Ethereum transaction is malformed.');
    }
    return item.value;
  }

  _RlpItem _decodeRlpItem(Uint8List bytes, int offset) {
    if (offset >= bytes.length) {
      throw const FormatException('Signed Ethereum transaction is malformed.');
    }
    final int prefix = bytes[offset];
    if (prefix <= 0x7f) {
      return _RlpItem(
        value: Uint8List.fromList(<int>[prefix]),
        nextOffset: offset + 1,
      );
    }
    if (prefix <= 0xb7) {
      final int length = prefix - 0x80;
      final int start = offset + 1;
      final int end = start + length;
      if (end > bytes.length) {
        throw const FormatException('Signed Ethereum transaction is malformed.');
      }
      return _RlpItem(
        value: Uint8List.sublistView(bytes, start, end),
        nextOffset: end,
      );
    }
    if (prefix <= 0xbf) {
      final int lengthOfLength = prefix - 0xb7;
      final int start = offset + 1;
      final int end = start + lengthOfLength;
      if (end > bytes.length) {
        throw const FormatException('Signed Ethereum transaction is malformed.');
      }
      final int length = _bigIntToInt(
        web3_crypto.bytesToUnsignedInt(Uint8List.sublistView(bytes, start, end)),
      );
      final int dataStart = end;
      final int dataEnd = dataStart + length;
      if (dataEnd > bytes.length) {
        throw const FormatException('Signed Ethereum transaction is malformed.');
      }
      return _RlpItem(
        value: Uint8List.sublistView(bytes, dataStart, dataEnd),
        nextOffset: dataEnd,
      );
    }
    if (prefix <= 0xf7) {
      final int length = prefix - 0xc0;
      final int start = offset + 1;
      final int end = start + length;
      if (end > bytes.length) {
        throw const FormatException('Signed Ethereum transaction is malformed.');
      }
      final List<Object?> list = <Object?>[];
      int cursor = start;
      while (cursor < end) {
        final _RlpItem item = _decodeRlpItem(bytes, cursor);
        list.add(item.value);
        cursor = item.nextOffset;
      }
      return _RlpItem(value: list, nextOffset: end);
    }

    final int lengthOfLength = prefix - 0xf7;
    final int start = offset + 1;
    final int end = start + lengthOfLength;
    if (end > bytes.length) {
      throw const FormatException('Signed Ethereum transaction is malformed.');
    }
    final int length = _bigIntToInt(
      web3_crypto.bytesToUnsignedInt(Uint8List.sublistView(bytes, start, end)),
    );
    final int dataStart = end;
    final int dataEnd = dataStart + length;
    if (dataEnd > bytes.length) {
      throw const FormatException('Signed Ethereum transaction is malformed.');
    }
    final List<Object?> list = <Object?>[];
    int cursor = dataStart;
    while (cursor < dataEnd) {
      final _RlpItem item = _decodeRlpItem(bytes, cursor);
      list.add(item.value);
      cursor = item.nextOffset;
    }
    return _RlpItem(value: list, nextOffset: dataEnd);
  }

  int _bigIntToInt(BigInt value) {
    if (value > BigInt.from(0x7fffffff)) {
      throw FormatException('Signed ${chain.label} value is too large.');
    }
    return value.toInt();
  }

  String _messageForBroadcastError(Object error) {
    final String message = error.toString().toLowerCase();
    if (message.contains('nonce too low')) {
      return 'The ${chain.label} nonce is stale. Refresh readiness and sign again.';
    }
    if (message.contains('replacement transaction underpriced')) {
      return '${chain.label} rejected the transfer because gas pricing is stale. Refresh readiness and resend.';
    }
    if (message.contains('insufficient funds')) {
      return 'The offline wallet balance is too low for the amount plus gas.';
    }
    if (message.contains('intrinsic gas too low')) {
      return '${chain.label} rejected the transfer because gas settings are too low.';
    }
    return '${chain.label} rejected the signed transfer. Refresh readiness and resend.';
  }

  String _hexFromBytes(List<int> bytes) {
    final StringBuffer buffer = StringBuffer('0x');
    for (final int byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class _DecodedLegacyEthereumTransaction {
  const _DecodedLegacyEthereumTransaction({
    required this.nonce,
    required this.gasPrice,
    required this.gasLimit,
    required this.to,
    required this.value,
    required this.data,
    required this.from,
    required this.chainId,
  });

  final int nonce;
  final BigInt gasPrice;
  final BigInt gasLimit;
  final EthereumAddress? to;
  final BigInt value;
  final Uint8List data;
  final EthereumAddress from;
  final int chainId;
}

class _RlpItem {
  const _RlpItem({required this.value, required this.nextOffset});

  final Object value;
  final int nextOffset;
}
