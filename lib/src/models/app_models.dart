import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

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
    required this.address,
    required this.displayAddress,
    required this.seedPhrase,
    required this.mode,
  });

  final String address;
  final String displayAddress;
  final String seedPhrase;
  final WalletSetupMode mode;
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
    this.transport = TransportKind.hotspot,
    this.receiverAddress = '',
    this.receiverEndpoint = '',
    this.receiverPeripheralId = '',
    this.receiverPeripheralName = '',
    this.amountSol = 0,
  });

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
    TransportKind? transport,
    String? receiverAddress,
    String? receiverEndpoint,
    String? receiverPeripheralId,
    String? receiverPeripheralName,
    double? amountSol,
    bool clearReceiver = false,
  }) {
    return SendDraft(
      transport: transport ?? this.transport,
      receiverAddress: clearReceiver ? '' : receiverAddress ?? this.receiverAddress,
      receiverEndpoint: clearReceiver ? '' : receiverEndpoint ?? this.receiverEndpoint,
      receiverPeripheralId:
          clearReceiver ? '' : receiverPeripheralId ?? this.receiverPeripheralId,
      receiverPeripheralName:
          clearReceiver ? '' : receiverPeripheralName ?? this.receiverPeripheralName,
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
  });

  final String id;
  final String label;
  final String subtitle;
  final TransportKind transport;
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
    required this.balanceSol,
    required this.offlineBalanceSol,
    required this.offlineAvailableSol,
    required this.offlineWalletAddress,
    required this.readyForOffline,
    required this.blockhashAge,
    required this.localEndpoint,
  });

  final double balanceSol;
  final double offlineBalanceSol;
  final double offlineAvailableSol;
  final String? offlineWalletAddress;
  final bool readyForOffline;
  final Duration? blockhashAge;
  final String? localEndpoint;
}

class OfflineEnvelope {
  const OfflineEnvelope({
    required this.version,
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
    required String senderAddress,
    required String receiverAddress,
    required int amountLamports,
    required String signedTransactionBase64,
    required TransportKind transportKind,
  }) {
    final OfflineEnvelope unsigned = OfflineEnvelope(
      version: 1,
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
  double get amountSol => amountLamports / 1000000000;
  String get counterpartyAddress => isInbound ? senderAddress : receiverAddress;

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
    required this.senderAddress,
    required this.receiverAddress,
    required this.amountLamports,
    required this.transactionSignature,
  });

  final String senderAddress;
  final String receiverAddress;
  final int amountLamports;
  final String transactionSignature;
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

  static String lamports(int amountLamports) => '$amountLamports lamports';

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
