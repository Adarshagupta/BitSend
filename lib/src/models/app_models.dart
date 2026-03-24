import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:solana/solana.dart' show Ed25519HDPublicKey, isValidAddress;
import 'package:web3dart/web3dart.dart' show EthereumAddress;

enum ChainKind { solana, ethereum, base, bnb, polygon }

enum ChainNetwork { testnet, mainnet }

enum WalletEngine { local, bitgo }

extension WalletEngineX on WalletEngine {
  String get label => switch (this) {
    WalletEngine.local => 'Local',
    WalletEngine.bitgo => 'BitGo',
  };

  String get walletLabel => switch (this) {
    WalletEngine.local => 'Local wallet',
    WalletEngine.bitgo => 'BitGo wallet',
  };

  String get shortLabel => switch (this) {
    WalletEngine.local => 'Offline',
    WalletEngine.bitgo => 'Online',
  };

  bool get supportsOfflineHandoff => this == WalletEngine.local;
}

extension ChainKindX on ChainKind {
  bool get isEvm =>
      this == ChainKind.ethereum ||
      this == ChainKind.base ||
      this == ChainKind.bnb ||
      this == ChainKind.polygon;

  String get label => switch (this) {
    ChainKind.solana => 'Solana',
    ChainKind.ethereum => 'Ethereum',
    ChainKind.base => 'Base',
    ChainKind.bnb => 'BNB Chain',
    ChainKind.polygon => 'Polygon',
  };

  String get shortLabel => switch (this) {
    ChainKind.solana => 'SOL',
    ChainKind.ethereum => 'ETH',
    ChainKind.base => 'Base ETH',
    ChainKind.bnb => 'BNB',
    ChainKind.polygon => 'POL',
  };

  String get assetDisplayLabel => switch (this) {
    ChainKind.solana => 'SOL',
    ChainKind.ethereum => 'ETH',
    ChainKind.base => 'Base ETH',
    ChainKind.bnb => 'BNB',
    ChainKind.polygon => 'POL',
  };

  String get networkLabel => switch (this) {
    ChainKind.solana => 'Solana Devnet',
    ChainKind.ethereum => 'Ethereum Sepolia',
    ChainKind.base => 'Base Sepolia',
    ChainKind.bnb => 'BNB Chain Testnet',
    ChainKind.polygon => 'Polygon Amoy',
  };

  String get networkKey => switch (this) {
    ChainKind.solana => 'solana-devnet',
    ChainKind.ethereum => 'ethereum-sepolia',
    ChainKind.base => 'base-sepolia',
    ChainKind.bnb => 'bnb-testnet',
    ChainKind.polygon => 'polygon-amoy',
  };

  String get rpcLabel => switch (this) {
    ChainKind.solana => 'RPC',
    ChainKind.ethereum => 'RPC',
    ChainKind.base => 'RPC',
    ChainKind.bnb => 'RPC',
    ChainKind.polygon => 'RPC',
  };

  String get baseUnitLabel => switch (this) {
    ChainKind.solana => 'lamports',
    ChainKind.ethereum => 'wei',
    ChainKind.base => 'wei',
    ChainKind.bnb => 'wei',
    ChainKind.polygon => 'wei',
  };

  String get receiverHint => switch (this) {
    ChainKind.solana => 'Receiver devnet address',
    ChainKind.ethereum => 'Receiver Sepolia address',
    ChainKind.base => 'Receiver Base Sepolia address',
    ChainKind.bnb => 'Receiver BNB Testnet address',
    ChainKind.polygon => 'Receiver Polygon Amoy address',
  };

  IconData get icon => switch (this) {
    ChainKind.solana => Icons.blur_circular_rounded,
    ChainKind.ethereum => Icons.diamond_rounded,
    ChainKind.base => Icons.layers_rounded,
    ChainKind.bnb => Icons.change_history_rounded,
    ChainKind.polygon => Icons.hub_rounded,
  };

  String get brandAssetPath => switch (this) {
    ChainKind.solana => 'assets/chains/solana.png',
    ChainKind.ethereum => 'assets/chains/ethereum.svg',
    ChainKind.base => 'assets/chains/base.png',
    ChainKind.bnb => 'assets/chains/bnb.svg',
    ChainKind.polygon => 'assets/chains/polygon.png',
  };

  bool get brandAssetIsSvg => switch (this) {
    ChainKind.solana => false,
    ChainKind.ethereum => true,
    ChainKind.base => false,
    ChainKind.bnb => true,
    ChainKind.polygon => false,
  };

  int get decimals => switch (this) {
    ChainKind.solana => 9,
    ChainKind.ethereum => 18,
    ChainKind.base => 18,
    ChainKind.bnb => 18,
    ChainKind.polygon => 18,
  };

  double get minimumFundingAmount => switch (this) {
    ChainKind.solana => 0.05,
    ChainKind.ethereum => 0.01,
    ChainKind.base => 0.01,
    ChainKind.bnb => 0.01,
    ChainKind.polygon => 0.01,
  };

  int get fallbackFeeHeadroomBaseUnits => switch (this) {
    ChainKind.solana => 10000,
    ChainKind.ethereum => 3000000000000000,
    ChainKind.base => 3000000000000000,
    ChainKind.bnb => 3000000000000000,
    ChainKind.polygon => 3000000000000000,
  };

  double amountFromBaseUnits(int value) {
    return value / _pow10(decimals);
  }

  int amountToBaseUnits(double value) {
    return (value * _pow10(decimals)).round();
  }

  String networkLabelFor(ChainNetwork network) {
    return network.labelFor(this);
  }

  String networkKeyFor(ChainNetwork network) {
    return network.keyFor(this);
  }

  String receiverHintFor(ChainNetwork network) {
    return network.receiverHintFor(this);
  }

  String addressScopeNoteFor(ChainNetwork network) {
    return switch (this) {
      ChainKind.solana =>
        'Solana uses a separate address family from EVM networks.',
      ChainKind.ethereum =>
        'Use the 0x address shown for ${network.labelFor(this)}. EVM chains share the same address format, but balances stay on their own network.',
      ChainKind.base =>
        'Use the 0x address shown for ${network.labelFor(this)}. EVM chains share the same address format, but balances stay on their own network.',
      ChainKind.bnb =>
        'Use the 0x address shown for ${network.labelFor(this)}. EVM chains share the same address format, but balances stay on their own network.',
      ChainKind.polygon =>
        'Use the 0x address shown for ${network.labelFor(this)}. EVM chains share the same address format, but balances stay on their own network.',
    };
  }

  double minimumFundingAmountFor(ChainNetwork network) {
    return switch ((this, network)) {
      (ChainKind.solana, ChainNetwork.testnet) => 0.05,
      (ChainKind.solana, ChainNetwork.mainnet) => 0.01,
      (ChainKind.ethereum, ChainNetwork.testnet) => 0.01,
      (ChainKind.ethereum, ChainNetwork.mainnet) => 0.001,
      (ChainKind.base, ChainNetwork.testnet) => 0.01,
      (ChainKind.base, ChainNetwork.mainnet) => 0.001,
      (ChainKind.bnb, ChainNetwork.testnet) => 0.01,
      (ChainKind.bnb, ChainNetwork.mainnet) => 0.001,
      (ChainKind.polygon, ChainNetwork.testnet) => 0.01,
      (ChainKind.polygon, ChainNetwork.mainnet) => 0.001,
    };
  }
}

extension ChainNetworkX on ChainNetwork {
  bool get isMainnet => this == ChainNetwork.mainnet;

  bool get supportsAirdrop => this == ChainNetwork.testnet;

  String labelFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'Solana Devnet',
      (ChainKind.solana, ChainNetwork.mainnet) => 'Solana Mainnet',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'Ethereum Sepolia',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'Ethereum Mainnet',
      (ChainKind.base, ChainNetwork.testnet) => 'Base Sepolia',
      (ChainKind.base, ChainNetwork.mainnet) => 'Base Mainnet',
      (ChainKind.bnb, ChainNetwork.testnet) => 'BNB Chain Testnet',
      (ChainKind.bnb, ChainNetwork.mainnet) => 'BNB Chain Mainnet',
      (ChainKind.polygon, ChainNetwork.testnet) => 'Polygon Amoy',
      (ChainKind.polygon, ChainNetwork.mainnet) => 'Polygon Mainnet',
    };
  }

  String shortLabelFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'Devnet',
      (ChainKind.solana, ChainNetwork.mainnet) => 'Mainnet',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'Sepolia',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'Mainnet',
      (ChainKind.base, ChainNetwork.testnet) => 'Sepolia',
      (ChainKind.base, ChainNetwork.mainnet) => 'Mainnet',
      (ChainKind.bnb, ChainNetwork.testnet) => 'Testnet',
      (ChainKind.bnb, ChainNetwork.mainnet) => 'Mainnet',
      (ChainKind.polygon, ChainNetwork.testnet) => 'Amoy',
      (ChainKind.polygon, ChainNetwork.mainnet) => 'Mainnet',
    };
  }

  String keyFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'solana-devnet',
      (ChainKind.solana, ChainNetwork.mainnet) => 'solana-mainnet',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'ethereum-sepolia',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'ethereum-mainnet',
      (ChainKind.base, ChainNetwork.testnet) => 'base-sepolia',
      (ChainKind.base, ChainNetwork.mainnet) => 'base-mainnet',
      (ChainKind.bnb, ChainNetwork.testnet) => 'bnb-testnet',
      (ChainKind.bnb, ChainNetwork.mainnet) => 'bnb-mainnet',
      (ChainKind.polygon, ChainNetwork.testnet) => 'polygon-amoy',
      (ChainKind.polygon, ChainNetwork.mainnet) => 'polygon-mainnet',
    };
  }

  String receiverHintFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'Receiver devnet address',
      (ChainKind.solana, ChainNetwork.mainnet) => 'Receiver mainnet address',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'Receiver Sepolia address',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'Receiver mainnet address',
      (ChainKind.base, ChainNetwork.testnet) => 'Receiver Base Sepolia address',
      (ChainKind.base, ChainNetwork.mainnet) => 'Receiver Base address',
      (ChainKind.bnb, ChainNetwork.testnet) => 'Receiver BNB Testnet address',
      (ChainKind.bnb, ChainNetwork.mainnet) => 'Receiver BNB address',
      (ChainKind.polygon, ChainNetwork.testnet) =>
        'Receiver Polygon Amoy address',
      (ChainKind.polygon, ChainNetwork.mainnet) => 'Receiver Polygon address',
    };
  }
}

double _pow10(int exponent) {
  double result = 1;
  for (int index = 0; index < exponent; index += 1) {
    result *= 10;
  }
  return result;
}

enum TransportKind { online, hotspot, ble, ultrasonic }

enum GasSpeed { slow, market, fast }

extension GasSpeedX on GasSpeed {
  String get label => switch (this) {
    GasSpeed.slow => 'Slow',
    GasSpeed.market => 'Market',
    GasSpeed.fast => 'Fast',
  };

  double get multiplier => switch (this) {
    GasSpeed.slow => 0.85,
    GasSpeed.market => 1,
    GasSpeed.fast => 1.2,
  };
}

extension TransportKindX on TransportKind {
  String get label => switch (this) {
    TransportKind.online => 'Online transfer',
    TransportKind.hotspot => 'Hotspot / Local Wi-Fi',
    TransportKind.ble => 'Bluetooth Low Energy',
    TransportKind.ultrasonic => 'Ultrasonic',
  };

  String get shortLabel => switch (this) {
    TransportKind.online => 'Online',
    TransportKind.hotspot => 'Hotspot',
    TransportKind.ble => 'BLE',
    TransportKind.ultrasonic => 'Audio',
  };

  IconData get icon => switch (this) {
    TransportKind.online => Icons.public_rounded,
    TransportKind.hotspot => Icons.wifi_tethering_rounded,
    TransportKind.ble => Icons.bluetooth_rounded,
    TransportKind.ultrasonic => Icons.graphic_eq_rounded,
  };
}

enum TransferDirection { inbound, outbound }

extension TransferDirectionX on TransferDirection {
  String get label => switch (this) {
    TransferDirection.inbound => 'Inbound',
    TransferDirection.outbound => 'Outbound',
  };
}

enum TransferStatus {
  created,
  sentOffline,
  receivedPendingBroadcast,
  broadcasting,
  broadcastSubmitted,
  broadcastFailed,
  confirmed,
  expired,
}

extension TransferStatusX on TransferStatus {
  String get label => switch (this) {
    TransferStatus.created => 'Created',
    TransferStatus.sentOffline => 'Sent offline',
    TransferStatus.receivedPendingBroadcast => 'Pending broadcast',
    TransferStatus.broadcasting => 'Broadcasting',
    TransferStatus.broadcastSubmitted => 'Submitted',
    TransferStatus.broadcastFailed => 'Broadcast failed',
    TransferStatus.confirmed => 'Confirmed',
    TransferStatus.expired => 'Expired',
  };

  bool get isError =>
      this == TransferStatus.broadcastFailed || this == TransferStatus.expired;
}

enum WalletSetupMode { created, restored }

enum EvmAccountStrategy { legacySeparated, compatibleUnified }

class WalletProfile {
  const WalletProfile({
    required this.chain,
    required this.address,
    required this.displayAddress,
    required this.seedPhrase,
    required this.mode,
  });

  final ChainKind chain;
  final String address;
  final String displayAddress;
  final String seedPhrase;
  final WalletSetupMode mode;
}

class WalletBackupAccount {
  const WalletBackupAccount({
    required this.chain,
    required this.role,
    required this.accountIndex,
    required this.derivationPath,
    required this.address,
    required this.privateKeyBase64,
  });

  final ChainKind chain;
  final String role;
  final int accountIndex;
  final String derivationPath;
  final String address;
  final String privateKeyBase64;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'chain': chain.name,
    'role': role,
    'accountIndex': accountIndex,
    'derivationPath': derivationPath,
    'address': address,
    'privateKeyBase64': privateKeyBase64,
  };
}

class WalletBackupExport {
  const WalletBackupExport({required this.fileName, required this.filePath});

  final String fileName;
  final String filePath;
}

