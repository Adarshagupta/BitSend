import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

enum ChainKind { solana, ethereum }

enum ChainNetwork { testnet, mainnet }

extension ChainKindX on ChainKind {
  String get label => switch (this) {
        ChainKind.solana => 'Solana',
        ChainKind.ethereum => 'Ethereum',
      };

  String get shortLabel => switch (this) {
        ChainKind.solana => 'SOL',
        ChainKind.ethereum => 'ETH',
      };

  String get networkLabel => switch (this) {
        ChainKind.solana => 'Solana Devnet',
        ChainKind.ethereum => 'Ethereum Sepolia',
      };

  String get networkKey => switch (this) {
        ChainKind.solana => 'solana-devnet',
        ChainKind.ethereum => 'ethereum-sepolia',
      };

  String get rpcLabel => switch (this) {
        ChainKind.solana => 'RPC',
        ChainKind.ethereum => 'RPC',
      };

  String get baseUnitLabel => switch (this) {
        ChainKind.solana => 'lamports',
        ChainKind.ethereum => 'wei',
      };

  String get receiverHint => switch (this) {
        ChainKind.solana => 'Receiver devnet address',
        ChainKind.ethereum => 'Receiver Sepolia address',
      };

  IconData get icon => switch (this) {
        ChainKind.solana => Icons.blur_circular_rounded,
        ChainKind.ethereum => Icons.diamond_rounded,
      };

  int get decimals => switch (this) {
        ChainKind.solana => 9,
        ChainKind.ethereum => 18,
      };

  double get minimumFundingAmount => switch (this) {
        ChainKind.solana => 0.05,
        ChainKind.ethereum => 0.01,
      };

