import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart' show EthPrivateKey;

import '../models/app_models.dart';

class OfflineVoucherService {
  OfflineVoucherService({
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final Uuid _uuid;
  final DateTime Function() _clock;

  static const String zeroAddress = '0x0000000000000000000000000000000000000000';

  OfflineVoucherEscrowSession issueEscrowSession({
    required ChainKind chain,
    required ChainNetwork network,
    required String senderAddress,
    required String settlementContractAddress,
    String? assetContractAddress,
    required String escrowAmountBaseUnits,
    required String spendableAmountBaseUnits,
    required String gasReserveBaseUnits,
    required DateTime expiresAt,
    DateTime? createdAt,
    String? escrowId,
    String? creationTransactionHash,
  }) {
    final BigInt spendable = _parseBaseUnits(spendableAmountBaseUnits);
    if (spendable <= BigInt.zero) {
      throw const FormatException('Spendable offline amount must be greater than zero.');
    }
    final DateTime issuedAt = (createdAt ?? _clock()).toUtc();
    if (!expiresAt.toUtc().isAfter(issuedAt)) {
      throw const FormatException('Voucher escrow expiry must be after creation.');
    }

    final String normalizedEscrowId =
        escrowId == null || escrowId.trim().isEmpty
        ? _opaqueIdHex('escrow:${_uuid.v4()}:${issuedAt.microsecondsSinceEpoch}')
        : _normalizeBytes32Hex(escrowId);
    final List<BigInt> denominations = _canonicalVoucherDenominations(spendable);
    final List<_DraftVoucher> draftVouchers = <_DraftVoucher>[
      for (int index = 0; index < denominations.length; index += 1)
        _DraftVoucher(
          amount: denominations[index],
          voucherId: _opaqueIdHex('voucher:$normalizedEscrowId:$index'),
          nonce: _opaqueIdHex('nonce:$normalizedEscrowId:$index'),
        ),
    ];
    final List<Uint8List> leaves = draftVouchers
        .map((item) => _voucherLeafHashBytes(
              escrowId: normalizedEscrowId,
              voucherId: item.voucherId,
              amount: item.amount,
              expiryAt: expiresAt.toUtc(),
              nonce: item.nonce,
            ))
        .toList(growable: false);
    final _MerkleTree tree = _MerkleTree.build(leaves);
    final OfflineVoucherEscrowCommitment commitment =
        OfflineVoucherEscrowCommitment(
          version: OfflineVoucherEscrowCommitment.currentVersion,
          escrowId: normalizedEscrowId,
          chain: chain,
          network: network,
          senderAddress: senderAddress.trim(),
          assetId: assetContractAddress == null || assetContractAddress.trim().isEmpty
              ? '${chain.name}:${network.name}:native'
              : '${chain.name}:${network.name}:${assetContractAddress.trim().toLowerCase()}',
          assetContract: assetContractAddress?.trim(),
          amountBaseUnits: escrowAmountBaseUnits.trim(),
          collateralBaseUnits: '0',
          voucherRoot: _hexFromBytes(tree.root),
          voucherCount: draftVouchers.length,
          maxVoucherAmountBaseUnits:
              denominations.reduce((BigInt a, BigInt b) => a > b ? a : b).toString(),
          createdAt: issuedAt,
          expiresAt: expiresAt.toUtc(),
          stateRoot:
              (creationTransactionHash == null || creationTransactionHash.trim().isEmpty)
              ? _opaqueIdHex('pending:${normalizedEscrowId}')
              : creationTransactionHash.trim(),
          settlementContract: settlementContractAddress.trim(),
        );

    final List<OfflineVoucherInventoryEntry> inventory = <OfflineVoucherInventoryEntry>[
      for (int index = 0; index < draftVouchers.length; index += 1)
        OfflineVoucherInventoryEntry(
          escrowId: normalizedEscrowId,
          voucher: OfflineVoucherLeaf(
            version: OfflineVoucherLeaf.currentVersion,
            escrowId: normalizedEscrowId,
            voucherId: draftVouchers[index].voucherId,
            amountBaseUnits: draftVouchers[index].amount.toString(),
            expiryAt: expiresAt.toUtc(),
            nonce: draftVouchers[index].nonce,
          ),
          proofBundle: OfflineVoucherProofBundle(
            version: OfflineVoucherProofBundle.currentVersion,
            escrowId: normalizedEscrowId,
            voucherId: draftVouchers[index].voucherId,
            voucherRoot: commitment.voucherRoot,
            voucherProof: tree.proofFor(index).map(_hexFromBytes).toList(growable: false),
            escrowStateRoot: commitment.stateRoot,
            escrowProof: <String>[commitment.stateRoot],
            finalizedAt: issuedAt,
            proofWindowExpiresAt: expiresAt.toUtc(),
          ),
        ),
    ];

    return OfflineVoucherEscrowSession(
      commitment: commitment,
      settlementContractAddress: settlementContractAddress.trim(),
      assetContractAddress: assetContractAddress?.trim(),
      availableAmountBaseUnits: spendable.toString(),
      gasReserveBaseUnits: gasReserveBaseUnits.trim(),
      inventory: inventory,
      creationTransactionHash: creationTransactionHash?.trim(),
    );
  }

  OfflineVoucherTransferBundle composeTransferBundle({
    required OfflineVoucherEscrowSession session,
    required String transferId,
    required String amountBaseUnits,
    required String receiverAddress,
    required EthPrivateKey signer,
    required TransportKind transportKind,
    DateTime? createdAt,
  }) {
    final BigInt requested = _parseBaseUnits(amountBaseUnits);
    if (requested <= BigInt.zero) {
      throw const FormatException('Transfer amount must be greater than zero.');
    }
    final List<OfflineVoucherInventoryEntry> available = session.inventory
        .where((item) => item.isAvailable)
        .toList(growable: false)
      ..sort(
        (OfflineVoucherInventoryEntry a, OfflineVoucherInventoryEntry b) =>
            _parseBaseUnits(b.voucher.amountBaseUnits).compareTo(
              _parseBaseUnits(a.voucher.amountBaseUnits),
            ),
      );
    BigInt remaining = requested;
    final List<OfflineVoucherPayment> payments = <OfflineVoucherPayment>[];
    for (final OfflineVoucherInventoryEntry entry in available) {
      final BigInt voucherAmount = _parseBaseUnits(entry.voucher.amountBaseUnits);
      if (voucherAmount > remaining) {
        continue;
      }
      final String signature = signVoucherAssignment(
        signer: signer,
        chain: session.commitment.chain,
        network: session.commitment.network,
        settlementContractAddress: session.settlementContractAddress,
        voucher: entry.voucher,
        receiverAddress: receiverAddress,
      );
      payments.add(
        OfflineVoucherPayment.create(
          voucher: entry.voucher,
          proofBundle: entry.proofBundle,
          senderAddress: session.commitment.senderAddress,
          senderSignature: signature,
          transportHint: transportKind.name,
          createdAt: (createdAt ?? _clock()).toUtc(),
        ),
      );
      remaining -= voucherAmount;
      if (remaining == BigInt.zero) {
        break;
      }
    }
    if (remaining != BigInt.zero) {
      throw FormatException(
        'Offline voucher inventory cannot cover ${requested.toString()} base units exactly.',
      );
    }
    return OfflineVoucherTransferBundle.create(
      transferId: transferId,
      chain: session.commitment.chain,
      network: session.commitment.network,
      escrowId: session.commitment.escrowId,
      settlementContractAddress: session.settlementContractAddress,
      senderAddress: session.commitment.senderAddress,
      receiverAddress: receiverAddress.trim(),
      payments: payments,
      totalAmountBaseUnits: requested.toString(),
      createdAt: (createdAt ?? _clock()).toUtc(),
      transportKind: transportKind,
    );
  }

  String signVoucherAssignment({
    required EthPrivateKey signer,
    required ChainKind chain,
    required ChainNetwork network,
    required String settlementContractAddress,
    required OfflineVoucherLeaf voucher,
    required String receiverAddress,
  }) {
    final Uint8List digest = assignmentDigest(
      chain: chain,
      network: network,
      settlementContractAddress: settlementContractAddress,
      voucher: voucher,
      receiverAddress: receiverAddress,
    );
    return web3_crypto.bytesToHex(
      signer.signToUint8List(digest),
      include0x: true,
    );
  }

  Uint8List assignmentDigest({
    required ChainKind chain,
    required ChainNetwork network,
    required String settlementContractAddress,
    required OfflineVoucherLeaf voucher,
    required String receiverAddress,
  }) {
    final Uint8List encoded = Uint8List.fromList(
      <int>[
        ..._encodeAddress(settlementContractAddress),
        ..._encodeUint(BigInt.from(_chainIdFor(chain, network))),
        ..._encodeAddress(receiverAddress),
        ..._voucherLeafHashBytes(
          escrowId: voucher.escrowId,
          voucherId: voucher.voucherId,
          amount: _parseBaseUnits(voucher.amountBaseUnits),
          expiryAt: voucher.expiryAt,
          nonce: voucher.nonce,
        ),
      ],
    );
    return web3_crypto.keccak256(encoded);
  }

  bool verifyTransferBundle(OfflineVoucherTransferBundle bundle) {
    if (!bundle.isChecksumValid || bundle.payments.isEmpty) {
      return false;
    }
    BigInt total = BigInt.zero;
    for (final OfflineVoucherPayment payment in bundle.payments) {
      if (payment.voucher.escrowId != bundle.escrowId) {
        return false;
      }
      final Uint8List leaf = _voucherLeafHashBytes(
        escrowId: payment.voucher.escrowId,
        voucherId: payment.voucher.voucherId,
        amount: _parseBaseUnits(payment.voucher.amountBaseUnits),
        expiryAt: payment.voucher.expiryAt,
        nonce: payment.voucher.nonce,
      );
      if (
        !_verifyMerkleProof(
          leaf: leaf,
          rootHex: payment.proofBundle.voucherRoot,
          proofHex: payment.proofBundle.voucherProof,
        )
      ) {
        return false;
      }
      if (
        !_verifyAssignmentSignature(
          chain: bundle.chain,
          network: bundle.network,
          settlementContractAddress: bundle.settlementContractAddress,
          senderAddress: payment.senderAddress,
          receiverAddress: bundle.receiverAddress,
          voucher: payment.voucher,
          signatureHex: payment.senderSignature,
        )
      ) {
        return false;
      }
      total += _parseBaseUnits(payment.voucher.amountBaseUnits);
    }
    return total == _parseBaseUnits(bundle.totalAmountBaseUnits);
  }

  List<OfflineVoucherInventoryEntry> reserveBundleEntries({
    required OfflineVoucherEscrowSession session,
    required OfflineVoucherTransferBundle bundle,
  }) {
    final Set<String> voucherIds = bundle.payments
        .map((payment) => payment.voucher.voucherId)
        .toSet();
    return session.inventory
        .map((entry) {
          if (!voucherIds.contains(entry.voucher.voucherId)) {
            return entry;
          }
          return OfflineVoucherInventoryEntry(
            escrowId: entry.escrowId,
            voucher: entry.voucher,
            proofBundle: entry.proofBundle,
            reservedForTransferId: bundle.transferId,
            claimedAt: entry.claimedAt,
          );
        })
        .toList(growable: false);
  }

  List<OfflineVoucherInventoryEntry> markClaimed({
    required OfflineVoucherEscrowSession session,
    required List<String> voucherIds,
    DateTime? claimedAt,
  }) {
    final Set<String> ids = voucherIds.toSet();
    final DateTime resolvedAt = (claimedAt ?? _clock()).toUtc();
    return session.inventory
        .map((entry) {
          if (!ids.contains(entry.voucher.voucherId)) {
            return entry;
          }
          return OfflineVoucherInventoryEntry(
            escrowId: entry.escrowId,
            voucher: entry.voucher,
            proofBundle: entry.proofBundle,
            reservedForTransferId: entry.reservedForTransferId,
            claimedAt: resolvedAt,
          );
        })
        .toList(growable: false);
  }

  String hashVoucherLeafHex(OfflineVoucherLeaf voucher) {
    return _hexFromBytes(
      _voucherLeafHashBytes(
        escrowId: voucher.escrowId,
        voucherId: voucher.voucherId,
        amount: _parseBaseUnits(voucher.amountBaseUnits),
        expiryAt: voucher.expiryAt,
        nonce: voucher.nonce,
      ),
    );
  }

  Uint8List _voucherLeafHashBytes({
    required String escrowId,
    required String voucherId,
    required BigInt amount,
    required DateTime expiryAt,
    required String nonce,
  }) {
    final Uint8List encoded = Uint8List.fromList(
      <int>[
        ..._encodeBytes32(escrowId),
        ..._encodeBytes32(voucherId),
        ..._encodeUint(amount),
        ..._encodeUint(BigInt.from(expiryAt.toUtc().millisecondsSinceEpoch ~/ 1000)),
        ..._encodeBytes32(nonce),
      ],
    );
    return web3_crypto.keccak256(encoded);
  }

  bool _verifyAssignmentSignature({
    required ChainKind chain,
    required ChainNetwork network,
    required String settlementContractAddress,
    required String senderAddress,
    required String receiverAddress,
    required OfflineVoucherLeaf voucher,
    required String signatureHex,
  }) {
    try {
      final Uint8List digest = assignmentDigest(
        chain: chain,
        network: network,
        settlementContractAddress: settlementContractAddress,
        voucher: voucher,
        receiverAddress: receiverAddress,
      );
      final Uint8List signatureBytes = web3_crypto.hexToBytes(signatureHex);
      if (signatureBytes.length != 65) {
        return false;
      }
      final BigInt r = _unsignedBytesToBigInt(signatureBytes.sublist(0, 32));
      final BigInt s = _unsignedBytesToBigInt(signatureBytes.sublist(32, 64));
      int recovery = signatureBytes[64];
      if (recovery >= 27) {
        recovery -= 27;
      }
      if (recovery < 0 || recovery > 1) {
        return false;
      }
      final Uint8List publicKey = web3_crypto.ecRecover(
        digest,
        web3_crypto.MsgSignature(r, s, recovery),
      );
      final Uint8List senderBytes = web3_crypto.publicKeyToAddress(publicKey);
      final String recovered = web3_crypto.bytesToHex(
        senderBytes,
        include0x: true,
      );
      return recovered.toLowerCase() == senderAddress.trim().toLowerCase();
    } catch (_) {
      return false;
    }
  }

  bool _verifyMerkleProof({
    required Uint8List leaf,
    required String rootHex,
    required List<String> proofHex,
  }) {
    Uint8List computed = Uint8List.fromList(leaf);
    for (final String item in proofHex) {
      final Uint8List sibling = web3_crypto.hexToBytes(item);
      computed = _hashSortedPair(computed, sibling);
    }
    return _hexFromBytes(computed).toLowerCase() == rootHex.trim().toLowerCase();
  }

  List<BigInt> _canonicalVoucherDenominations(BigInt total) {
    final List<BigInt> values = <BigInt>[];
    BigInt issuedSoFar = BigInt.zero;
    BigInt next = BigInt.one;
    while (issuedSoFar < total) {
      final BigInt remaining = total - issuedSoFar;
      final BigInt value = next <= remaining ? next : remaining;
      values.add(value);
      issuedSoFar += value;
      next = value << 1;
    }
    return values;
  }

  String _opaqueIdHex(String seed) {
    return _hexFromBytes(
      web3_crypto.keccak256(Uint8List.fromList(utf8.encode(seed))),
    );
  }

  String _normalizeBytes32Hex(String value) {
    final Uint8List bytes = web3_crypto.hexToBytes(value);
    if (bytes.length != 32) {
      throw const FormatException('Expected a 32-byte hex identifier.');
    }
    return _hexFromBytes(bytes);
  }

  int _chainIdFor(ChainKind chain, ChainNetwork network) {
    return switch ((chain, network)) {
      (ChainKind.ethereum, ChainNetwork.testnet) => 11155111,
      (ChainKind.ethereum, ChainNetwork.mainnet) => 1,
      (ChainKind.base, ChainNetwork.testnet) => 84532,
      (ChainKind.base, ChainNetwork.mainnet) => 8453,
      _ => throw const FormatException('Offline vouchers are only available on EVM chains.'),
    };
  }

  Uint8List _encodeBytes32(String hexValue) {
    final Uint8List bytes = web3_crypto.hexToBytes(hexValue);
    if (bytes.length != 32) {
      throw const FormatException('Expected a 32-byte hex value.');
    }
    return bytes;
  }

  Uint8List _encodeAddress(String address) {
    final Uint8List bytes = web3_crypto.hexToBytes(address);
    if (bytes.length != 20) {
      throw const FormatException('Expected a 20-byte address.');
    }
    return Uint8List.fromList(
      <int>[...List<int>.filled(12, 0), ...bytes],
    );
  }

  Uint8List _encodeUint(BigInt value) {
    if (value < BigInt.zero) {
      throw const FormatException('Unsigned integer cannot be negative.');
    }
    final Uint8List output = Uint8List(32);
    BigInt cursor = value;
    for (int index = 31; index >= 0 && cursor > BigInt.zero; index -= 1) {
      output[index] = (cursor & BigInt.from(0xff)).toInt();
      cursor = cursor >> 8;
    }
    return output;
  }

  BigInt _parseBaseUnits(String value) {
    return BigInt.parse(value.trim());
  }

  BigInt _unsignedBytesToBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (final int byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  Uint8List _hashSortedPair(Uint8List left, Uint8List right) {
    final int comparison = _compareBytes(left, right);
    final Uint8List first = comparison <= 0 ? left : right;
    final Uint8List second = comparison <= 0 ? right : left;
    return Uint8List.fromList(
      web3_crypto.keccak256(Uint8List.fromList(<int>[...first, ...second])),
    );
  }

  int _compareBytes(Uint8List left, Uint8List right) {
    final int length = left.length < right.length ? left.length : right.length;
    for (int index = 0; index < length; index += 1) {
      if (left[index] != right[index]) {
        return left[index] - right[index];
      }
    }
    return left.length - right.length;
  }

  String _hexFromBytes(Uint8List bytes) {
    return web3_crypto.bytesToHex(bytes, include0x: true);
  }
}

class _DraftVoucher {
  const _DraftVoucher({
    required this.amount,
    required this.voucherId,
    required this.nonce,
  });

  final BigInt amount;
  final String voucherId;
  final String nonce;
}

class _MerkleTree {
  const _MerkleTree._({
    required this.root,
    required List<List<Uint8List>> levels,
  }) : _levels = levels;

  final Uint8List root;
  final List<List<Uint8List>> _levels;

  factory _MerkleTree.build(List<Uint8List> leaves) {
    if (leaves.isEmpty) {
      throw const FormatException('At least one voucher leaf is required.');
    }
    final OfflineVoucherService helper = OfflineVoucherService();
    final List<List<Uint8List>> levels = <List<Uint8List>>[
      leaves.map((leaf) => Uint8List.fromList(leaf)).toList(growable: false),
    ];
    while (levels.last.length > 1) {
      final List<Uint8List> current = levels.last;
      final List<Uint8List> next = <Uint8List>[];
      for (int index = 0; index < current.length; index += 2) {
        final Uint8List left = current[index];
        final Uint8List right = index + 1 < current.length
            ? current[index + 1]
            : current[index];
        next.add(helper._hashSortedPair(left, right));
      }
      levels.add(next);
    }
    return _MerkleTree._(root: levels.last.single, levels: levels);
  }

  List<Uint8List> proofFor(int index) {
    final List<Uint8List> proof = <Uint8List>[];
    int cursor = index;
    for (int levelIndex = 0; levelIndex < _levels.length - 1; levelIndex += 1) {
      final List<Uint8List> level = _levels[levelIndex];
      final int siblingIndex = cursor.isEven ? cursor + 1 : cursor - 1;
      proof.add(
        Uint8List.fromList(
          siblingIndex < level.length ? level[siblingIndex] : level[cursor],
        ),
      );
      cursor = cursor ~/ 2;
    }
    return proof;
  }
}