class SendContact {
  const SendContact({
    required this.id,
    required this.name,
    required this.address,
    required this.chain,
    required this.network,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final ChainKind chain;
  final ChainNetwork network;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'address': address,
    'chain': chain.name,
    'network': network.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SendContact.fromJson(Map<String, dynamic> json) {
    return SendContact(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      chain: ChainKind.values.byName(json['chain'] as String),
      network: ChainNetwork.values.byName(json['network'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class WalletAccountSummary {
  const WalletAccountSummary({
    required this.chain,
    required this.slotIndex,
    required this.mainWallet,
    required this.protectedWallet,
    required this.selected,
  });

  final ChainKind chain;
  final int slotIndex;
  final WalletProfile? mainWallet;
  final WalletProfile? protectedWallet;
  final bool selected;

  String get label => 'Account ${slotIndex + 1}';
}

class TokenAllowanceEntry {
  const TokenAllowanceEntry({
    required this.id,
    required this.chain,
    required this.network,
    required this.ownerAddress,
    required this.assetId,
    required this.tokenSymbol,
    required this.tokenDisplayName,
    required this.tokenDecimals,
    required this.tokenContractAddress,
    required this.spenderAddress,
    required this.updatedAt,
    this.spenderLabel = '',
    this.allowanceBaseUnits = 0,
    this.lastTransactionHash,
  });

  final String id;
  final ChainKind chain;
  final ChainNetwork network;
  final String ownerAddress;
  final String assetId;
  final String tokenSymbol;
  final String tokenDisplayName;
  final int tokenDecimals;
  final String tokenContractAddress;
  final String spenderAddress;
  final String spenderLabel;
  final int allowanceBaseUnits;
  final DateTime updatedAt;
  final String? lastTransactionHash;

  String get resolvedSpenderLabel =>
      spenderLabel.trim().isEmpty ? Formatters.shortAddress(spenderAddress) : spenderLabel;

  double get allowanceAmount => allowanceBaseUnits / _pow10(tokenDecimals);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'chain': chain.name,
    'network': network.name,
    'ownerAddress': ownerAddress,
    'assetId': assetId,
    'tokenSymbol': tokenSymbol,
    'tokenDisplayName': tokenDisplayName,
    'tokenDecimals': tokenDecimals,
    'tokenContractAddress': tokenContractAddress,
    'spenderAddress': spenderAddress,
    'spenderLabel': spenderLabel,
    'allowanceBaseUnits': allowanceBaseUnits,
    'updatedAt': updatedAt.toIso8601String(),
    'lastTransactionHash': lastTransactionHash,
  };

  factory TokenAllowanceEntry.fromJson(Map<String, dynamic> json) {
    return TokenAllowanceEntry(
      id: json['id'] as String,
      chain: ChainKind.values.byName(json['chain'] as String),
      network: ChainNetwork.values.byName(json['network'] as String),
      ownerAddress: (json['ownerAddress'] as String?) ?? '',
      assetId: json['assetId'] as String,
      tokenSymbol: json['tokenSymbol'] as String,
      tokenDisplayName: json['tokenDisplayName'] as String,
      tokenDecimals: json['tokenDecimals'] as int,
      tokenContractAddress: json['tokenContractAddress'] as String,
      spenderAddress: json['spenderAddress'] as String,
      spenderLabel: (json['spenderLabel'] as String?) ?? '',
      allowanceBaseUnits: _parseFlexibleInt(json['allowanceBaseUnits']),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastTransactionHash: json['lastTransactionHash'] as String?,
    );
  }

  TokenAllowanceEntry copyWith({
    String? spenderLabel,
    int? allowanceBaseUnits,
    DateTime? updatedAt,
    String? lastTransactionHash,
  }) {
    return TokenAllowanceEntry(
      id: id,
      chain: chain,
      network: network,
      ownerAddress: ownerAddress,
      assetId: assetId,
      tokenSymbol: tokenSymbol,
      tokenDisplayName: tokenDisplayName,
      tokenDecimals: tokenDecimals,
      tokenContractAddress: tokenContractAddress,
      spenderAddress: spenderAddress,
      spenderLabel: spenderLabel ?? this.spenderLabel,
      allowanceBaseUnits: allowanceBaseUnits ?? this.allowanceBaseUnits,
      updatedAt: updatedAt ?? this.updatedAt,
      lastTransactionHash: lastTransactionHash ?? this.lastTransactionHash,
    );
  }
}

class TokenAllowanceQuote {
  const TokenAllowanceQuote({
    required this.currentAllowanceBaseUnits,
    required this.proposedAllowanceBaseUnits,
    required this.networkFeeBaseUnits,
    this.isEstimate = false,
  });

  final int currentAllowanceBaseUnits;
  final int proposedAllowanceBaseUnits;
  final int networkFeeBaseUnits;
  final bool isEstimate;
}

class SwapFeeAmount {
  const SwapFeeAmount({
    required this.amountBaseUnits,
    required this.tokenAddress,
    required this.type,
  });

  final int amountBaseUnits;
  final String tokenAddress;
  final String type;
}

class SwapAllowanceIssue {
  const SwapAllowanceIssue({
    required this.actualBaseUnits,
    required this.spenderAddress,
  });

  final int actualBaseUnits;
  final String spenderAddress;
}

class SwapBalanceIssue {
  const SwapBalanceIssue({
    required this.tokenAddress,
    required this.actualBaseUnits,
    required this.expectedBaseUnits,
  });

  final String tokenAddress;
  final int actualBaseUnits;
  final int expectedBaseUnits;
}

class SwapRouteFill {
  const SwapRouteFill({
    required this.fromTokenAddress,
    required this.toTokenAddress,
    required this.source,
    required this.proportionBps,
  });

  final String fromTokenAddress;
  final String toTokenAddress;
  final String source;
  final int proportionBps;
}

class SwapTransactionRequest {
  const SwapTransactionRequest({
    required this.toAddress,
    required this.dataHex,
    required this.gasLimit,
    required this.gasPriceWei,
    required this.valueBaseUnits,
  });

  final String toAddress;
  final String dataHex;
  final int gasLimit;
  final int gasPriceWei;
  final int valueBaseUnits;
}

class SwapQuote {
  const SwapQuote({
    required this.sellTokenAddress,
    required this.buyTokenAddress,
    required this.sellAmountBaseUnits,
    required this.buyAmountBaseUnits,
    required this.minBuyAmountBaseUnits,
    required this.liquidityAvailable,
    required this.routeFills,
    required this.isFirmQuote,
    this.totalNetworkFeeBaseUnits,
    this.zeroExFee,
    this.gasFee,
    this.allowanceIssue,
    this.balanceIssue,
    this.transaction,
    this.zid,
  });

  final String sellTokenAddress;
  final String buyTokenAddress;
  final int sellAmountBaseUnits;
  final int buyAmountBaseUnits;
  final int minBuyAmountBaseUnits;
  final bool liquidityAvailable;
  final List<SwapRouteFill> routeFills;
  final bool isFirmQuote;
  final int? totalNetworkFeeBaseUnits;
  final SwapFeeAmount? zeroExFee;
  final SwapFeeAmount? gasFee;
  final SwapAllowanceIssue? allowanceIssue;
  final SwapBalanceIssue? balanceIssue;
  final SwapTransactionRequest? transaction;
  final String? zid;

  bool get requiresAllowance => allowanceIssue != null;
  bool get hasBalanceIssue => balanceIssue != null;
}

class NftHolding {
  const NftHolding({
    required this.chain,
    required this.network,
    required this.contractAddress,
    required this.tokenId,
    required this.ownerAddress,
    required this.updatedAt,
    this.collectionName = '',
    this.symbol = '',
    this.tokenUri,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final String contractAddress;
  final String tokenId;
  final String ownerAddress;
  final DateTime updatedAt;
  final String collectionName;
  final String symbol;
  final String? tokenUri;

  String get id =>
      '${chain.name}:${network.name}:${contractAddress.toLowerCase()}:$tokenId';

  String get resolvedCollectionName =>
      collectionName.trim().isEmpty ? 'NFT Collection' : collectionName;

  String get resolvedSymbol => symbol.trim().isEmpty ? 'NFT' : symbol;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'chain': chain.name,
    'network': network.name,
    'contractAddress': contractAddress,
    'tokenId': tokenId,
    'ownerAddress': ownerAddress,
    'updatedAt': updatedAt.toIso8601String(),
    'collectionName': collectionName,
    'symbol': symbol,
    'tokenUri': tokenUri,
  };

  factory NftHolding.fromJson(Map<String, dynamic> json) {
    return NftHolding(
      chain: ChainKind.values.byName(json['chain'] as String),
      network: ChainNetwork.values.byName(json['network'] as String),
      contractAddress: json['contractAddress'] as String,
      tokenId: json['tokenId'] as String,
      ownerAddress: json['ownerAddress'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      collectionName: (json['collectionName'] as String?) ?? '',
      symbol: (json['symbol'] as String?) ?? '',
      tokenUri: json['tokenUri'] as String?,
    );
  }
}

enum DappRequestMethod { personalSign, ethSign, sendTransaction }

extension DappRequestMethodX on DappRequestMethod {
  String get label => switch (this) {
    DappRequestMethod.personalSign => 'Sign message',
    DappRequestMethod.ethSign => 'Sign payload',
    DappRequestMethod.sendTransaction => 'Send transaction',
  };
}

class DappSignRequest {
  const DappSignRequest({
    required this.method,
    required this.chain,
    required this.network,
    required this.rawJson,
    this.origin,
    this.message,
    this.payloadHex,
    this.toAddress,
    this.valueBaseUnits = 0,
    this.dataHex = '0x',
  });

  final DappRequestMethod method;
  final ChainKind chain;
  final ChainNetwork network;
  final String rawJson;
  final String? origin;
  final String? message;
  final String? payloadHex;
  final String? toAddress;
  final int valueBaseUnits;
  final String dataHex;

  bool get isMessageRequest =>
      method == DappRequestMethod.personalSign ||
      method == DappRequestMethod.ethSign;

  String get title => method.label;

  String get summary {
    return switch (method) {
      DappRequestMethod.personalSign => message?.trim().isNotEmpty == true
          ? message!.trim()
          : (payloadHex ?? 'Message payload'),
      DappRequestMethod.ethSign =>
        payloadHex?.trim().isNotEmpty == true ? payloadHex!.trim() : 'Raw payload',
      DappRequestMethod.sendTransaction => toAddress == null
          ? 'Transaction request'
          : 'Send to ${Formatters.shortAddress(toAddress!)}',
    };
  }

  factory DappSignRequest.fromJsonString(
    String raw, {
    required ChainKind preferredChain,
    required ChainNetwork preferredNetwork,
  }) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Paste a dapp request first.');
    }
    if (trimmed.toLowerCase().startsWith('walletconnect:')) {
      throw const FormatException(
        'WalletConnect URI detected, but this build only supports pasted or scanned sign requests and transaction requests.',
      );
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
        'Paste a JSON dapp request, such as personal_sign or eth_sendTransaction.',
      );
    }
    final String methodName = (json['method'] as String? ?? '').trim();
    final List<dynamic> params =
        (json['params'] as List<dynamic>?) ?? const <dynamic>[];
    final Object? rawChainId = json['chainId'];
    final int? chainId = rawChainId == null
        ? null
        : rawChainId is int
        ? rawChainId
        : _parseFlexibleHexInt('$rawChainId');
    final (ChainKind, ChainNetwork) scope =
        _scopeFromDappChainId(chainId) ?? (preferredChain, preferredNetwork);
    final String? origin = (json['origin'] as String?)?.trim();

    switch (methodName) {
      case 'personal_sign':
        if (params.length < 2) {
          throw const FormatException('personal_sign request is missing params.');
        }
        final String payload = '${params.first}'.trim();
        return DappSignRequest(
          method: DappRequestMethod.personalSign,
          chain: scope.$1,
          network: scope.$2,
          rawJson: trimmed,
          origin: origin,
          message: _decodeDappMessage(payload),
          payloadHex: _looksLikeHexPayload(payload) ? payload : null,
        );
      case 'eth_sign':
        if (params.length < 2) {
          throw const FormatException('eth_sign request is missing params.');
        }
        final String payload = '${params[1]}'.trim();
        return DappSignRequest(
          method: DappRequestMethod.ethSign,
          chain: scope.$1,
          network: scope.$2,
          rawJson: trimmed,
          origin: origin,
          message: _decodeDappMessage(payload),
          payloadHex: payload,
        );
      case 'eth_sendTransaction':
        if (params.isEmpty || params.first is! Map) {
          throw const FormatException(
            'eth_sendTransaction request is missing transaction params.',
          );
        }
        final Map<String, dynamic> tx = Map<String, dynamic>.from(
          params.first as Map,
        );
        final String toAddress = (tx['to'] as String? ?? '').trim();
        if (!_isValidEvmAddress(toAddress)) {
          throw const FormatException(
            'eth_sendTransaction request is missing a valid recipient.',
          );
        }
        final String dataHex = (tx['data'] as String? ?? '0x').trim();
        final String valueText = (tx['value'] as String? ?? '0x0').trim();
        return DappSignRequest(
          method: DappRequestMethod.sendTransaction,
          chain: scope.$1,
          network: scope.$2,
          rawJson: trimmed,
          origin: origin,
          toAddress: EthereumAddress.fromHex(toAddress).hexEip55,
          valueBaseUnits: _parseFlexibleHexInt(valueText),
          dataHex: dataHex.isEmpty ? '0x' : dataHex,
        );
      default:
        throw FormatException('$methodName is not supported yet.');
    }
  }
}

class DappSignResult {
  const DappSignResult({
    required this.request,
    required this.result,
    required this.completedAt,
    this.isTransaction = false,
  });

  final DappSignRequest request;
  final String result;
  final DateTime completedAt;
  final bool isTransaction;
}

class CachedBlockhash {
  const CachedBlockhash({
    required this.blockhash,
    required this.lastValidBlockHeight,
    required this.fetchedAt,
  });

  final String blockhash;
  final int lastValidBlockHeight;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'blockhash': blockhash,
    'lastValidBlockHeight': lastValidBlockHeight,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory CachedBlockhash.fromJson(Map<String, dynamic> json) =>
      CachedBlockhash(
        blockhash: json['blockhash'] as String,
        lastValidBlockHeight: json['lastValidBlockHeight'] as int,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
}

class SendDraft {
  const SendDraft({
    this.chain = ChainKind.ethereum,
    this.network = ChainNetwork.testnet,
    this.walletEngine = WalletEngine.local,
    this.transport = TransportKind.hotspot,
    this.assetId = '',
    this.gasSpeed = GasSpeed.market,
    this.receiverAddress = '',
    this.receiverLabel = '',
    this.receiverEndpoint = '',
    this.receiverPeripheralId = '',
    this.receiverPeripheralName = '',
    this.receiverSessionToken = '',
    this.receiverRelayId = '',
    this.receiverPreferredChain = '',
    this.receiverPreferredToken = '',
    this.amountSol = 0,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final WalletEngine walletEngine;
  final TransportKind transport;
  final String assetId;
  final GasSpeed gasSpeed;
  final String receiverAddress;
  final String receiverLabel;
  final String receiverEndpoint;
  final String receiverPeripheralId;
  final String receiverPeripheralName;
  final String receiverSessionToken;
  final String receiverRelayId;
  final String receiverPreferredChain;
  final String receiverPreferredToken;
  final double amountSol;

  bool get hasReceiver =>
      receiverAddress.isNotEmpty &&
      switch (walletEngine) {
        WalletEngine.local => switch (transport) {
          TransportKind.online => true,
          TransportKind.hotspot => receiverEndpoint.isNotEmpty,
          TransportKind.ble => receiverPeripheralId.isNotEmpty,
          TransportKind.ultrasonic => receiverSessionToken.isNotEmpty,
        },
        WalletEngine.bitgo => true,
      };
  bool get hasAmount => amountSol > 0;

  SendDraft copyWith({
    ChainKind? chain,
    ChainNetwork? network,
    WalletEngine? walletEngine,
    TransportKind? transport,
    String? assetId,
    GasSpeed? gasSpeed,
    String? receiverAddress,
    String? receiverLabel,
    String? receiverEndpoint,
    String? receiverPeripheralId,
    String? receiverPeripheralName,
    String? receiverSessionToken,
    String? receiverRelayId,
    String? receiverPreferredChain,
    String? receiverPreferredToken,
    double? amountSol,
    bool clearReceiver = false,
  }) {
    return SendDraft(
      chain: chain ?? this.chain,
      network: network ?? this.network,
      walletEngine: walletEngine ?? this.walletEngine,
      transport: transport ?? this.transport,
      assetId: assetId ?? this.assetId,
      gasSpeed: gasSpeed ?? this.gasSpeed,
      receiverAddress: clearReceiver
          ? ''
          : receiverAddress ?? this.receiverAddress,
      receiverLabel: clearReceiver ? '' : receiverLabel ?? this.receiverLabel,
      receiverEndpoint: clearReceiver
          ? ''
          : receiverEndpoint ?? this.receiverEndpoint,
      receiverPeripheralId: clearReceiver
          ? ''
          : receiverPeripheralId ?? this.receiverPeripheralId,
      receiverPeripheralName: clearReceiver
          ? ''
          : receiverPeripheralName ?? this.receiverPeripheralName,
      receiverSessionToken: clearReceiver
          ? ''
          : receiverSessionToken ?? this.receiverSessionToken,
      receiverRelayId: clearReceiver
          ? ''
          : receiverRelayId ?? this.receiverRelayId,
      receiverPreferredChain: clearReceiver
          ? ''
          : receiverPreferredChain ?? this.receiverPreferredChain,
      receiverPreferredToken: clearReceiver
          ? ''
          : receiverPreferredToken ?? this.receiverPreferredToken,
      amountSol: amountSol ?? this.amountSol,
    );
  }
}

class ReceiverDiscoveryItem {
  const ReceiverDiscoveryItem({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.transport,
    this.address = '',
    this.rssi,
    this.lastSeenAt,
    this.metadataVerified = false,
  });

  final String id;
  final String label;
  final String subtitle;
  final TransportKind transport;
  final String address;
  final int? rssi;
  final DateTime? lastSeenAt;
  final bool metadataVerified;

  bool get hasVerifiedAddress => metadataVerified && address.isNotEmpty;

  String get resolvedAddress => hasVerifiedAddress ? address : subtitle;

  String get signalLabel {
    final int? strength = rssi;
    if (strength == null) {
      return 'Signal unknown';
    }
    if (strength >= -60) {
      return 'Strong signal';
    }
    if (strength >= -75) {
      return 'Medium signal';
    }
    return 'Weak signal';
  }
}

class HomeStatus {
  const HomeStatus({
    required this.hasInternet,
    required this.hasLocalLink,
    required this.hasDevnet,
    this.walletEngine = WalletEngine.local,
  });

  final bool hasInternet;
  final bool hasLocalLink;
  final bool hasDevnet;
  final WalletEngine walletEngine;
}

class WalletSummary {
  const WalletSummary({
    required this.chain,
    required this.network,
    required this.balanceSol,
    required this.offlineBalanceSol,
    required this.offlineAvailableSol,
    required this.offlineWalletAddress,
    required this.readyForOffline,
    required this.blockhashAge,
    required this.localEndpoint,
    this.walletEngine = WalletEngine.local,
    this.primaryAddress,
    this.primaryDisplayLabel,
    this.bitgoWallet,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final double balanceSol;
  final double offlineBalanceSol;
  final double offlineAvailableSol;
  final String? offlineWalletAddress;
  final bool readyForOffline;
  final Duration? blockhashAge;
  final String? localEndpoint;
  final WalletEngine walletEngine;
  final String? primaryAddress;
  final String? primaryDisplayLabel;
  final BitGoWalletSummary? bitgoWallet;
}

class TrackedAssetDefinition {
  const TrackedAssetDefinition({
    required this.id,
    required this.chain,
    required this.network,
    required this.symbol,
    required this.displayName,
    required this.decimals,
    this.contractAddress,
  });

  final String id;
  final ChainKind chain;
  final ChainNetwork network;
  final String symbol;
  final String displayName;
  final int decimals;
  final String? contractAddress;

  bool get isNative => contractAddress == null || contractAddress!.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'chain': chain.name,
    'network': network.name,
    'symbol': symbol,
    'displayName': displayName,
    'decimals': decimals,
    'contractAddress': contractAddress,
  };

  factory TrackedAssetDefinition.fromJson(Map<String, dynamic> json) {
    return TrackedAssetDefinition(
      id: json['id'] as String,
      chain: ChainKind.values.byName(json['chain'] as String),
      network: ChainNetwork.values.byName(json['network'] as String),
      symbol: json['symbol'] as String,
      displayName: json['displayName'] as String,
      decimals: json['decimals'] as int,
      contractAddress: json['contractAddress'] as String?,
    );
  }

  double amountFromBaseUnits(int value) {
    return value / _pow10(decimals);
  }

  int amountToBaseUnits(double value) {
    return (value * _pow10(decimals)).round();
  }
}

const List<TrackedAssetDefinition> trackedAssetDefinitions =
    <TrackedAssetDefinition>[
      TrackedAssetDefinition(
        id: 'solana:testnet:native',
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        symbol: 'SOL',
        displayName: 'Solana',
        decimals: 9,
      ),
      TrackedAssetDefinition(
        id: 'solana:mainnet:native',
        chain: ChainKind.solana,
        network: ChainNetwork.mainnet,
        symbol: 'SOL',
        displayName: 'Solana',
        decimals: 9,
      ),
      TrackedAssetDefinition(
        id: 'ethereum:testnet:native',
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        symbol: 'ETH',
        displayName: 'Ethereum',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'ethereum:mainnet:native',
        chain: ChainKind.ethereum,
        network: ChainNetwork.mainnet,
        symbol: 'ETH',
        displayName: 'Ethereum',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'base:testnet:native',
        chain: ChainKind.base,
        network: ChainNetwork.testnet,
        symbol: 'ETH',
        displayName: 'Base',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'base:mainnet:native',
        chain: ChainKind.base,
        network: ChainNetwork.mainnet,
        symbol: 'ETH',
        displayName: 'Base',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'bnb:testnet:native',
        chain: ChainKind.bnb,
        network: ChainNetwork.testnet,
        symbol: 'BNB',
        displayName: 'BNB Chain',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'bnb:mainnet:native',
        chain: ChainKind.bnb,
        network: ChainNetwork.mainnet,
        symbol: 'BNB',
        displayName: 'BNB Chain',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'bnb:mainnet:usdt',
        chain: ChainKind.bnb,
        network: ChainNetwork.mainnet,
        symbol: 'USDT',
        displayName: 'Tether USD',
        decimals: 18,
        contractAddress: '0x55d398326f99059fF775485246999027B3197955',
      ),
      TrackedAssetDefinition(
        id: 'polygon:testnet:native',
        chain: ChainKind.polygon,
        network: ChainNetwork.testnet,
        symbol: 'POL',
        displayName: 'Polygon',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'polygon:mainnet:native',
        chain: ChainKind.polygon,
        network: ChainNetwork.mainnet,
        symbol: 'POL',
        displayName: 'Polygon',
        decimals: 18,
      ),
      TrackedAssetDefinition(
        id: 'ethereum:testnet:usdc',
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        symbol: 'USDC',
        displayName: 'USD Coin',
        decimals: 6,
        contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
      ),
      TrackedAssetDefinition(
        id: 'ethereum:testnet:eurc',
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        symbol: 'EURC',
        displayName: 'Euro Coin',
        decimals: 6,
        contractAddress: '0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4',
      ),
      TrackedAssetDefinition(
        id: 'ethereum:mainnet:usdc',
        chain: ChainKind.ethereum,
        network: ChainNetwork.mainnet,
        symbol: 'USDC',
        displayName: 'USD Coin',
        decimals: 6,
        contractAddress: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      ),
      TrackedAssetDefinition(
        id: 'ethereum:mainnet:eurc',
        chain: ChainKind.ethereum,
        network: ChainNetwork.mainnet,
        symbol: 'EURC',
        displayName: 'Euro Coin',
        decimals: 6,
        contractAddress: '0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c',
      ),
      TrackedAssetDefinition(
        id: 'base:testnet:usdc',
        chain: ChainKind.base,
        network: ChainNetwork.testnet,
        symbol: 'USDC',
        displayName: 'USD Coin',
        decimals: 6,
        contractAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      ),
      TrackedAssetDefinition(
        id: 'base:testnet:eurc',
        chain: ChainKind.base,
        network: ChainNetwork.testnet,
        symbol: 'EURC',
        displayName: 'Euro Coin',
        decimals: 6,
        contractAddress: '0x808456652fdb597867f38412077A9182bf77359F',
      ),
      TrackedAssetDefinition(
        id: 'base:mainnet:usdc',
        chain: ChainKind.base,
        network: ChainNetwork.mainnet,
        symbol: 'USDC',
        displayName: 'USD Coin',
        decimals: 6,
        contractAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      ),
      TrackedAssetDefinition(
        id: 'base:mainnet:eurc',
        chain: ChainKind.base,
        network: ChainNetwork.mainnet,
        symbol: 'EURC',
        displayName: 'Euro Coin',
        decimals: 6,
        contractAddress: '0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42',
      ),
    ];

List<TrackedAssetDefinition> trackedAssetsForScope(
  ChainKind chain,
  ChainNetwork network,
) {
  return trackedAssetDefinitions
      .where(
        (TrackedAssetDefinition asset) =>
            asset.chain == chain && asset.network == network,
      )
      .toList(growable: false);
}

String trackedAssetLookupKey(TrackedAssetDefinition asset) {
  final String contract = (asset.contractAddress ?? '').trim().toLowerCase();
  return contract.isNotEmpty
      ? '${asset.chain.name}:${asset.network.name}:$contract'
      : asset.id;
}

class AssetPortfolioHolding {
  const AssetPortfolioHolding({
    required this.chain,
    required this.network,
    required this.totalBalance,
    required this.mainBalance,
    required this.protectedBalance,
    required this.spendableBalance,
    required this.reservedBalance,
    this.assetId = '',
    this.symbol = '',
    this.displayName = '',
    this.assetDecimals,
    this.contractAddress,
    this.isNative = true,
    this.mainAddress,
    this.protectedAddress,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final double totalBalance;
  final double mainBalance;
  final double protectedBalance;
  final double spendableBalance;
  final double reservedBalance;
  final String assetId;
  final String symbol;
  final String displayName;
  final int? assetDecimals;
  final String? contractAddress;
  final bool isNative;
  final String? mainAddress;
  final String? protectedAddress;

  String get resolvedSymbol =>
      symbol.isEmpty ? chain.assetDisplayLabel : symbol;

  String get resolvedDisplayName =>
      displayName.isEmpty ? chain.label : displayName;

  int get resolvedDecimals => assetDecimals ?? chain.decimals;

  String get resolvedAssetId => assetId.isEmpty
      ? '${chain.name}:${network.name}:${resolvedSymbol.toLowerCase()}'
      : assetId;

  double amountFromBaseUnits(int value) {
    return value / _pow10(resolvedDecimals);
  }

  int amountToBaseUnits(double value) {
    return (value * _pow10(resolvedDecimals)).round();
  }
}

enum BitGoBackendMode { unknown, mock, live }

extension BitGoBackendModeX on BitGoBackendMode {
  String get label => switch (this) {
    BitGoBackendMode.unknown => 'Unknown',
    BitGoBackendMode.mock => 'Mock',
    BitGoBackendMode.live => 'Live',
  };

  bool get isLive => this == BitGoBackendMode.live;
}

class BitGoBackendHealth {
  const BitGoBackendHealth({
    required this.ok,
    required this.mode,
    this.version = '',
  });

  final bool ok;
  final BitGoBackendMode mode;
  final String version;

  factory BitGoBackendHealth.fromJson(Map<String, dynamic> json) {
    final String rawMode =
        (json['mode'] as String?)?.trim().toLowerCase() ?? '';
    return BitGoBackendHealth(
      ok: (json['ok'] as bool?) ?? false,
      mode: switch (rawMode) {
        'live' => BitGoBackendMode.live,
        'mock' => BitGoBackendMode.mock,
        _ => BitGoBackendMode.unknown,
      },
      version: (json['version'] as String?)?.trim() ?? '',
    );
  }
}

class SendQuote {
  const SendQuote({
    required this.amountBaseUnits,
    required this.networkFeeBaseUnits,
    required this.totalDebitBaseUnits,
    this.isEstimate = false,
    this.slippageBps = 0,
    this.note,
  });

  final int amountBaseUnits;
  final int networkFeeBaseUnits;
  final int totalDebitBaseUnits;
  final bool isEstimate;
  final int slippageBps;
  final String? note;
}

class BitGoWalletSummary {
  const BitGoWalletSummary({
    required this.chain,
    required this.network,
    required this.walletId,
    required this.address,
    required this.displayLabel,
    required this.balanceBaseUnits,
    required this.connectivityStatus,
    this.coin,
    this.lastSyncedAt,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final String walletId;
  final String address;
  final String displayLabel;
  final int balanceBaseUnits;
  final String connectivityStatus;
  final String? coin;
  final DateTime? lastSyncedAt;

  double amountForChain() => chain.amountFromBaseUnits(balanceBaseUnits);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'chain': chain.name,
    'network': network.name,
    'walletId': walletId,
    'address': address,
    'displayLabel': displayLabel,
    'balanceBaseUnits': balanceBaseUnits,
    'connectivityStatus': connectivityStatus,
    'coin': coin,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory BitGoWalletSummary.fromJson(Map<String, dynamic> json) =>
      BitGoWalletSummary(
        chain: ChainKind.values.byName(json['chain'] as String),
        network: ChainNetwork.values.byName(
          (json['network'] as String?) ?? ChainNetwork.testnet.name,
        ),
        walletId: json['walletId'] as String,
        address: json['address'] as String,
        displayLabel:
            (json['displayLabel'] as String?) ??
            (json['label'] as String?) ??
            'BitGo wallet',
        balanceBaseUnits: _parseFlexibleInt(
          json['balanceBaseUnits'] ?? json['balance'],
        ),
        connectivityStatus:
            (json['connectivityStatus'] as String?) ??
            (json['status'] as String?) ??
            'connected',
        coin: json['coin'] as String?,
        lastSyncedAt: (json['lastSyncedAt'] as String?) == null
            ? null
            : DateTime.parse(json['lastSyncedAt'] as String),
      );
}

int _parseFlexibleInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

class BitGoDemoSession {
  const BitGoDemoSession({required this.sessionToken, required this.wallets});

  final String sessionToken;
  final List<BitGoWalletSummary> wallets;

  factory BitGoDemoSession.fromJson(Map<String, dynamic> json) =>
      BitGoDemoSession(
        sessionToken: json['sessionToken'] as String,
        wallets: ((json['wallets'] as List<dynamic>?) ?? const <dynamic>[])
            .map(
              (dynamic item) =>
                  BitGoWalletSummary.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
}

class BitGoTransferSnapshot {
  const BitGoTransferSnapshot({
    required this.clientTransferId,
    required this.bitgoTransferId,
    required this.bitgoWalletId,
    required this.status,
    this.transactionSignature,
    this.explorerUrl,
    this.message,
    this.updatedAt,
  });

  final String clientTransferId;
  final String bitgoTransferId;
  final String bitgoWalletId;
  final String status;
  final String? transactionSignature;
  final String? explorerUrl;
  final String? message;
  final DateTime? updatedAt;

  factory BitGoTransferSnapshot.fromJson(Map<String, dynamic> json) {
    return BitGoTransferSnapshot(
      clientTransferId:
          (json['clientTransferId'] as String?) ??
          (json['transferId'] as String?) ??
          '',
      bitgoTransferId:
          (json['bitgoTransferId'] as String?) ?? (json['id'] as String?) ?? '',
      bitgoWalletId:
          (json['bitgoWalletId'] as String?) ??
          (json['walletId'] as String?) ??
          '',
      status:
          (json['status'] as String?) ??
          (json['backendStatus'] as String?) ??
          'pending',
      transactionSignature:
          (json['transactionSignature'] as String?) ??
          (json['transactionHash'] as String?) ??
          (json['signature'] as String?),
      explorerUrl: json['explorerUrl'] as String?,
      message: (json['message'] as String?) ?? (json['reason'] as String?),
      updatedAt: (json['updatedAt'] as String?) == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class FileverseDemoSession {
  const FileverseDemoSession({required this.sessionToken});

  final String sessionToken;

  factory FileverseDemoSession.fromJson(Map<String, dynamic> json) =>
      FileverseDemoSession(sessionToken: json['sessionToken'] as String);
}

class FileverseReceiptSnapshot {
  const FileverseReceiptSnapshot({
    required this.receiptId,
    required this.receiptUrl,
    required this.savedAt,
    this.storageMode,
    this.message,
  });

  final String receiptId;
  final String receiptUrl;
  final DateTime savedAt;
  final String? storageMode;
  final String? message;

  factory FileverseReceiptSnapshot.fromJson(Map<String, dynamic> json) =>
      FileverseReceiptSnapshot(
        receiptId:
            (json['receiptId'] as String?) ??
            (json['id'] as String?) ??
            (json['documentId'] as String?) ??
            '',
        receiptUrl:
            (json['receiptUrl'] as String?) ??
            (json['url'] as String?) ??
            (json['shareUrl'] as String?) ??
            '',
        savedAt: (json['savedAt'] as String?) == null
            ? DateTime.now()
            : DateTime.parse(json['savedAt'] as String),
        storageMode:
            (json['storageMode'] as String?) ?? (json['provider'] as String?),
        message: json['message'] as String?,
      );
}

class EnsPaymentPreference {
  const EnsPaymentPreference({
    required this.ensName,
    this.preferredChain = '',
    this.preferredToken = '',
  });

  static const String chainRecordKey = 'com.bitsend.payment.chain';
  static const String tokenRecordKey = 'com.bitsend.payment.token';

  final String ensName;
  final String preferredChain;
  final String preferredToken;

  bool get hasPreference =>
      preferredChain.trim().isNotEmpty || preferredToken.trim().isNotEmpty;

  String get summary {
    final String chain = preferredChain.trim();
    final String token = preferredToken.trim();
    if (chain.isNotEmpty && token.isNotEmpty) {
      return '$chain / $token';
    }
    return chain.isNotEmpty ? chain : token;
  }
}

class ReceiverInvitePayload {
  const ReceiverInvitePayload({
    required this.chain,
    required this.network,
    required this.transport,
    required this.address,
    required this.displayAddress,
    this.endpoint,
    this.sessionToken,
    this.relayId,
  });

  static const String type = 'bitsend.pairing';
  static const String legacyType = 'bitsend.receiver';
  static const int currentVersion = 2;

  final ChainKind chain;
  final ChainNetwork network;
  final TransportKind transport;
  final String address;
  final String displayAddress;
  final String? endpoint;
  final String? sessionToken;
  final String? relayId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'version': currentVersion,
    'network': network.keyFor(chain),
    'networkMode': network.name,
    'chain': chain.name,
    'transport': transport.name,
    'address': address,
    'displayAddress': displayAddress,
    'endpoint': endpoint,
    if (sessionToken != null && sessionToken!.isNotEmpty)
      'sessionToken': sessionToken,
    if (relayId != null && relayId!.isNotEmpty) 'relayId': relayId,
  };

  String toPairCodeData() => jsonEncode(toJson());

  String toQrData() => toPairCodeData();

  factory ReceiverInvitePayload.fromPairCodeData(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('QR code is empty.');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
        'This QR code is not a Bitsend receiver invite.',
      );
    }

    final String? payloadType = json['type'] as String?;
    if (payloadType != type && payloadType != legacyType) {
      throw const FormatException(
        'This QR code is not a Bitsend receiver invite.',
      );
    }
    final String? chainName = json['chain'] as String?;
    final String? networkKey = json['network'] as String?;
    final (ChainKind, ChainNetwork) scope = switch ((chainName, networkKey)) {
      ('solana', 'solana-devnet') => (ChainKind.solana, ChainNetwork.testnet),
      ('solana', 'solana-mainnet') => (ChainKind.solana, ChainNetwork.mainnet),
      ('ethereum', 'ethereum-sepolia') => (
        ChainKind.ethereum,
        ChainNetwork.testnet,
      ),
      ('ethereum', 'ethereum-mainnet') => (
        ChainKind.ethereum,
        ChainNetwork.mainnet,
      ),
      ('base', 'base-sepolia') => (ChainKind.base, ChainNetwork.testnet),
      ('base', 'base-mainnet') => (ChainKind.base, ChainNetwork.mainnet),
      ('bnb', 'bnb-testnet') => (ChainKind.bnb, ChainNetwork.testnet),
      ('bnb', 'bnb-mainnet') => (ChainKind.bnb, ChainNetwork.mainnet),
      ('polygon', 'polygon-amoy') => (ChainKind.polygon, ChainNetwork.testnet),
      ('polygon', 'polygon-mainnet') =>
        (ChainKind.polygon, ChainNetwork.mainnet),
      ('solana', _) => (ChainKind.solana, ChainNetwork.testnet),
      ('ethereum', _) => (ChainKind.ethereum, ChainNetwork.testnet),
      ('base', _) => (ChainKind.base, ChainNetwork.testnet),
      ('bnb', _) => (ChainKind.bnb, ChainNetwork.testnet),
      ('polygon', _) => (ChainKind.polygon, ChainNetwork.testnet),
      (_, 'solana-devnet') => (ChainKind.solana, ChainNetwork.testnet),
      (_, 'solana-mainnet') => (ChainKind.solana, ChainNetwork.mainnet),
      (_, 'ethereum-sepolia') => (ChainKind.ethereum, ChainNetwork.testnet),
      (_, 'ethereum-mainnet') => (ChainKind.ethereum, ChainNetwork.mainnet),
      (_, 'base-sepolia') => (ChainKind.base, ChainNetwork.testnet),
      (_, 'base-mainnet') => (ChainKind.base, ChainNetwork.mainnet),
      (_, 'bnb-testnet') => (ChainKind.bnb, ChainNetwork.testnet),
      (_, 'bnb-mainnet') => (ChainKind.bnb, ChainNetwork.mainnet),
      (_, 'polygon-amoy') => (ChainKind.polygon, ChainNetwork.testnet),
      (_, 'polygon-mainnet') => (ChainKind.polygon, ChainNetwork.mainnet),
      _ => throw const FormatException(
        'This QR code is for a different network.',
      ),
    };
    final int version = (json['version'] as int?) ?? 1;
    if (version != 1 && version != currentVersion) {
      throw const FormatException('This QR code version is not supported.');
    }

    final TransportKind transport = TransportKind.values.byName(
      json['transport'] as String,
    );
    final String address = (json['address'] as String? ?? '').trim();
    final String displayAddress = (json['displayAddress'] as String? ?? '')
        .trim();
    final String? endpoint = (json['endpoint'] as String?)?.trim();
    if (address.isEmpty) {
      throw const FormatException(
        'Receiver address is missing from the QR code.',
      );
    }
    if (transport == TransportKind.hotspot &&
        (endpoint == null || endpoint.isEmpty)) {
      throw const FormatException(
        'Receiver hotspot endpoint is missing from the QR code.',
      );
    }
    final String? sessionToken = (json['sessionToken'] as String?)?.trim();
    final String? relayId = (json['relayId'] as String?)?.trim();
    if (transport == TransportKind.ultrasonic &&
        (sessionToken == null || sessionToken.isEmpty)) {
      throw const FormatException(
        'Receiver ultrasonic session token is missing from the QR code.',
      );
    }
    if (transport == TransportKind.ultrasonic &&
        (relayId == null || relayId.isEmpty)) {
      throw const FormatException(
        'Receiver relay id is missing from the QR code.',
      );
    }

    return ReceiverInvitePayload(
      chain: scope.$1,
      network: scope.$2,
      transport: transport,
      address: address,
      displayAddress: displayAddress.isEmpty ? address : displayAddress,
      endpoint: endpoint == null || endpoint.isEmpty ? null : endpoint,
      sessionToken: sessionToken == null || sessionToken.isEmpty
          ? null
          : sessionToken,
      relayId: relayId == null || relayId.isEmpty ? null : relayId,
    );
  }

  factory ReceiverInvitePayload.fromQrData(String raw) {
    return ReceiverInvitePayload.fromPairCodeData(raw);
  }
}

class DirectTransferQrPayload {
  const DirectTransferQrPayload({
    required this.chain,
    required this.network,
    required this.address,
    required this.displayAddress,
    this.amount,
    this.label,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final String address;
  final String displayAddress;
  final double? amount;
  final String? label;

  static DirectTransferQrPayload? tryParse(
    String raw, {
    required ChainKind preferredChain,
    required ChainNetwork preferredNetwork,
  }) {
    try {
      return DirectTransferQrPayload.fromQrData(
        raw,
        preferredChain: preferredChain,
        preferredNetwork: preferredNetwork,
      );
    } catch (_) {
      return null;
    }
  }

  factory DirectTransferQrPayload.fromQrData(
    String raw, {
    required ChainKind preferredChain,
    required ChainNetwork preferredNetwork,
  }) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('QR code is empty.');
    }

    final DirectTransferQrPayload? plain = _tryParsePlainDirectTransferQr(
      trimmed,
      preferredChain: preferredChain,
      preferredNetwork: preferredNetwork,
    );
    if (plain != null) {
      return plain;
    }

    final int separator = trimmed.indexOf(':');
    if (separator <= 0) {
      throw const FormatException(
        'This QR code does not contain a supported wallet address.',
      );
    }
    final String scheme = trimmed.substring(0, separator).toLowerCase();
    return switch (scheme) {
      'solana' => _parseSolanaDirectTransferQr(
        trimmed,
        preferredNetwork: preferredNetwork,
      ),
      'ethereum' || 'base' || 'bnb' || 'bsc' || 'polygon' || 'matic' =>
        _parseEvmDirectTransferQr(
        trimmed,
        scheme: scheme,
        preferredChain: preferredChain,
        preferredNetwork: preferredNetwork,
      ),
      _ => throw const FormatException(
        'This QR code does not contain a supported wallet address.',
      ),
    };
  }
}

enum OfflineVoucherClaimStatus {
  accepted,
  duplicateRejected,
  expiredRejected,
  invalidRejected,
  submittedOnchain,
  confirmedOnchain,
}

enum OfflineVoucherClaimSubmissionMode { receiver, sponsor }

class OfflineVoucherEscrowCommitment {
  const OfflineVoucherEscrowCommitment({
    required this.version,
    required this.escrowId,
    required this.chain,
    required this.network,
    required this.senderAddress,
    required this.assetId,
    required this.amountBaseUnits,
    required this.collateralBaseUnits,
    required this.voucherRoot,
    required this.voucherCount,
    required this.maxVoucherAmountBaseUnits,
    required this.createdAt,
    required this.expiresAt,
    required this.stateRoot,
    this.assetContract,
    this.settlementContract,
  });

  static const int currentVersion = 1;

  final int version;
  final String escrowId;
  final ChainKind chain;
  final ChainNetwork network;
  final String senderAddress;
  final String assetId;
  final String amountBaseUnits;
  final String collateralBaseUnits;
  final String voucherRoot;
  final int voucherCount;
  final String maxVoucherAmountBaseUnits;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String stateRoot;
  final String? assetContract;
  final String? settlementContract;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'escrowId': escrowId,
    'chain': chain.name,
    'network': network.name,
    'senderAddress': senderAddress,
    'assetId': assetId,
    'assetContract': assetContract,
    'amountBaseUnits': amountBaseUnits,
    'collateralBaseUnits': collateralBaseUnits,
    'voucherRoot': voucherRoot,
    'voucherCount': voucherCount,
    'maxVoucherAmountBaseUnits': maxVoucherAmountBaseUnits,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'stateRoot': stateRoot,
    'settlementContract': settlementContract,
  };

  factory OfflineVoucherEscrowCommitment.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherEscrowCommitment(
      version: (json['version'] as int?) ?? currentVersion,
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      chain: ChainKind.values.byName(json['chain'] as String),
      network: ChainNetwork.values.byName(json['network'] as String),
      senderAddress: (json['senderAddress'] as String? ?? '').trim(),
      assetId: (json['assetId'] as String? ?? '').trim(),
      assetContract: (json['assetContract'] as String?)?.trim(),
      amountBaseUnits: (json['amountBaseUnits'] as String? ?? '').trim(),
      collateralBaseUnits:
          (json['collateralBaseUnits'] as String? ?? '').trim(),
      voucherRoot: (json['voucherRoot'] as String? ?? '').trim(),
      voucherCount: (json['voucherCount'] as int?) ?? 0,
      maxVoucherAmountBaseUnits:
          (json['maxVoucherAmountBaseUnits'] as String? ?? '').trim(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      stateRoot: (json['stateRoot'] as String? ?? '').trim(),
      settlementContract: (json['settlementContract'] as String?)?.trim(),
    );
  }
}

class OfflineVoucherLeaf {
  const OfflineVoucherLeaf({
    required this.version,
    required this.escrowId,
    required this.voucherId,
    required this.amountBaseUnits,
    required this.expiryAt,
    required this.nonce,
    this.receiverAddress,
  });

  static const int currentVersion = 1;

  final int version;
  final String escrowId;
  final String voucherId;
  final String amountBaseUnits;
  final DateTime expiryAt;
  final String nonce;
  final String? receiverAddress;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'escrowId': escrowId,
    'voucherId': voucherId,
    'amountBaseUnits': amountBaseUnits,
    'expiryAt': expiryAt.toUtc().toIso8601String(),
    'nonce': nonce,
    'receiverAddress': receiverAddress,
  };

  String computeHashHex() => _sha256HexFromObject(toJson());

  factory OfflineVoucherLeaf.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherLeaf(
      version: (json['version'] as int?) ?? currentVersion,
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      voucherId: (json['voucherId'] as String? ?? '').trim(),
      amountBaseUnits: (json['amountBaseUnits'] as String? ?? '').trim(),
      expiryAt: DateTime.parse(json['expiryAt'] as String).toUtc(),
      nonce:
          (json['nonce'] as String? ??
                  json['nonceHex'] as String? ??
                  json['nonceBase64'] as String? ??
                  '')
              .trim(),
      receiverAddress: (json['receiverAddress'] as String?)?.trim(),
    );
  }
}

class OfflineVoucherProofBundle {
  const OfflineVoucherProofBundle({
    required this.version,
    required this.escrowId,
    required this.voucherId,
    required this.voucherRoot,
    required this.voucherProof,
    required this.escrowStateRoot,
    required this.escrowProof,
    required this.finalizedAt,
    required this.proofWindowExpiresAt,
  });

  static const int currentVersion = 1;

  final int version;
  final String escrowId;
  final String voucherId;
  final String voucherRoot;
  final List<String> voucherProof;
  final String escrowStateRoot;
  final List<String> escrowProof;
  final DateTime finalizedAt;
  final DateTime proofWindowExpiresAt;

  bool get isExpired => !proofWindowExpiresAt.isAfter(DateTime.now().toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'escrowId': escrowId,
    'voucherId': voucherId,
    'voucherRoot': voucherRoot,
    'voucherProof': voucherProof,
    'escrowStateRoot': escrowStateRoot,
    'escrowProof': escrowProof,
    'finalizedAt': finalizedAt.toUtc().toIso8601String(),
    'proofWindowExpiresAt': proofWindowExpiresAt.toUtc().toIso8601String(),
  };

  factory OfflineVoucherProofBundle.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherProofBundle(
      version: (json['version'] as int?) ?? currentVersion,
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      voucherId: (json['voucherId'] as String? ?? '').trim(),
      voucherRoot: (json['voucherRoot'] as String? ?? '').trim(),
      voucherProof: _stringList(json['voucherProof']),
      escrowStateRoot: (json['escrowStateRoot'] as String? ?? '').trim(),
      escrowProof: _stringList(json['escrowProof']),
      finalizedAt: DateTime.parse(json['finalizedAt'] as String).toUtc(),
      proofWindowExpiresAt: DateTime.parse(
        json['proofWindowExpiresAt'] as String,
      ).toUtc(),
    );
  }
}

class OfflineVoucherPayment {
  const OfflineVoucherPayment({
    required this.version,
    required this.txId,
    required this.voucher,
    required this.proofBundle,
    required this.senderAddress,
    required this.senderSignature,
    required this.transportHint,
    required this.createdAt,
  });

  static const int currentVersion = 1;

  final int version;
  final String txId;
  final OfflineVoucherLeaf voucher;
  final OfflineVoucherProofBundle proofBundle;
  final String senderAddress;
  final String senderSignature;
  final String transportHint;
  final DateTime createdAt;

  Map<String, dynamic> _unsignedJson() => <String, dynamic>{
    'version': version,
    'voucher': voucher.toJson(),
    'proofBundle': proofBundle.toJson(),
    'senderAddress': senderAddress,
    'senderSignature': senderSignature,
    'transportHint': transportHint,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  String computeTxId() => _sha256HexFromObject(_unsignedJson());

  bool get isTxIdValid => txId == computeTxId();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'txId': txId,
    ..._unsignedJson(),
  };

  factory OfflineVoucherPayment.create({
    required OfflineVoucherLeaf voucher,
    required OfflineVoucherProofBundle proofBundle,
    required String senderAddress,
    required String senderSignature,
    required String transportHint,
    required DateTime createdAt,
  }) {
    final OfflineVoucherPayment unsigned = OfflineVoucherPayment(
      version: currentVersion,
      txId: '',
      voucher: voucher,
      proofBundle: proofBundle,
      senderAddress: senderAddress,
      senderSignature: senderSignature,
      transportHint: transportHint,
      createdAt: createdAt.toUtc(),
    );
    return OfflineVoucherPayment(
      version: unsigned.version,
      txId: unsigned.computeTxId(),
      voucher: unsigned.voucher,
      proofBundle: unsigned.proofBundle,
      senderAddress: unsigned.senderAddress,
      senderSignature: unsigned.senderSignature,
      transportHint: unsigned.transportHint,
      createdAt: unsigned.createdAt,
    );
  }

  factory OfflineVoucherPayment.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherPayment(
      version: (json['version'] as int?) ?? currentVersion,
      txId: (json['txId'] as String? ?? '').trim(),
      voucher: OfflineVoucherLeaf.fromJson(
        json['voucher'] as Map<String, dynamic>,
      ),
      proofBundle: OfflineVoucherProofBundle.fromJson(
        json['proofBundle'] as Map<String, dynamic>,
      ),
      senderAddress: (json['senderAddress'] as String? ?? '').trim(),
      senderSignature: (json['senderSignature'] as String? ?? '').trim(),
      transportHint: (json['transportHint'] as String? ?? '').trim(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }
}

class OfflineVoucherRelayMessage {
  const OfflineVoucherRelayMessage({
    required this.version,
    required this.txId,
    required this.payment,
    required this.hopCount,
    required this.priority,
    required this.createdAt,
    required this.expiresAt,
  });

  static const int currentVersion = 1;

  final int version;
  final String txId;
  final OfflineVoucherPayment payment;
  final int hopCount;
  final int priority;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
  bool get matchesPayment => txId == payment.txId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'txId': txId,
    'payment': payment.toJson(),
    'hopCount': hopCount,
    'priority': priority,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  factory OfflineVoucherRelayMessage.create({
    required OfflineVoucherPayment payment,
    required int hopCount,
    required int priority,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    return OfflineVoucherRelayMessage(
      version: currentVersion,
      txId: payment.txId,
      payment: payment,
      hopCount: hopCount,
      priority: priority,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
    );
  }

  factory OfflineVoucherRelayMessage.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherRelayMessage(
      version: (json['version'] as int?) ?? currentVersion,
      txId: (json['txId'] as String? ?? '').trim(),
      payment: OfflineVoucherPayment.fromJson(
        json['payment'] as Map<String, dynamic>,
      ),
      hopCount: (json['hopCount'] as int?) ?? 0,
      priority: (json['priority'] as int?) ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
  }
}

class OfflineVoucherClaimSubmission {
  const OfflineVoucherClaimSubmission({
    required this.version,
    required this.voucherId,
    required this.txId,
    required this.escrowId,
    required this.claimerAddress,
    required this.createdAt,
  });

  static const int currentVersion = 1;

  final int version;
  final String voucherId;
  final String txId;
  final String escrowId;
  final String claimerAddress;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'voucherId': voucherId,
    'txId': txId,
    'escrowId': escrowId,
    'claimerAddress': claimerAddress,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory OfflineVoucherClaimSubmission.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherClaimSubmission(
      version: (json['version'] as int?) ?? currentVersion,
      voucherId: (json['voucherId'] as String? ?? '').trim(),
      txId: (json['txId'] as String? ?? '').trim(),
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      claimerAddress: (json['claimerAddress'] as String? ?? '').trim(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }
}

class OfflineVoucherClaimRecord {
  const OfflineVoucherClaimRecord({
    required this.version,
    required this.voucherId,
    required this.txId,
    required this.escrowId,
    required this.claimerAddress,
    required this.status,
    required this.createdAt,
    this.submissionMode,
    this.submissionAttempts,
    this.graceLockExpiresAt,
    this.settlementTransactionHash,
    this.lastError,
    this.resolvedAt,
  });

  static const int currentVersion = 1;

  final int version;
  final String voucherId;
  final String txId;
  final String escrowId;
  final String claimerAddress;
  final OfflineVoucherClaimStatus status;
  final DateTime createdAt;
  final OfflineVoucherClaimSubmissionMode? submissionMode;
  final int? submissionAttempts;
  final DateTime? graceLockExpiresAt;
  final String? settlementTransactionHash;
  final String? lastError;
  final DateTime? resolvedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'voucherId': voucherId,
    'txId': txId,
    'escrowId': escrowId,
    'claimerAddress': claimerAddress,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'submissionMode': submissionMode?.name,
    'submissionAttempts': submissionAttempts,
    'graceLockExpiresAt': graceLockExpiresAt?.toUtc().toIso8601String(),
    'settlementTransactionHash': settlementTransactionHash,
    'lastError': lastError,
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
  };

  factory OfflineVoucherClaimRecord.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherClaimRecord(
      version: (json['version'] as int?) ?? currentVersion,
      voucherId: (json['voucherId'] as String? ?? '').trim(),
      txId: (json['txId'] as String? ?? '').trim(),
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      claimerAddress: (json['claimerAddress'] as String? ?? '').trim(),
      status: OfflineVoucherClaimStatus.values.byName(
        (json['status'] as String?) ?? OfflineVoucherClaimStatus.invalidRejected.name,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      submissionMode: (json['submissionMode'] as String?) == null
          ? null
          : OfflineVoucherClaimSubmissionMode.values.byName(
              json['submissionMode'] as String,
            ),
      submissionAttempts: json['submissionAttempts'] as int?,
      graceLockExpiresAt: (json['graceLockExpiresAt'] as String?) == null
          ? null
          : DateTime.parse(json['graceLockExpiresAt'] as String).toUtc(),
      settlementTransactionHash:
          (json['settlementTransactionHash'] as String?)?.trim(),
      lastError: (json['lastError'] as String?)?.trim(),
      resolvedAt: (json['resolvedAt'] as String?) == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String).toUtc(),
    );
  }
}

class OfflineVoucherClaimSettlementUpdate {
  const OfflineVoucherClaimSettlementUpdate({
    required this.version,
    required this.voucherId,
    required this.txId,
    required this.escrowId,
    required this.status,
    required this.updatedAt,
    this.settlementTransactionHash,
    this.errorMessage,
  });

  static const int currentVersion = 1;

  final int version;
  final String voucherId;
  final String txId;
  final String escrowId;
  final OfflineVoucherClaimStatus status;
  final DateTime updatedAt;
  final String? settlementTransactionHash;
  final String? errorMessage;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'voucherId': voucherId,
    'txId': txId,
    'escrowId': escrowId,
    'status': status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'settlementTransactionHash': settlementTransactionHash,
    'errorMessage': errorMessage,
  };

  factory OfflineVoucherClaimSettlementUpdate.fromJson(
    Map<String, dynamic> json,
  ) {
    return OfflineVoucherClaimSettlementUpdate(
      version: (json['version'] as int?) ?? currentVersion,
      voucherId: (json['voucherId'] as String? ?? '').trim(),
      txId: (json['txId'] as String? ?? '').trim(),
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      status: OfflineVoucherClaimStatus.values.byName(
        (json['status'] as String?) ??
            OfflineVoucherClaimStatus.invalidRejected.name,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      settlementTransactionHash:
          (json['settlementTransactionHash'] as String?)?.trim(),
      errorMessage: (json['errorMessage'] as String?)?.trim(),
    );
  }
}

class OfflineVoucherRefundEligibility {
  const OfflineVoucherRefundEligibility({
    required this.escrowId,
    required this.refundable,
    required this.reason,
    this.lockedUntil,
    this.blockingVoucherId,
  });

  final String escrowId;
  final bool refundable;
  final String reason;
  final DateTime? lockedUntil;
  final String? blockingVoucherId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'escrowId': escrowId,
    'refundable': refundable,
    'reason': reason,
    'lockedUntil': lockedUntil?.toUtc().toIso8601String(),
    'blockingVoucherId': blockingVoucherId,
  };

  factory OfflineVoucherRefundEligibility.fromJson(
    Map<String, dynamic> json,
  ) {
    return OfflineVoucherRefundEligibility(
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      refundable: (json['refundable'] as bool?) ?? false,
      reason: (json['reason'] as String? ?? '').trim(),
      lockedUntil: (json['lockedUntil'] as String?) == null
          ? null
          : DateTime.parse(json['lockedUntil'] as String).toUtc(),
      blockingVoucherId: (json['blockingVoucherId'] as String?)?.trim(),
    );
  }
}

class OfflineVoucherClaimAttempt {
  const OfflineVoucherClaimAttempt({
    required this.version,
    required this.transferId,
    required this.voucherId,
    required this.txId,
    required this.escrowId,
    required this.chain,
    required this.network,
    required this.accountSlot,
    required this.claimerAddress,
    required this.settlementContractAddress,
    required this.voucher,
    required this.assignmentSignatureHex,
    required this.voucherProof,
    required this.status,
    required this.queuedAt,
    required this.nextAttemptAt,
    this.submissionMode,
    this.attemptCount = 0,
    this.lastAttemptedAt,
    this.submittedTransactionHash,
    this.sponsoredFallbackRequested = false,
    this.lastError,
    this.confirmedAt,
  });

  static const int currentVersion = 1;

  final int version;
  final String transferId;
  final String voucherId;
  final String txId;
  final String escrowId;
  final ChainKind chain;
  final ChainNetwork network;
  final int accountSlot;
  final String claimerAddress;
  final String settlementContractAddress;
  final OfflineVoucherLeaf voucher;
  final String assignmentSignatureHex;
  final List<String> voucherProof;
  final OfflineVoucherClaimStatus status;
  final OfflineVoucherClaimSubmissionMode? submissionMode;
  final DateTime queuedAt;
  final DateTime nextAttemptAt;
  final int attemptCount;
  final DateTime? lastAttemptedAt;
  final String? submittedTransactionHash;
  final bool sponsoredFallbackRequested;
  final String? lastError;
  final DateTime? confirmedAt;

  bool get isTerminal =>
      status == OfflineVoucherClaimStatus.confirmedOnchain ||
      status == OfflineVoucherClaimStatus.expiredRejected ||
      status == OfflineVoucherClaimStatus.invalidRejected ||
      status == OfflineVoucherClaimStatus.duplicateRejected;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'transferId': transferId,
    'voucherId': voucherId,
    'txId': txId,
    'escrowId': escrowId,
    'chain': chain.name,
    'network': network.name,
    'accountSlot': accountSlot,
    'claimerAddress': claimerAddress,
    'settlementContractAddress': settlementContractAddress,
    'voucher': voucher.toJson(),
    'assignmentSignatureHex': assignmentSignatureHex,
    'voucherProof': voucherProof,
    'status': status.name,
    'submissionMode': submissionMode?.name,
    'queuedAt': queuedAt.toUtc().toIso8601String(),
    'nextAttemptAt': nextAttemptAt.toUtc().toIso8601String(),
    'attemptCount': attemptCount,
    'lastAttemptedAt': lastAttemptedAt?.toUtc().toIso8601String(),
    'submittedTransactionHash': submittedTransactionHash,
    'sponsoredFallbackRequested': sponsoredFallbackRequested,
    'lastError': lastError,
    'confirmedAt': confirmedAt?.toUtc().toIso8601String(),
  };

  factory OfflineVoucherClaimAttempt.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherClaimAttempt(
      version: (json['version'] as int?) ?? currentVersion,
      transferId: (json['transferId'] as String? ?? '').trim(),
      voucherId: (json['voucherId'] as String? ?? '').trim(),
      txId: (json['txId'] as String? ?? '').trim(),
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      chain: ChainKind.values.byName(
        (json['chain'] as String?) ?? ChainKind.ethereum.name,
      ),
      network: ChainNetwork.values.byName(
        (json['network'] as String?) ?? ChainNetwork.testnet.name,
      ),
      accountSlot: (json['accountSlot'] as int?) ?? 0,
      claimerAddress: (json['claimerAddress'] as String? ?? '').trim(),
      settlementContractAddress:
          (json['settlementContractAddress'] as String? ?? '').trim(),
      voucher: OfflineVoucherLeaf.fromJson(
        Map<String, dynamic>.from(json['voucher'] as Map),
      ),
      assignmentSignatureHex:
          (json['assignmentSignatureHex'] as String? ?? '').trim(),
      voucherProof:
          ((json['voucherProof'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic value) => '$value'.trim())
              .where((String value) => value.isNotEmpty)
              .toList(growable: false),
      status: OfflineVoucherClaimStatus.values.byName(
        (json['status'] as String?) ?? OfflineVoucherClaimStatus.accepted.name,
      ),
      submissionMode: (json['submissionMode'] as String?) == null
          ? null
          : OfflineVoucherClaimSubmissionMode.values.byName(
              json['submissionMode'] as String,
            ),
      queuedAt: DateTime.parse(json['queuedAt'] as String).toUtc(),
      nextAttemptAt: DateTime.parse(json['nextAttemptAt'] as String).toUtc(),
      attemptCount: (json['attemptCount'] as int?) ?? 0,
      lastAttemptedAt: (json['lastAttemptedAt'] as String?) == null
          ? null
          : DateTime.parse(json['lastAttemptedAt'] as String).toUtc(),
      submittedTransactionHash:
          (json['submittedTransactionHash'] as String?)?.trim(),
      sponsoredFallbackRequested:
          (json['sponsoredFallbackRequested'] as bool?) ?? false,
      lastError: (json['lastError'] as String?)?.trim(),
      confirmedAt: (json['confirmedAt'] as String?) == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String).toUtc(),
    );
  }

  OfflineVoucherClaimAttempt copyWith({
    OfflineVoucherClaimStatus? status,
    OfflineVoucherClaimSubmissionMode? submissionMode,
    DateTime? nextAttemptAt,
    int? attemptCount,
    DateTime? lastAttemptedAt,
    String? submittedTransactionHash,
    bool? sponsoredFallbackRequested,
    String? lastError,
    bool clearLastError = false,
    DateTime? confirmedAt,
  }) {
    return OfflineVoucherClaimAttempt(
      version: version,
      transferId: transferId,
      voucherId: voucherId,
      txId: txId,
      escrowId: escrowId,
      chain: chain,
      network: network,
      accountSlot: accountSlot,
      claimerAddress: claimerAddress,
      settlementContractAddress: settlementContractAddress,
      voucher: voucher,
      assignmentSignatureHex: assignmentSignatureHex,
      voucherProof: voucherProof,
      status: status ?? this.status,
      submissionMode: submissionMode ?? this.submissionMode,
      queuedAt: queuedAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      submittedTransactionHash:
          submittedTransactionHash ?? this.submittedTransactionHash,
      sponsoredFallbackRequested:
          sponsoredFallbackRequested ?? this.sponsoredFallbackRequested,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

enum OfflineTransportPayloadKind { legacyEnvelope, voucherBundle }

class OfflineTransportPayload {
  const OfflineTransportPayload._({
    required this.kind,
    this.envelope,
    this.voucherBundle,
  });

  factory OfflineTransportPayload.envelope(OfflineEnvelope envelope) =>
      OfflineTransportPayload._(
        kind: OfflineTransportPayloadKind.legacyEnvelope,
        envelope: envelope,
      );

  factory OfflineTransportPayload.voucherBundle(
    OfflineVoucherTransferBundle bundle,
  ) => OfflineTransportPayload._(
    kind: OfflineTransportPayloadKind.voucherBundle,
    voucherBundle: bundle,
  );

  final OfflineTransportPayloadKind kind;
  final OfflineEnvelope? envelope;
  final OfflineVoucherTransferBundle? voucherBundle;

  Map<String, dynamic> toJson() => switch (kind) {
    OfflineTransportPayloadKind.legacyEnvelope => <String, dynamic>{
      'version': 1,
      'type': 'envelope',
      'envelope': envelope!.toJson(),
    },
    OfflineTransportPayloadKind.voucherBundle => <String, dynamic>{
      'version': 1,
      'type': 'voucher_bundle',
      'bundle': voucherBundle!.toJson(),
    },
  };

  factory OfflineTransportPayload.fromJson(Map<String, dynamic> json) {
    final String type = (json['type'] as String? ?? '').trim();
    if (type == 'envelope') {
      return OfflineTransportPayload.envelope(
        OfflineEnvelope.fromJson(
          Map<String, dynamic>.from(json['envelope'] as Map),
        ),
      );
    }
    if (type == 'voucher_bundle') {
      return OfflineTransportPayload.voucherBundle(
        OfflineVoucherTransferBundle.fromJson(
          Map<String, dynamic>.from(json['bundle'] as Map),
        ),
      );
    }
    if (json.containsKey('signedTransactionBase64')) {
      return OfflineTransportPayload.envelope(OfflineEnvelope.fromJson(json));
    }
    if (json.containsKey('payments') &&
        json.containsKey('settlementContractAddress')) {
      return OfflineTransportPayload.voucherBundle(
        OfflineVoucherTransferBundle.fromJson(json),
      );
    }
    throw const FormatException('Unsupported offline transport payload.');
  }
}

class OfflineVoucherInventoryEntry {
  const OfflineVoucherInventoryEntry({
    required this.escrowId,
    required this.voucher,
    required this.proofBundle,
    this.reservedForTransferId,
    this.claimedAt,
  });

  final String escrowId;
  final OfflineVoucherLeaf voucher;
  final OfflineVoucherProofBundle proofBundle;
  final String? reservedForTransferId;
  final DateTime? claimedAt;

  bool get isReserved =>
      reservedForTransferId != null && reservedForTransferId!.isNotEmpty;
  bool get isClaimed => claimedAt != null;
  bool get isAvailable => !isReserved && !isClaimed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'escrowId': escrowId,
    'voucher': voucher.toJson(),
    'proofBundle': proofBundle.toJson(),
    'reservedForTransferId': reservedForTransferId,
    'claimedAt': claimedAt?.toUtc().toIso8601String(),
  };

  factory OfflineVoucherInventoryEntry.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherInventoryEntry(
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      voucher: OfflineVoucherLeaf.fromJson(
        json['voucher'] as Map<String, dynamic>,
      ),
      proofBundle: OfflineVoucherProofBundle.fromJson(
        json['proofBundle'] as Map<String, dynamic>,
      ),
      reservedForTransferId: (json['reservedForTransferId'] as String?)?.trim(),
      claimedAt: (json['claimedAt'] as String?) == null
          ? null
          : DateTime.parse(json['claimedAt'] as String).toUtc(),
    );
  }
}

class OfflineVoucherEscrowSession {
  const OfflineVoucherEscrowSession({
    required this.commitment,
    required this.settlementContractAddress,
    required this.assetContractAddress,
    required this.availableAmountBaseUnits,
    required this.gasReserveBaseUnits,
    required this.inventory,
    this.creationTransactionHash,
    this.refundTransactionHash,
    this.refundedAt,
  });

  final OfflineVoucherEscrowCommitment commitment;
  final String settlementContractAddress;
  final String? assetContractAddress;
  final String availableAmountBaseUnits;
  final String gasReserveBaseUnits;
  final List<OfflineVoucherInventoryEntry> inventory;
  final String? creationTransactionHash;
  final String? refundTransactionHash;
  final DateTime? refundedAt;

  bool get isRefunded => refundedAt != null;
  BigInt get availableBaseUnits => inventory
      .where((OfflineVoucherInventoryEntry item) => item.isAvailable)
      .fold<BigInt>(
        BigInt.zero,
        (BigInt total, OfflineVoucherInventoryEntry item) =>
            total + BigInt.parse(item.voucher.amountBaseUnits),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'commitment': commitment.toJson(),
    'settlementContractAddress': settlementContractAddress,
    'assetContractAddress': assetContractAddress,
    'availableAmountBaseUnits': availableAmountBaseUnits,
    'gasReserveBaseUnits': gasReserveBaseUnits,
    'inventory': inventory.map((item) => item.toJson()).toList(growable: false),
    'creationTransactionHash': creationTransactionHash,
    'refundTransactionHash': refundTransactionHash,
    'refundedAt': refundedAt?.toUtc().toIso8601String(),
  };

  factory OfflineVoucherEscrowSession.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherEscrowSession(
      commitment: OfflineVoucherEscrowCommitment.fromJson(
        json['commitment'] as Map<String, dynamic>,
      ),
      settlementContractAddress:
          (json['settlementContractAddress'] as String? ?? '').trim(),
      assetContractAddress: (json['assetContractAddress'] as String?)?.trim(),
      availableAmountBaseUnits:
          (json['availableAmountBaseUnits'] as String? ?? '0').trim(),
      gasReserveBaseUnits:
          (json['gasReserveBaseUnits'] as String? ?? '0').trim(),
      inventory: ((json['inventory'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OfflineVoucherInventoryEntry.fromJson)
          .toList(growable: false),
      creationTransactionHash: (json['creationTransactionHash'] as String?)
          ?.trim(),
      refundTransactionHash:
          (json['refundTransactionHash'] as String?)?.trim(),
      refundedAt: (json['refundedAt'] as String?) == null
          ? null
          : DateTime.parse(json['refundedAt'] as String).toUtc(),
    );
  }

  OfflineVoucherEscrowSession copyWith({
    List<OfflineVoucherInventoryEntry>? inventory,
    String? availableAmountBaseUnits,
    String? creationTransactionHash,
    String? refundTransactionHash,
    DateTime? refundedAt,
  }) {
    return OfflineVoucherEscrowSession(
      commitment: commitment,
      settlementContractAddress: settlementContractAddress,
      assetContractAddress: assetContractAddress,
      availableAmountBaseUnits:
          availableAmountBaseUnits ?? this.availableAmountBaseUnits,
      gasReserveBaseUnits: gasReserveBaseUnits,
      inventory: inventory ?? this.inventory,
      creationTransactionHash:
          creationTransactionHash ?? this.creationTransactionHash,
      refundTransactionHash: refundTransactionHash ?? this.refundTransactionHash,
      refundedAt: refundedAt ?? this.refundedAt,
    );
  }
}

class OfflineVoucherOnChainEscrow {
  const OfflineVoucherOnChainEscrow({
    required this.ownerAddress,
    required this.assetContractAddress,
    required this.totalAmountBaseUnits,
    required this.remainingAmountBaseUnits,
    required this.expiryAt,
    required this.voucherRoot,
    required this.refunded,
  });

  final String ownerAddress;
  final String assetContractAddress;
  final String totalAmountBaseUnits;
  final String remainingAmountBaseUnits;
  final DateTime expiryAt;
  final String voucherRoot;
  final bool refunded;
}

class OfflineVoucherTransferBundle {
  const OfflineVoucherTransferBundle({
    required this.version,
    required this.transferId,
    required this.chain,
    required this.network,
    required this.escrowId,
    required this.settlementContractAddress,
    required this.senderAddress,
    required this.receiverAddress,
    required this.payments,
    required this.totalAmountBaseUnits,
    required this.createdAt,
    required this.transportHint,
    required this.integrityChecksum,
  });

  static const int currentVersion = 1;

  final int version;
  final String transferId;
  final ChainKind chain;
  final ChainNetwork network;
  final String escrowId;
  final String settlementContractAddress;
  final String senderAddress;
  final String receiverAddress;
  final List<OfflineVoucherPayment> payments;
  final String totalAmountBaseUnits;
  final DateTime createdAt;
  final String transportHint;
  final String integrityChecksum;

  Map<String, dynamic> _checksumPayload() => <String, dynamic>{
    'version': version,
    'transferId': transferId,
    'chain': chain.name,
    'network': network.name,
    'escrowId': escrowId,
    'settlementContractAddress': settlementContractAddress,
    'senderAddress': senderAddress,
    'receiverAddress': receiverAddress,
    'payments': payments.map((item) => item.toJson()).toList(growable: false),
    'totalAmountBaseUnits': totalAmountBaseUnits,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'transportHint': transportHint,
  };

  String computeChecksum() => _sha256HexFromObject(_checksumPayload());

  bool get isChecksumValid => integrityChecksum == computeChecksum();

  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._checksumPayload(),
    'integrityChecksum': integrityChecksum,
  };

  factory OfflineVoucherTransferBundle.create({
    required String transferId,
    required ChainKind chain,
    required ChainNetwork network,
    required String escrowId,
    required String settlementContractAddress,
    required String senderAddress,
    required String receiverAddress,
    required List<OfflineVoucherPayment> payments,
    required String totalAmountBaseUnits,
    required DateTime createdAt,
    required TransportKind transportKind,
  }) {
    final OfflineVoucherTransferBundle unsigned = OfflineVoucherTransferBundle(
      version: currentVersion,
      transferId: transferId,
      chain: chain,
      network: network,
      escrowId: escrowId,
      settlementContractAddress: settlementContractAddress,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      payments: List<OfflineVoucherPayment>.unmodifiable(payments),
      totalAmountBaseUnits: totalAmountBaseUnits,
      createdAt: createdAt,
      transportHint: transportKind.name,
      integrityChecksum: '',
    );
    return OfflineVoucherTransferBundle(
      version: unsigned.version,
      transferId: unsigned.transferId,
      chain: unsigned.chain,
      network: unsigned.network,
      escrowId: unsigned.escrowId,
      settlementContractAddress: unsigned.settlementContractAddress,
      senderAddress: unsigned.senderAddress,
      receiverAddress: unsigned.receiverAddress,
      payments: unsigned.payments,
      totalAmountBaseUnits: unsigned.totalAmountBaseUnits,
      createdAt: unsigned.createdAt,
      transportHint: unsigned.transportHint,
      integrityChecksum: unsigned.computeChecksum(),
    );
  }

  factory OfflineVoucherTransferBundle.fromJson(Map<String, dynamic> json) {
    return OfflineVoucherTransferBundle(
      version: (json['version'] as int?) ?? currentVersion,
      transferId: (json['transferId'] as String? ?? '').trim(),
      chain: ChainKind.values.byName(
        (json['chain'] as String?) ?? ChainKind.ethereum.name,
      ),
      network: ChainNetwork.values.byName(
        (json['network'] as String?) ?? ChainNetwork.testnet.name,
      ),
      escrowId: (json['escrowId'] as String? ?? '').trim(),
      settlementContractAddress:
          (json['settlementContractAddress'] as String? ?? '').trim(),
      senderAddress: (json['senderAddress'] as String? ?? '').trim(),
      receiverAddress: (json['receiverAddress'] as String? ?? '').trim(),
      payments: ((json['payments'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OfflineVoucherPayment.fromJson)
          .toList(growable: false),
      totalAmountBaseUnits:
          (json['totalAmountBaseUnits'] as String? ?? '0').trim(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      transportHint: (json['transportHint'] as String? ?? '').trim(),
      integrityChecksum: (json['integrityChecksum'] as String? ?? '').trim(),
    );
  }
}

class UltrasonicTransferPacket {
  const UltrasonicTransferPacket({
    required this.version,
    required this.chain,
    required this.network,
    required this.transferId,
    required this.createdAt,
    required this.sessionToken,
    required this.signedTransactionBytes,
    required this.checksum,
  });

  static const int currentVersion = 1;
  static const int sessionTokenLength = 16;
  static const int checksumLength = 32;
  static const int maximumEncodedLength = 256;

  final int version;
  final ChainKind chain;
  final ChainNetwork network;
  final String transferId;
  final DateTime createdAt;
  final String sessionToken;
  final Uint8List signedTransactionBytes;
  final String checksum;

  Uint8List _payloadBytes() {
    final Uint8List transferIdBytes = _uuidStringToBytes(transferId);
    final Uint8List tokenBytes = _sessionTokenToBytes(sessionToken);
    final ByteData header = ByteData(1 + 1 + 1 + 16 + 8 + 16 + 2);
    int offset = 0;
    header.setUint8(offset, version);
    offset += 1;
    header.setUint8(offset, chain.index);
    offset += 1;
    header.setUint8(offset, network.index);
    offset += 1;
    for (int i = 0; i < transferIdBytes.length; i += 1) {
      header.setUint8(offset + i, transferIdBytes[i]);
    }
    offset += transferIdBytes.length;
    header.setInt64(offset, createdAt.millisecondsSinceEpoch, Endian.big);
    offset += 8;
    for (int i = 0; i < tokenBytes.length; i += 1) {
      header.setUint8(offset + i, tokenBytes[i]);
    }
    offset += tokenBytes.length;
    header.setUint16(offset, signedTransactionBytes.length, Endian.big);
    return Uint8List.fromList(<int>[
      ...header.buffer.asUint8List(),
      ...signedTransactionBytes,
    ]);
  }

  String computeChecksum() {
    return sha256.convert(_payloadBytes()).toString();
  }

  bool get isChecksumValid => checksum == computeChecksum();

  Uint8List toBytes() {
    return Uint8List.fromList(<int>[
      ..._payloadBytes(),
      ..._hexToBytes(checksum),
    ]);
  }

  factory UltrasonicTransferPacket.create({
    required ChainKind chain,
    required ChainNetwork network,
    required String transferId,
    required DateTime createdAt,
    required String sessionToken,
    required Uint8List signedTransactionBytes,
  }) {
    final UltrasonicTransferPacket unsigned = UltrasonicTransferPacket(
      version: currentVersion,
      chain: chain,
      network: network,
      transferId: transferId,
      createdAt: createdAt,
      sessionToken: sessionToken,
      signedTransactionBytes: signedTransactionBytes,
      checksum: '',
    );
    return UltrasonicTransferPacket(
      version: unsigned.version,
      chain: unsigned.chain,
      network: unsigned.network,
      transferId: unsigned.transferId,
      createdAt: unsigned.createdAt,
      sessionToken: unsigned.sessionToken,
      signedTransactionBytes: unsigned.signedTransactionBytes,
      checksum: unsigned.computeChecksum(),
    );
  }

  factory UltrasonicTransferPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < 77) {
      throw const FormatException('Ultrasonic transfer packet is too short.');
    }
    final ByteData header = ByteData.sublistView(bytes, 0, 45);
    int offset = 0;
    final int version = header.getUint8(offset);
    offset += 1;
    if (version != currentVersion) {
      throw const FormatException('Unsupported ultrasonic transfer version.');
    }
    final ChainKind chain = ChainKind.values[header.getUint8(offset)];
    offset += 1;
    final ChainNetwork network = ChainNetwork.values[header.getUint8(offset)];
    offset += 1;
    final String transferId = _uuidBytesToString(bytes.sublist(offset, offset + 16));
    offset += 16;
    final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
      header.getInt64(offset, Endian.big),
    );
    offset += 8;
    final String sessionToken = _sessionTokenBytesToString(
      bytes.sublist(offset, offset + sessionTokenLength),
    );
    offset += sessionTokenLength;
    final int signedLength = header.getUint16(offset, Endian.big);
    offset += 2;
    final int signedEnd = 45 + signedLength;
    if (signedEnd + checksumLength > bytes.length) {
      throw const FormatException('Ultrasonic transfer payload is truncated.');
    }
    final Uint8List signedTransactionBytes = Uint8List.fromList(
      bytes.sublist(45, signedEnd),
    );
    final String checksum = _bytesToHex(
      bytes.sublist(signedEnd, signedEnd + checksumLength),
    );
    return UltrasonicTransferPacket(
      version: version,
      chain: chain,
      network: network,
      transferId: transferId,
      createdAt: createdAt,
      sessionToken: sessionToken,
      signedTransactionBytes: signedTransactionBytes,
      checksum: checksum,
    );
  }
}

class UltrasonicAckPacket {
  const UltrasonicAckPacket({
    required this.version,
    required this.transferId,
    required this.sessionToken,
    required this.accepted,
    required this.checksum,
  });

  static const int currentVersion = 1;
  static const int checksumLength = 32;

  final int version;
  final String transferId;
  final String sessionToken;
  final bool accepted;
  final String checksum;

  Uint8List _payloadBytes() {
    final Uint8List transferIdBytes = _uuidStringToBytes(transferId);
    final Uint8List tokenBytes = _sessionTokenToBytes(sessionToken);
    return Uint8List.fromList(<int>[
      version,
      ...transferIdBytes,
      ...tokenBytes,
      accepted ? 1 : 0,
    ]);
  }

  String computeChecksum() => sha256.convert(_payloadBytes()).toString();

  bool get isChecksumValid => checksum == computeChecksum();

  Uint8List toBytes() => Uint8List.fromList(<int>[
    ..._payloadBytes(),
    ..._hexToBytes(checksum),
  ]);

  factory UltrasonicAckPacket.create({
    required String transferId,
    required String sessionToken,
    required bool accepted,
  }) {
    final UltrasonicAckPacket unsigned = UltrasonicAckPacket(
      version: currentVersion,
      transferId: transferId,
      sessionToken: sessionToken,
      accepted: accepted,
      checksum: '',
    );
    return UltrasonicAckPacket(
      version: unsigned.version,
      transferId: unsigned.transferId,
      sessionToken: unsigned.sessionToken,
      accepted: unsigned.accepted,
      checksum: unsigned.computeChecksum(),
    );
  }

  factory UltrasonicAckPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < 1 + 16 + UltrasonicTransferPacket.sessionTokenLength + 1 + checksumLength) {
      throw const FormatException('Ultrasonic acknowledgement is too short.');
    }
    final int version = bytes[0];
    if (version != currentVersion) {
      throw const FormatException('Unsupported ultrasonic acknowledgement version.');
    }
    final String transferId = _uuidBytesToString(bytes.sublist(1, 17));
    final String sessionToken = _sessionTokenBytesToString(
      bytes.sublist(17, 33),
    );
    final bool accepted = bytes[33] == 1;
    final String checksum = _bytesToHex(
      bytes.sublist(34, 34 + checksumLength),
    );
    return UltrasonicAckPacket(
      version: version,
      transferId: transferId,
      sessionToken: sessionToken,
      accepted: accepted,
      checksum: checksum,
    );
  }
}

class RelayCapsule {
  const RelayCapsule({
    required this.version,
    required this.relayId,
    required this.createdAt,
    required this.nonceBase64,
    required this.encryptedPacketBase64,
  });

  static const int currentVersion = 1;

  final int version;
  final String relayId;
  final DateTime createdAt;
  final String nonceBase64;
  final String encryptedPacketBase64;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'relayId': relayId,
    'createdAt': createdAt.toIso8601String(),
    'nonceBase64': nonceBase64,
    'encryptedPacketBase64': encryptedPacketBase64,
  };

  String toQrData() => jsonEncode(toJson());

  factory RelayCapsule.fromJson(Map<String, dynamic> json) => RelayCapsule(
    version: (json['version'] as int?) ?? currentVersion,
    relayId: json['relayId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    nonceBase64: json['nonceBase64'] as String,
    encryptedPacketBase64: json['encryptedPacketBase64'] as String,
  );
}

class PendingRelaySession {
  const PendingRelaySession({
    required this.relayId,
    required this.sessionToken,
    required this.chain,
    required this.network,
    required this.receiverAddress,
    required this.createdAt,
  });

  final String relayId;
  final String sessionToken;
  final ChainKind chain;
  final ChainNetwork network;
  final String receiverAddress;
  final DateTime createdAt;

  bool get isExpired =>
      DateTime.now().difference(createdAt) > const Duration(hours: 24);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'relayId': relayId,
    'sessionToken': sessionToken,
    'chain': chain.name,
    'network': network.name,
    'receiverAddress': receiverAddress,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingRelaySession.fromJson(Map<String, dynamic> json) =>
      PendingRelaySession(
        relayId: json['relayId'] as String,
        sessionToken: json['sessionToken'] as String,
        chain: ChainKind.values.byName(json['chain'] as String),
        network: ChainNetwork.values.byName(json['network'] as String),
        receiverAddress: json['receiverAddress'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class PreparedRelayCapsule {
  const PreparedRelayCapsule({
    required this.transfer,
    required this.relayCapsule,
    required this.relayUrl,
  });

  final PendingTransfer transfer;
  final RelayCapsule relayCapsule;
  final Uri relayUrl;
}

class OfflineEnvelope {
  const OfflineEnvelope({
    required this.version,
    required this.chain,
    required this.network,
    required this.transferId,
    required this.createdAt,
    required this.senderAddress,
    required this.receiverAddress,
    required this.amountLamports,
    required this.signedTransactionBase64,
    required this.transportHint,
    required this.integrityChecksum,
  });

  final int version;
  final ChainKind chain;
  final ChainNetwork network;
  final String transferId;
  final DateTime createdAt;
  final String senderAddress;
  final String receiverAddress;
  final int amountLamports;
  final String signedTransactionBase64;
  final String transportHint;
  final String integrityChecksum;

  Map<String, dynamic> _checksumPayload() => <String, dynamic>{
    'version': version,
    'chain': chain.name,
    'network': network.name,
    'transferId': transferId,
    'createdAt': createdAt.toIso8601String(),
    'senderAddress': senderAddress,
    'receiverAddress': receiverAddress,
    'amountLamports': amountLamports,
    'signedTransactionBase64': signedTransactionBase64,
    'transportHint': transportHint,
  };

  String computeChecksum() {
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(_checksumPayload())),
    );
    return sha256.convert(bytes).toString();
  }

  bool get isChecksumValid => integrityChecksum == computeChecksum();

  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._checksumPayload(),
    'integrityChecksum': integrityChecksum,
  };

  factory OfflineEnvelope.create({
    required String transferId,
    required DateTime createdAt,
    required ChainKind chain,
    required ChainNetwork network,
    required String senderAddress,
    required String receiverAddress,
    required int amountLamports,
    required String signedTransactionBase64,
    required TransportKind transportKind,
  }) {
    final OfflineEnvelope unsigned = OfflineEnvelope(
      version: 1,
      chain: chain,
      network: network,
      transferId: transferId,
      createdAt: createdAt,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      amountLamports: amountLamports,
      signedTransactionBase64: signedTransactionBase64,
      transportHint: transportKind.name,
      integrityChecksum: '',
    );
    return OfflineEnvelope(
      version: unsigned.version,
      chain: unsigned.chain,
      network: unsigned.network,
      transferId: unsigned.transferId,
      createdAt: unsigned.createdAt,
      senderAddress: unsigned.senderAddress,
      receiverAddress: unsigned.receiverAddress,
      amountLamports: unsigned.amountLamports,
      signedTransactionBase64: unsigned.signedTransactionBase64,
      transportHint: unsigned.transportHint,
      integrityChecksum: unsigned.computeChecksum(),
    );
  }

  factory OfflineEnvelope.fromJson(Map<String, dynamic> json) =>
      OfflineEnvelope(
        version: json['version'] as int,
        chain: ChainKind.values.byName(
          (json['chain'] as String?) ?? ChainKind.solana.name,
        ),
        network: ChainNetwork.values.byName(
          (json['network'] as String?) ?? ChainNetwork.testnet.name,
        ),
        transferId: json['transferId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        senderAddress: json['senderAddress'] as String,
        receiverAddress: json['receiverAddress'] as String,
        amountLamports: json['amountLamports'] as int,
        signedTransactionBase64: json['signedTransactionBase64'] as String,
        transportHint: json['transportHint'] as String,
        integrityChecksum: json['integrityChecksum'] as String,
      );
}

class PendingTransfer {
  const PendingTransfer({
    required this.transferId,
    required this.chain,
    required this.network,
    required this.walletEngine,
    required this.direction,
    required this.status,
    required this.amountLamports,
    required this.senderAddress,
    required this.receiverAddress,
    required this.transport,
    required this.createdAt,
    required this.updatedAt,
    this.assetId = '',
    this.assetSymbol = '',
    this.assetDisplayName = '',
    this.assetDecimals,
    this.assetContractAddress,
    this.isNativeAsset = true,
    this.envelope,
    this.remoteEndpoint,
    this.transactionSignature,
    this.explorerUrl,
    this.lastError,
    this.confirmedAt,
    this.bitgoWalletId,
    this.bitgoTransferId,
    this.backendStatus,
    this.fileverseReceiptId,
    this.fileverseReceiptUrl,
    this.fileverseSavedAt,
    this.fileverseStorageMode,
    this.fileverseMessage,
  });

  final String transferId;
  final ChainKind chain;
  final ChainNetwork network;
  final WalletEngine walletEngine;
  final TransferDirection direction;
  final TransferStatus status;
  final int amountLamports;
  final String senderAddress;
  final String receiverAddress;
  final TransportKind transport;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String assetId;
  final String assetSymbol;
  final String assetDisplayName;
  final int? assetDecimals;
  final String? assetContractAddress;
  final bool isNativeAsset;
  final OfflineEnvelope? envelope;
  final String? remoteEndpoint;
  final String? transactionSignature;
  final String? explorerUrl;
  final String? lastError;
  final DateTime? confirmedAt;
  final String? bitgoWalletId;
  final String? bitgoTransferId;
  final String? backendStatus;
  final String? fileverseReceiptId;
  final String? fileverseReceiptUrl;
  final DateTime? fileverseSavedAt;
  final String? fileverseStorageMode;
  final String? fileverseMessage;

  bool get isInbound => direction == TransferDirection.inbound;
  bool get isBitGo => walletEngine == WalletEngine.bitgo;
  bool get isDirectOnchainTransfer =>
      walletEngine == WalletEngine.local && transport == TransportKind.online;
  double get amountSol => isNativeAsset
      ? chain.amountFromBaseUnits(amountLamports)
      : amountLamports / _pow10(resolvedAssetDecimals);
  String get resolvedAssetId => assetId.isEmpty
      ? '${chain.name}:${network.name}:native'
      : assetId;
  String get resolvedAssetSymbol =>
      assetSymbol.isEmpty ? chain.assetDisplayLabel : assetSymbol;
  String get resolvedAssetDisplayName =>
      assetDisplayName.isEmpty ? chain.label : assetDisplayName;
  int get resolvedAssetDecimals => assetDecimals ?? chain.decimals;
  String get counterpartyAddress => isInbound ? senderAddress : receiverAddress;
  bool get isReceiptSavedInFileverse => fileverseStorageMode == 'fileverse';
  bool get hasReceiptLink =>
      fileverseReceiptUrl != null && fileverseReceiptUrl!.isNotEmpty;
  bool get hasReceiptArchive =>
      (fileverseReceiptId != null && fileverseReceiptId!.isNotEmpty) ||
      hasReceiptLink ||
      fileverseSavedAt != null ||
      (fileverseMessage != null && fileverseMessage!.isNotEmpty);
  String? get receiptStorageLabel => switch (fileverseStorageMode) {
    'fileverse' => 'Saved in Fileverse',
    'worker' => 'Archived by Bitsend',
    _ => null,
  };
  bool get reservesOfflineFunds =>
      walletEngine == WalletEngine.local &&
      transport != TransportKind.online &&
      direction == TransferDirection.outbound &&
      switch (status) {
        TransferStatus.sentOffline ||
        TransferStatus.broadcasting ||
        TransferStatus.broadcastSubmitted ||
        TransferStatus.broadcastFailed => true,
        _ => false,
      };
  bool get canBroadcast => switch (walletEngine) {
    WalletEngine.local => switch (status) {
      TransferStatus.sentOffline ||
      TransferStatus.receivedPendingBroadcast ||
      TransferStatus.broadcastFailed => envelope != null,
      _ => false,
    },
    WalletEngine.bitgo => status == TransferStatus.broadcastFailed,
  };
  bool get canRetryBroadcast => status == TransferStatus.broadcastFailed;
  bool get needsInitialBroadcast =>
      walletEngine == WalletEngine.local &&
      transport != TransportKind.online &&
      envelope != null &&
      (status == TransferStatus.sentOffline ||
          status == TransferStatus.receivedPendingBroadcast);
  bool get usesVoucherSettlement =>
      walletEngine == WalletEngine.local &&
      transport != TransportKind.online &&
      envelope == null;
  bool get isVisibleInPendingQueue => status != TransferStatus.confirmed;

  PendingTransfer copyWith({
    TransferStatus? status,
    DateTime? updatedAt,
    String? transactionSignature,
    String? explorerUrl,
    String? lastError,
    bool clearLastError = false,
    DateTime? confirmedAt,
    String? remoteEndpoint,
    String? bitgoWalletId,
    String? bitgoTransferId,
    String? backendStatus,
    String? fileverseReceiptId,
    String? fileverseReceiptUrl,
    DateTime? fileverseSavedAt,
    String? fileverseStorageMode,
    String? fileverseMessage,
  }) {
    return PendingTransfer(
      transferId: transferId,
      chain: chain,
      network: network,
      walletEngine: walletEngine,
      direction: direction,
      status: status ?? this.status,
      amountLamports: amountLamports,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      transport: transport,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assetId: assetId,
      assetSymbol: assetSymbol,
      assetDisplayName: assetDisplayName,
      assetDecimals: assetDecimals,
      assetContractAddress: assetContractAddress,
      isNativeAsset: isNativeAsset,
      envelope: envelope,
      remoteEndpoint: remoteEndpoint ?? this.remoteEndpoint,
      transactionSignature: transactionSignature ?? this.transactionSignature,
      explorerUrl: explorerUrl ?? this.explorerUrl,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      bitgoWalletId: bitgoWalletId ?? this.bitgoWalletId,
      bitgoTransferId: bitgoTransferId ?? this.bitgoTransferId,
      backendStatus: backendStatus ?? this.backendStatus,
      fileverseReceiptId: fileverseReceiptId ?? this.fileverseReceiptId,
      fileverseReceiptUrl: fileverseReceiptUrl ?? this.fileverseReceiptUrl,
      fileverseSavedAt: fileverseSavedAt ?? this.fileverseSavedAt,
      fileverseStorageMode: fileverseStorageMode ?? this.fileverseStorageMode,
      fileverseMessage: fileverseMessage ?? this.fileverseMessage,
    );
  }

  Map<String, Object?> toDbMap() => <String, Object?>{
    'transfer_id': transferId,
    'chain': chain.name,
    'network': network.name,
    'wallet_engine': walletEngine.name,
    'direction': direction.name,
    'status': status.name,
    'amount_lamports': amountLamports,
    'sender_address': senderAddress,
    'receiver_address': receiverAddress,
    'transport_hint': transport.name,
    'created_at_ms': createdAt.millisecondsSinceEpoch,
    'updated_at_ms': updatedAt.millisecondsSinceEpoch,
    'asset_id': assetId,
    'asset_symbol': assetSymbol,
    'asset_display_name': assetDisplayName,
    'asset_decimals': assetDecimals,
    'asset_contract_address': assetContractAddress,
    'asset_is_native': isNativeAsset ? 1 : 0,
    'envelope_json': envelope == null ? '' : jsonEncode(envelope!.toJson()),
    'remote_endpoint': remoteEndpoint,
    'tx_signature': transactionSignature,
    'explorer_url': explorerUrl,
    'last_error': lastError,
    'confirmed_at_ms': confirmedAt?.millisecondsSinceEpoch,
    'bitgo_wallet_id': bitgoWalletId,
    'bitgo_transfer_id': bitgoTransferId,
    'backend_status': backendStatus,
    'fileverse_receipt_id': fileverseReceiptId,
    'fileverse_receipt_url': fileverseReceiptUrl,
    'fileverse_saved_at_ms': fileverseSavedAt?.millisecondsSinceEpoch,
    'fileverse_storage_mode': fileverseStorageMode,
    'fileverse_message': fileverseMessage,
  };

  factory PendingTransfer.fromDbMap(Map<String, Object?> map) {
    final WalletEngine walletEngine = WalletEngine.values.byName(
      (map['wallet_engine'] as String?) ?? WalletEngine.local.name,
    );
    final String envelopeJson = (map['envelope_json'] as String?) ?? '';
    final OfflineEnvelope? envelope = envelopeJson.isEmpty
        ? null
        : OfflineEnvelope.fromJson(
            jsonDecode(envelopeJson) as Map<String, dynamic>,
          );
    return PendingTransfer(
      transferId: map['transfer_id']! as String,
      chain: ChainKind.values.byName(
        (map['chain'] as String?) ?? ChainKind.solana.name,
      ),
      network: ChainNetwork.values.byName(
        (map['network'] as String?) ??
            envelope?.network.name ??
            ChainNetwork.testnet.name,
      ),
      walletEngine: walletEngine,
      direction: TransferDirection.values.byName(map['direction']! as String),
      status: TransferStatus.values.byName(map['status']! as String),
      amountLamports: map['amount_lamports']! as int,
      senderAddress: map['sender_address']! as String,
      receiverAddress: map['receiver_address']! as String,
      transport: TransportKind.values.byName(map['transport_hint']! as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at_ms']! as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at_ms']! as int,
      ),
      assetId: (map['asset_id'] as String?) ?? '',
      assetSymbol: (map['asset_symbol'] as String?) ?? '',
      assetDisplayName: (map['asset_display_name'] as String?) ?? '',
      assetDecimals: map['asset_decimals'] as int?,
      assetContractAddress: map['asset_contract_address'] as String?,
      isNativeAsset: ((map['asset_is_native'] as int?) ?? 1) != 0,
      envelope: envelope,
      remoteEndpoint: map['remote_endpoint'] as String?,
      transactionSignature: map['tx_signature'] as String?,
      explorerUrl: map['explorer_url'] as String?,
      lastError: map['last_error'] as String?,
      confirmedAt: map['confirmed_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['confirmed_at_ms']! as int),
      bitgoWalletId: map['bitgo_wallet_id'] as String?,
      bitgoTransferId: map['bitgo_transfer_id'] as String?,
      backendStatus: map['backend_status'] as String?,
      fileverseReceiptId: map['fileverse_receipt_id'] as String?,
      fileverseReceiptUrl: map['fileverse_receipt_url'] as String?,
      fileverseSavedAt: map['fileverse_saved_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['fileverse_saved_at_ms']! as int,
            ),
      fileverseStorageMode: map['fileverse_storage_mode'] as String?,
      fileverseMessage: map['fileverse_message'] as String?,
    );
  }
}

class PendingTransferListItem {
  const PendingTransferListItem({
    required this.transferId,
    required this.amountLabel,
    required this.counterpartyLabel,
    required this.ageLabel,
    required this.status,
    required this.direction,
  });

  final String transferId;
  final String amountLabel;
  final String counterpartyLabel;
  final String ageLabel;
  final TransferStatus status;
  final TransferDirection direction;
}

class TransferTimelineState {
  const TransferTimelineState({
    required this.title,
    required this.caption,
    required this.isComplete,
    required this.isCurrent,
    this.isError = false,
  });

  final String title;
  final String caption;
  final bool isComplete;
  final bool isCurrent;
  final bool isError;
}

class ValidatedTransactionDetails {
  const ValidatedTransactionDetails({
    required this.chain,
    required this.network,
    required this.senderAddress,
    required this.receiverAddress,
    required this.amountLamports,
    required this.transactionSignature,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final String senderAddress;
  final String receiverAddress;
  final int amountLamports;
  final String transactionSignature;
}

class EthereumPreparedContext {
  const EthereumPreparedContext({
    required this.nonce,
    required this.gasPriceWei,
    required this.chainId,
    required this.fetchedAt,
  });

  final int nonce;
  final int gasPriceWei;
  final int chainId;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nonce': nonce,
    'gasPriceWei': gasPriceWei,
    'chainId': chainId,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory EthereumPreparedContext.fromJson(Map<String, dynamic> json) =>
      EthereumPreparedContext(
        nonce: json['nonce'] as int,
        gasPriceWei: json['gasPriceWei'] as int,
        chainId: json['chainId'] as int,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
}

Uint8List _uuidStringToBytes(String value) {
  final String normalized = value.replaceAll('-', '').trim().toLowerCase();
  if (normalized.length != 32) {
    throw const FormatException('Transfer id must be a UUID string.');
  }
  return _hexToBytes(normalized);
}

String _uuidBytesToString(List<int> bytes) {
  if (bytes.length != 16) {
    throw const FormatException('Transfer id bytes must be 16 bytes long.');
  }
  final String normalized = _bytesToHex(bytes);
  return [
    normalized.substring(0, 8),
    normalized.substring(8, 12),
    normalized.substring(12, 16),
    normalized.substring(16, 20),
    normalized.substring(20),
  ].join('-');
}

Uint8List _sessionTokenToBytes(String token) {
  final String normalized = token.trim().toLowerCase();
  if (normalized.length != UltrasonicTransferPacket.sessionTokenLength * 2) {
    throw const FormatException('Session token must be 16 bytes in hex.');
  }
  return _hexToBytes(normalized);
}

String _sessionTokenBytesToString(List<int> bytes) {
  if (bytes.length != UltrasonicTransferPacket.sessionTokenLength) {
    throw const FormatException('Session token bytes must be 16 bytes long.');
  }
  return _bytesToHex(bytes);
}

Uint8List _hexToBytes(String value) {
  final String normalized = value.trim();
  if (normalized.length.isOdd) {
    throw const FormatException('Hex string length must be even.');
  }
  final Uint8List bytes = Uint8List(normalized.length ~/ 2);
  for (int index = 0; index < normalized.length; index += 2) {
    bytes[index ~/ 2] = int.parse(
      normalized.substring(index, index + 2),
      radix: 16,
    );
  }
  return bytes;
}

String _bytesToHex(List<int> bytes) {
  final StringBuffer buffer = StringBuffer();
  for (final int value in bytes) {
    buffer.write(value.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

bool _listEquals(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((Object? item) => (item as String?)?.trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

String _sha256HexFromObject(Object? value) {
  final Uint8List bytes = Uint8List.fromList(
    utf8.encode(_canonicalJsonString(value)),
  );
  return sha256.convert(bytes).toString();
}

String _canonicalJsonString(Object? value) {
  return jsonEncode(_canonicalJsonValue(value));
}

Object? _canonicalJsonValue(Object? value) {
  if (value is Map) {
    final Map<dynamic, dynamic> map = value;
    final List<String> keys = map.keys
        .map<String>((dynamic key) => key.toString())
        .toList(growable: false)
      ..sort();
    return <String, Object?>{
      for (final String key in keys)
        key: _canonicalJsonValue(map[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalJsonValue).toList(growable: false);
  }
  return value;
}

int _scopeCodeForPairCode(ChainKind chain, ChainNetwork network) =>
    switch ((chain, network)) {
      (ChainKind.solana, ChainNetwork.testnet) => 0,
      (ChainKind.solana, ChainNetwork.mainnet) => 1,
      (ChainKind.ethereum, ChainNetwork.testnet) => 2,
      (ChainKind.ethereum, ChainNetwork.mainnet) => 3,
      (ChainKind.base, ChainNetwork.testnet) => 4,
      (ChainKind.base, ChainNetwork.mainnet) => 5,
      (ChainKind.bnb, ChainNetwork.testnet) => 6,
      (ChainKind.bnb, ChainNetwork.mainnet) => 7,
      (ChainKind.polygon, ChainNetwork.testnet) => 8,
      (ChainKind.polygon, ChainNetwork.mainnet) => 9,
    };

(ChainKind, ChainNetwork) _scopeFromPairCode(int code) => switch (code) {
  0 => (ChainKind.solana, ChainNetwork.testnet),
  1 => (ChainKind.solana, ChainNetwork.mainnet),
  2 => (ChainKind.ethereum, ChainNetwork.testnet),
  3 => (ChainKind.ethereum, ChainNetwork.mainnet),
  4 => (ChainKind.base, ChainNetwork.testnet),
  5 => (ChainKind.base, ChainNetwork.mainnet),
  6 => (ChainKind.bnb, ChainNetwork.testnet),
  7 => (ChainKind.bnb, ChainNetwork.mainnet),
  8 => (ChainKind.polygon, ChainNetwork.testnet),
  9 => (ChainKind.polygon, ChainNetwork.mainnet),
  _ => throw const FormatException('Unknown transport network scope.'),
};

DirectTransferQrPayload? _tryParsePlainDirectTransferQr(
  String raw, {
  required ChainKind preferredChain,
  required ChainNetwork preferredNetwork,
}) {
  if (_isValidAddressForDirectQr(raw, preferredChain)) {
    return DirectTransferQrPayload(
      chain: preferredChain,
      network: preferredNetwork,
      address: raw,
      displayAddress: raw,
    );
  }
  if (_looksLikeSupportedAddress(raw)) {
    throw const FormatException(
      'This wallet QR does not match the selected chain. Switch chains and scan again.',
    );
  }
  return null;
}

DirectTransferQrPayload _parseSolanaDirectTransferQr(
  String raw, {
  required ChainNetwork preferredNetwork,
}) {
  final _QrUriParts parts = _splitQrUri(raw);
  String address = parts.target;
  if (address.startsWith('//')) {
    address = address.substring(2);
  }
  address = Uri.decodeComponent(address.trim());
  if (!isValidAddress(address)) {
    throw const FormatException(
      'This QR code does not contain a valid wallet address.',
    );
  }
  return DirectTransferQrPayload(
    chain: ChainKind.solana,
    network: preferredNetwork,
    address: address,
    displayAddress: address,
    amount: _parseQrAmount(parts.query, ChainKind.solana),
    label: _parseQrLabel(parts.query),
  );
}

DirectTransferQrPayload _parseEvmDirectTransferQr(
  String raw, {
  required String scheme,
  required ChainKind preferredChain,
  required ChainNetwork preferredNetwork,
}) {
  final _QrUriParts parts = _splitQrUri(raw);
  String target = parts.target;
  if (target.startsWith('//')) {
    target = target.substring(2);
  }
  if (target.startsWith('pay-')) {
    target = target.substring(4);
  }
  final List<String> targetParts = target.split('@');
  final String address = Uri.decodeComponent(targetParts.first.trim());
  if (!_isValidEvmAddress(address)) {
    throw const FormatException(
      'This QR code does not contain a valid wallet address.',
    );
  }

  final int? chainId = targetParts.length > 1
      ? int.tryParse(targetParts[1].trim())
      : null;
  final (ChainKind, ChainNetwork)? explicitScope = chainId == null
      ? null
      : _evmScopeFromChainId(chainId);
  if (chainId != null && explicitScope == null) {
    throw const FormatException('This QR code is for an unsupported network.');
  }

  final ChainKind chain =
      explicitScope?.$1 ??
      switch (scheme) {
        'base' => ChainKind.base,
        'bnb' || 'bsc' => ChainKind.bnb,
        'polygon' || 'matic' => ChainKind.polygon,
        _ => preferredChain.isEvm ? preferredChain : ChainKind.ethereum,
      };
  final ChainNetwork network = explicitScope?.$2 ?? preferredNetwork;

  return DirectTransferQrPayload(
    chain: chain,
    network: network,
    address: address,
    displayAddress: EthereumAddress.fromHex(address).hexEip55,
    amount: _parseQrAmount(parts.query, chain),
    label: _parseQrLabel(parts.query),
  );
}

class _QrUriParts {
  const _QrUriParts({required this.target, required this.query});

  final String target;
  final Map<String, String> query;
}

_QrUriParts _splitQrUri(String raw) {
  final int separator = raw.indexOf(':');
  final String remainder = separator == -1 ? raw : raw.substring(separator + 1);
  final int queryStart = remainder.indexOf('?');
  final String target = queryStart == -1
      ? remainder
      : remainder.substring(0, queryStart);
  final String queryString = queryStart == -1
      ? ''
      : remainder.substring(queryStart + 1);
  Map<String, String> query = const <String, String>{};
  if (queryString.isNotEmpty) {
    try {
      query = Uri.splitQueryString(queryString);
    } catch (_) {
      query = const <String, String>{};
    }
  }
  return _QrUriParts(target: target, query: query);
}

bool _looksLikeSupportedAddress(String value) {
  final String normalized = value.trim();
  return isValidAddress(normalized) || _isValidEvmAddress(normalized);
}

bool _isValidAddressForDirectQr(String value, ChainKind chain) {
  final String normalized = value.trim();
  return chain == ChainKind.solana
      ? isValidAddress(normalized)
      : _isValidEvmAddress(normalized);
}

bool _isValidEvmAddress(String value) {
  final String normalized = value.trim();
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

(ChainKind, ChainNetwork)? _evmScopeFromChainId(int chainId) => switch (chainId) {
  1 => (ChainKind.ethereum, ChainNetwork.mainnet),
  11155111 => (ChainKind.ethereum, ChainNetwork.testnet),
  8453 => (ChainKind.base, ChainNetwork.mainnet),
  84532 => (ChainKind.base, ChainNetwork.testnet),
  56 => (ChainKind.bnb, ChainNetwork.mainnet),
  97 => (ChainKind.bnb, ChainNetwork.testnet),
  137 => (ChainKind.polygon, ChainNetwork.mainnet),
  80002 => (ChainKind.polygon, ChainNetwork.testnet),
  _ => null,
};

(ChainKind, ChainNetwork)? _scopeFromDappChainId(int? chainId) {
  if (chainId == null) {
    return null;
  }
  return _evmScopeFromChainId(chainId);
}

bool _looksLikeHexPayload(String value) {
  final String normalized = value.trim();
  return normalized.startsWith('0x') &&
      normalized.length >= 2 &&
      RegExp(r'^0x[a-fA-F0-9]+$').hasMatch(normalized) &&
      normalized.length.isEven;
}

String _decodeDappMessage(String value) {
  final String normalized = value.trim();
  if (!_looksLikeHexPayload(normalized)) {
    return normalized;
  }
  try {
    final Uint8List bytes = _hexToBytes(normalized.substring(2));
    final String decoded = utf8.decode(bytes, allowMalformed: true).trim();
    return decoded.isEmpty ? normalized : decoded;
  } catch (_) {
    return normalized;
  }
}

int _parseFlexibleHexInt(String value) {
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 0;
  }
  if (normalized.startsWith('0x')) {
    return int.tryParse(normalized.substring(2), radix: 16) ?? 0;
  }
  return int.tryParse(normalized) ?? 0;
}

double? _parseQrAmount(Map<String, String> query, ChainKind chain) {
  final String? amountText = query['amount']?.trim();
  if (amountText != null && amountText.isNotEmpty) {
    final double? parsed = double.tryParse(amountText);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  final String? valueText = query['value']?.trim();
  if (valueText != null && valueText.isNotEmpty) {
    final int? parsed = int.tryParse(valueText);
    if (parsed != null && parsed > 0) {
      return chain.amountFromBaseUnits(parsed);
    }
  }
  return null;
}

String? _parseQrLabel(Map<String, String> query) {
  final String value =
      (query['label'] ?? query['message'] ?? query['memo'] ?? '').trim();
  return value.isEmpty ? null : value;
}

class Formatters {
  const Formatters._();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String sol(double amount) {
    return '◎${amount.toStringAsFixed(amount >= 10 ? 1 : 3)}';
  }

  static String asset(double amount, ChainKind chain) {
    final int fractionDigits = amount >= 10 ? 1 : 4;
    final String prefix = switch (chain) {
      ChainKind.solana => '◎',
      ChainKind.ethereum => 'Ξ',
      ChainKind.base => 'Ξ',
      ChainKind.bnb => 'BNB ',
      ChainKind.polygon => 'POL ',
    };
    final double minimumVisibleAmount = 1 / _pow10(fractionDigits);
    final double absoluteAmount = amount.abs();
    if (absoluteAmount > 0 && absoluteAmount < minimumVisibleAmount) {
      final String sign = amount < 0 ? '-' : '';
      return '$sign$prefix<${minimumVisibleAmount.toStringAsFixed(fractionDigits)}';
    }
    return '$prefix${amount.toStringAsFixed(fractionDigits)}';
  }

  static String holding(double amount, AssetPortfolioHolding holding) {
    if (holding.isNative) {
      return asset(amount, holding.chain);
    }
    final int fractionDigits = amount >= 100
        ? 2
        : amount >= 1
        ? 3
        : 4;
    return '${amount.toStringAsFixed(fractionDigits)} ${holding.resolvedSymbol}';
  }

  static String trackedAsset(double amount, TrackedAssetDefinition asset) {
    if (asset.isNative) {
      return Formatters.asset(amount, asset.chain);
    }
    return tokenAmount(amount, asset.symbol);
  }

  static String tokenAmount(double amount, String symbol) {
    final int fractionDigits = amount >= 100
        ? 2
        : amount >= 1
        ? 3
        : 4;
    return '${amount.toStringAsFixed(fractionDigits)} $symbol';
  }

  static String transferAmount(PendingTransfer transfer) {
    if (transfer.isNativeAsset) {
      return asset(transfer.amountSol, transfer.chain);
    }
    return tokenAmount(transfer.amountSol, transfer.resolvedAssetSymbol);
  }

  static String usd(double amount) {
    final bool negative = amount < 0;
    final String fixed = amount.abs().toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String whole = parts.first;
    final StringBuffer grouped = StringBuffer();
    for (int index = 0; index < whole.length; index += 1) {
      final int reversedIndex = whole.length - index;
      grouped.write(whole[index]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        grouped.write(',');
      }
    }
    final String sign = negative ? '-' : '';
    return '$sign\$${grouped.toString()}.${parts.last}';
  }

  static String lamports(int amountLamports) => '$amountLamports lamports';

  static String baseUnits(int amount, ChainKind chain) {
    return '$amount ${chain.baseUnitLabel}';
  }

  static String shortAddress(String address) {
    if (address.length < 10) {
      return address;
    }
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }

  static String dateTime(DateTime value) {
    final String month = _months[value.month - 1];
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$month ${value.day}, $hour:$minute';
  }

  static String relativeAge(DateTime timestamp, DateTime now) {
    final Duration difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }

  static String durationLabel(Duration? duration) {
    if (duration == null) {
      return 'Not prepared';
    }
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s old';
    }
    return '${duration.inMinutes}m old';
  }
}
