import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

enum ChainKind { solana, ethereum, base }

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
  bool get isEvm => this == ChainKind.ethereum || this == ChainKind.base;

  String get label => switch (this) {
    ChainKind.solana => 'Solana',
    ChainKind.ethereum => 'Ethereum',
    ChainKind.base => 'Base',
  };

  String get shortLabel => switch (this) {
    ChainKind.solana => 'SOL',
    ChainKind.ethereum => 'ETH',
    ChainKind.base => 'Base ETH',
  };

  String get assetDisplayLabel => switch (this) {
    ChainKind.solana => 'SOL',
    ChainKind.ethereum => 'ETH',
    ChainKind.base => 'Base ETH',
  };

  String get networkLabel => switch (this) {
    ChainKind.solana => 'Solana Devnet',
    ChainKind.ethereum => 'Ethereum Sepolia',
    ChainKind.base => 'Base Sepolia',
  };

  String get networkKey => switch (this) {
    ChainKind.solana => 'solana-devnet',
    ChainKind.ethereum => 'ethereum-sepolia',
    ChainKind.base => 'base-sepolia',
  };

  String get rpcLabel => switch (this) {
    ChainKind.solana => 'RPC',
    ChainKind.ethereum => 'RPC',
    ChainKind.base => 'RPC',
  };

  String get baseUnitLabel => switch (this) {
    ChainKind.solana => 'lamports',
    ChainKind.ethereum => 'wei',
    ChainKind.base => 'wei',
  };

  String get receiverHint => switch (this) {
    ChainKind.solana => 'Receiver devnet address',
    ChainKind.ethereum => 'Receiver Sepolia address',
    ChainKind.base => 'Receiver Base Sepolia address',
  };

  IconData get icon => switch (this) {
    ChainKind.solana => Icons.blur_circular_rounded,
    ChainKind.ethereum => Icons.diamond_rounded,
    ChainKind.base => Icons.layers_rounded,
  };

  int get decimals => switch (this) {
    ChainKind.solana => 9,
    ChainKind.ethereum => 18,
    ChainKind.base => 18,
  };

  double get minimumFundingAmount => switch (this) {
    ChainKind.solana => 0.05,
    ChainKind.ethereum => 0.01,
    ChainKind.base => 0.01,
  };

  int get fallbackFeeHeadroomBaseUnits => switch (this) {
    ChainKind.solana => 10000,
    ChainKind.ethereum => 3000000000000000,
    ChainKind.base => 3000000000000000,
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
        'Bitsend derives a dedicated Ethereum 0x address. Funds stay on ${network.labelFor(this)}.',
      ChainKind.base =>
        'Bitsend derives a dedicated Base 0x address. Funds stay on ${network.labelFor(this)}.',
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

enum TransportKind { hotspot, ble, ultrasonic }

extension TransportKindX on TransportKind {
  String get label => switch (this) {
    TransportKind.hotspot => 'Hotspot / Local Wi-Fi',
    TransportKind.ble => 'Bluetooth Low Energy',
    TransportKind.ultrasonic => 'Ultrasonic',
  };

  String get shortLabel => switch (this) {
    TransportKind.hotspot => 'Hotspot',
    TransportKind.ble => 'BLE',
    TransportKind.ultrasonic => 'Ultrasonic',
  };

  IconData get icon => switch (this) {
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

  static const String type = 'bitsend.receiver';
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
      throw const FormatException(
        'This QR code is not a Bitsend receiver code.',
      );
    }

    if ((json['type'] as String?) != type) {
      throw const FormatException(
        'This QR code is not a Bitsend receiver code.',
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
      ('solana', _) => (ChainKind.solana, ChainNetwork.testnet),
      ('ethereum', _) => (ChainKind.ethereum, ChainNetwork.testnet),
      ('base', _) => (ChainKind.base, ChainNetwork.testnet),
      (_, 'solana-devnet') => (ChainKind.solana, ChainNetwork.testnet),
      (_, 'solana-mainnet') => (ChainKind.solana, ChainNetwork.mainnet),
      (_, 'ethereum-sepolia') => (ChainKind.ethereum, ChainNetwork.testnet),
      (_, 'ethereum-mainnet') => (ChainKind.ethereum, ChainNetwork.mainnet),
      (_, 'base-sepolia') => (ChainKind.base, ChainNetwork.testnet),
      (_, 'base-mainnet') => (ChainKind.base, ChainNetwork.mainnet),
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
  double get amountSol => chain.amountFromBaseUnits(amountLamports);
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
      TransferStatus.broadcastFailed => true,
      _ => false,
    },
    WalletEngine.bitgo => status == TransferStatus.broadcastFailed,
  };
  bool get canRetryBroadcast => status == TransferStatus.broadcastFailed;
  bool get needsInitialBroadcast =>
      walletEngine == WalletEngine.local &&
      (status == TransferStatus.sentOffline ||
          status == TransferStatus.receivedPendingBroadcast);

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