  int get fallbackFeeHeadroomBaseUnits => switch (this) {
        ChainKind.solana => 10000,
        ChainKind.ethereum => 3000000000000000,
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

  double minimumFundingAmountFor(ChainNetwork network) {
    return switch ((this, network)) {
      (ChainKind.solana, ChainNetwork.testnet) => 0.05,
      (ChainKind.solana, ChainNetwork.mainnet) => 0.01,
      (ChainKind.ethereum, ChainNetwork.testnet) => 0.01,
      (ChainKind.ethereum, ChainNetwork.mainnet) => 0.001,
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
    };
  }

  String shortLabelFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'Devnet',
      (ChainKind.solana, ChainNetwork.mainnet) => 'Mainnet',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'Sepolia',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'Mainnet',
    };
  }

  String keyFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'solana-devnet',
      (ChainKind.solana, ChainNetwork.mainnet) => 'solana-mainnet',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'ethereum-sepolia',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'ethereum-mainnet',
    };
  }

  String receiverHintFor(ChainKind chain) {
    return switch ((chain, this)) {
      (ChainKind.solana, ChainNetwork.testnet) => 'Receiver devnet address',
      (ChainKind.solana, ChainNetwork.mainnet) => 'Receiver mainnet address',
      (ChainKind.ethereum, ChainNetwork.testnet) => 'Receiver Sepolia address',
      (ChainKind.ethereum, ChainNetwork.mainnet) => 'Receiver mainnet address',
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

enum TransportKind { hotspot, ble }

extension TransportKindX on TransportKind {
  String get label => switch (this) {
        TransportKind.hotspot => 'Hotspot / Local Wi-Fi',
        TransportKind.ble => 'Bluetooth Low Energy',
      };

  String get shortLabel => switch (this) {
        TransportKind.hotspot => 'Hotspot',
        TransportKind.ble => 'BLE',
      };

  IconData get icon => switch (this) {
        TransportKind.hotspot => Icons.wifi_tethering_rounded,
        TransportKind.ble => Icons.bluetooth_rounded,
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
  const WalletBackupExport({
    required this.fileName,
    required this.filePath,
  });

  final String fileName;
  final String filePath;
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

  factory CachedBlockhash.fromJson(Map<String, dynamic> json) => CachedBlockhash(
        blockhash: json['blockhash'] as String,
        lastValidBlockHeight: json['lastValidBlockHeight'] as int,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
}

class SendDraft {
  const SendDraft({
    this.chain = ChainKind.solana,
    this.network = ChainNetwork.testnet,
    this.transport = TransportKind.hotspot,
    this.receiverAddress = '',
    this.receiverEndpoint = '',
    this.receiverPeripheralId = '',
    this.receiverPeripheralName = '',
    this.amountSol = 0,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final TransportKind transport;
  final String receiverAddress;
  final String receiverEndpoint;
  final String receiverPeripheralId;
  final String receiverPeripheralName;
  final double amountSol;

  bool get hasReceiver => receiverAddress.isNotEmpty && switch (transport) {
        TransportKind.hotspot => receiverEndpoint.isNotEmpty,
        TransportKind.ble => receiverPeripheralId.isNotEmpty,
      };
  bool get hasAmount => amountSol > 0;

  SendDraft copyWith({
    ChainKind? chain,
    ChainNetwork? network,
    TransportKind? transport,
    String? receiverAddress,
    String? receiverEndpoint,
    String? receiverPeripheralId,
    String? receiverPeripheralName,
    double? amountSol,
    bool clearReceiver = false,
  }) {
    return SendDraft(
      chain: chain ?? this.chain,
      network: network ?? this.network,
      transport: transport ?? this.transport,
      receiverAddress:
          clearReceiver ? '' : receiverAddress ?? this.receiverAddress,
      receiverEndpoint:
          clearReceiver ? '' : receiverEndpoint ?? this.receiverEndpoint,
      receiverPeripheralId:
          clearReceiver ? '' : receiverPeripheralId ?? this.receiverPeripheralId,
      receiverPeripheralName:
          clearReceiver
              ? ''
              : receiverPeripheralName ?? this.receiverPeripheralName,
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
  });

  final bool hasInternet;
  final bool hasLocalLink;
  final bool hasDevnet;
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
}

class ReceiverInvitePayload {
  const ReceiverInvitePayload({
    required this.chain,
    required this.network,
    required this.transport,
    required this.address,
    required this.displayAddress,
    this.endpoint,
  });

  static const String type = 'bitsend.receiver';
  static const int currentVersion = 1;

  final ChainKind chain;
  final ChainNetwork network;
  final TransportKind transport;
  final String address;
  final String displayAddress;
  final String? endpoint;

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
      };

  String toQrData() => jsonEncode(toJson());

  factory ReceiverInvitePayload.fromQrData(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('QR code is empty.');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('This QR code is not a Bitsend receiver code.');
    }

    if ((json['type'] as String?) != type) {
      throw const FormatException('This QR code is not a Bitsend receiver code.');
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
      ('solana', _) => (ChainKind.solana, ChainNetwork.testnet),
      ('ethereum', _) => (ChainKind.ethereum, ChainNetwork.testnet),
      (_, 'solana-devnet') => (ChainKind.solana, ChainNetwork.testnet),
      (_, 'solana-mainnet') => (ChainKind.solana, ChainNetwork.mainnet),
      (_, 'ethereum-sepolia') => (ChainKind.ethereum, ChainNetwork.testnet),
      (_, 'ethereum-mainnet') => (ChainKind.ethereum, ChainNetwork.mainnet),
      _ => throw const FormatException('This QR code is for a different network.'),
    };
    if ((json['version'] as int?) != currentVersion) {
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
      throw const FormatException('Receiver address is missing from the QR code.');
    }
    if (transport == TransportKind.hotspot &&
        (endpoint == null || endpoint.isEmpty)) {
      throw const FormatException('Receiver hotspot endpoint is missing from the QR code.');
    }

    return ReceiverInvitePayload(
      chain: scope.$1,
      network: scope.$2,
      transport: transport,
      address: address,
      displayAddress: displayAddress.isEmpty ? address : displayAddress,
      endpoint: endpoint == null || endpoint.isEmpty ? null : endpoint,
    );
  }
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
    final Uint8List bytes =
        Uint8List.fromList(utf8.encode(jsonEncode(_checksumPayload())));
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

  factory OfflineEnvelope.fromJson(Map<String, dynamic> json) => OfflineEnvelope(
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
    required this.direction,
    required this.status,
    required this.amountLamports,
    required this.senderAddress,
    required this.receiverAddress,
    required this.transport,
    required this.createdAt,
    required this.updatedAt,
    required this.envelope,
    this.remoteEndpoint,
    this.transactionSignature,
    this.explorerUrl,
    this.lastError,
    this.confirmedAt,
  });

  final String transferId;
  final ChainKind chain;
  final ChainNetwork network;
  final TransferDirection direction;
  final TransferStatus status;
  final int amountLamports;
  final String senderAddress;
  final String receiverAddress;
  final TransportKind transport;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OfflineEnvelope envelope;
  final String? remoteEndpoint;
  final String? transactionSignature;
  final String? explorerUrl;
  final String? lastError;
  final DateTime? confirmedAt;

  bool get isInbound => direction == TransferDirection.inbound;
  double get amountSol => chain.amountFromBaseUnits(amountLamports);
  String get counterpartyAddress => isInbound ? senderAddress : receiverAddress;
  bool get reservesOfflineFunds =>
      direction == TransferDirection.outbound &&
      switch (status) {
        TransferStatus.sentOffline ||
        TransferStatus.broadcasting ||
        TransferStatus.broadcastSubmitted ||
        TransferStatus.broadcastFailed => true,
        _ => false,
      };
  bool get canBroadcast => switch (status) {
        TransferStatus.sentOffline ||
        TransferStatus.receivedPendingBroadcast ||
        TransferStatus.broadcastFailed => true,
        _ => false,
      };
  bool get canRetryBroadcast => status == TransferStatus.broadcastFailed;
  bool get needsInitialBroadcast =>
      status == TransferStatus.sentOffline ||
      status == TransferStatus.receivedPendingBroadcast;

  PendingTransfer copyWith({
    TransferStatus? status,
    DateTime? updatedAt,
    String? transactionSignature,
    String? explorerUrl,
    String? lastError,
    bool clearLastError = false,
    DateTime? confirmedAt,
    String? remoteEndpoint,
  }) {
    return PendingTransfer(
      transferId: transferId,
      chain: chain,
      network: network,
      direction: direction,
      status: status ?? this.status,
      amountLamports: amountLamports,
      senderAddress: senderAddress,
      receiverAddress: receiverAddress,
      transport: transport,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      envelope: envelope,
      remoteEndpoint: remoteEndpoint ?? this.remoteEndpoint,
      transactionSignature: transactionSignature ?? this.transactionSignature,
      explorerUrl: explorerUrl ?? this.explorerUrl,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  Map<String, Object?> toDbMap() => <String, Object?>{
        'transfer_id': transferId,
        'chain': chain.name,
        'network': network.name,
        'direction': direction.name,
        'status': status.name,
        'amount_lamports': amountLamports,
        'sender_address': senderAddress,
        'receiver_address': receiverAddress,
        'transport_hint': transport.name,
        'created_at_ms': createdAt.millisecondsSinceEpoch,
        'updated_at_ms': updatedAt.millisecondsSinceEpoch,
        'envelope_json': jsonEncode(envelope.toJson()),
        'remote_endpoint': remoteEndpoint,
        'tx_signature': transactionSignature,
        'explorer_url': explorerUrl,
        'last_error': lastError,
        'confirmed_at_ms': confirmedAt?.millisecondsSinceEpoch,
      };

  factory PendingTransfer.fromDbMap(Map<String, Object?> map) {
    final OfflineEnvelope envelope = OfflineEnvelope.fromJson(
      jsonDecode(map['envelope_json']! as String) as Map<String, dynamic>,
    );
    return PendingTransfer(
      transferId: map['transfer_id']! as String,
      chain: ChainKind.values.byName(
        (map['chain'] as String?) ?? ChainKind.solana.name,
      ),
      network: ChainNetwork.values.byName(
        (map['network'] as String?) ?? envelope.network.name,
      ),
      direction: TransferDirection.values.byName(map['direction']! as String),
      status: TransferStatus.values.byName(map['status']! as String),
      amountLamports: map['amount_lamports']! as int,
      senderAddress: map['sender_address']! as String,
      receiverAddress: map['receiver_address']! as String,
      transport: TransportKind.values.byName(map['transport_hint']! as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at_ms']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at_ms']! as int),
      envelope: envelope,
      remoteEndpoint: map['remote_endpoint'] as String?,
      transactionSignature: map['tx_signature'] as String?,
      explorerUrl: map['explorer_url'] as String?,
      lastError: map['last_error'] as String?,
      confirmedAt: map['confirmed_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['confirmed_at_ms']! as int),
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
    };
    return '$prefix${amount.toStringAsFixed(fractionDigits)}';
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
