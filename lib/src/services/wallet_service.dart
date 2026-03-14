import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:solana/solana.dart';
import 'package:wallet/wallet.dart' as hd_wallet;
import 'package:web3dart/web3dart.dart';

import '../models/app_models.dart';

class WalletService {
  WalletService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _walletMnemonicKey = 'wallet_mnemonic';
  static const String _walletModeKey = 'wallet_mode';
  static const String _legacySolanaRpcEndpointKey = 'rpc_endpoint_solana';
  static const String _legacyEthereumRpcEndpointKey = 'rpc_endpoint_ethereum';

  final FlutterSecureStorage _storage;

  Future<WalletProfile?> loadWallet({
    ChainKind chain = ChainKind.solana,
  }) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }

    final String? modeValue = await _storage.read(key: _walletModeKey);
    final WalletSetupMode mode =
        modeValue == WalletSetupMode.restored.name ? WalletSetupMode.restored : WalletSetupMode.created;
    return _profileFromMnemonic(
      mnemonic,
      mode,
      chain: chain,
      account: 0,
    );
  }

  Future<WalletProfile?> loadOfflineWallet({
    ChainKind chain = ChainKind.solana,
  }) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }
    final String? modeValue = await _storage.read(key: _walletModeKey);
    final WalletSetupMode mode =
        modeValue == WalletSetupMode.restored.name ? WalletSetupMode.restored : WalletSetupMode.created;
    return _profileFromMnemonic(
      mnemonic,
      mode,
      chain: chain,
      account: 1,
    );
  }

  Future<WalletProfile> createWallet() async {
    final String mnemonic = bip39.generateMnemonic();
    return _persistWallet(mnemonic, WalletSetupMode.created);
  }

  Future<WalletProfile> restoreWallet(String mnemonic) async {
    final String normalized = mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('The recovery phrase is not valid.');
    }
    return _persistWallet(normalized, WalletSetupMode.restored);
  }

  Future<WalletProfile> _persistWallet(String mnemonic, WalletSetupMode mode) async {
    await _storage.write(key: _walletMnemonicKey, value: mnemonic);
    await _storage.write(key: _walletModeKey, value: mode.name);
    return _profileFromMnemonic(
      mnemonic,
      mode,
      chain: ChainKind.solana,
      account: 0,
    );
  }

  Future<WalletProfile> _profileFromMnemonic(
    String mnemonic,
    WalletSetupMode mode, {
    required ChainKind chain,
    required int account,
  }) async {
    switch (chain) {
      case ChainKind.solana:
        final Ed25519HDKeyPair keyPair = await Ed25519HDKeyPair.fromMnemonic(
          mnemonic,
          account: account,
        );
        return WalletProfile(
          chain: chain,
          address: keyPair.address,
          displayAddress: Formatters.shortAddress(keyPair.address),
          seedPhrase: mnemonic,
          mode: mode,
        );
      case ChainKind.ethereum:
        final EthPrivateKey credentials = _ethereumCredentialsFromMnemonic(
          mnemonic,
          account: account,
        );
        final EthereumAddress address = await credentials.extractAddress();
        final String addressHex = address.hexEip55;
        return WalletProfile(
          chain: chain,
          address: addressHex,
          displayAddress: Formatters.shortAddress(addressHex),
          seedPhrase: mnemonic,
          mode: mode,
        );
    }
  }

  Future<Ed25519HDKeyPair> loadSigningKeyPair({int account = 0}) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw const FormatException('Wallet not initialized yet.');
    }
    return Ed25519HDKeyPair.fromMnemonic(mnemonic, account: account);
  }

  Future<Ed25519HDKeyPair> loadOfflineSigningKeyPair() => loadSigningKeyPair(account: 1);

  Future<EthPrivateKey> loadEthereumSigningCredentials({int account = 0}) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw const FormatException('Wallet not initialized yet.');
    }
    return _ethereumCredentialsFromMnemonic(mnemonic, account: account);
  }

  Future<EthPrivateKey> loadEthereumOfflineSigningCredentials() {
    return loadEthereumSigningCredentials(account: 1);
  }

  Future<void> saveRpcEndpoint(
    String endpoint, {
    ChainKind chain = ChainKind.solana,
    ChainNetwork network = ChainNetwork.testnet,
  }) async {
    await _storage.write(
      key: _rpcEndpointKey(chain, network),
      value: endpoint,
    );
  }

  Future<String?> loadRpcEndpoint({
    ChainKind chain = ChainKind.solana,
    ChainNetwork network = ChainNetwork.testnet,
  }) async {
    final String? scoped = await _storage.read(
      key: _rpcEndpointKey(chain, network),
    );
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }
    if (network != ChainNetwork.testnet) {
      return null;
    }
    return _storage.read(
      key: chain == ChainKind.solana
          ? _legacySolanaRpcEndpointKey
          : _legacyEthereumRpcEndpointKey,
    );
  }

  Future<WalletBackupExport> exportWalletBackup() async {
    final WalletProfile? solanaWallet = await loadWallet(
      chain: ChainKind.solana,
    );
    final WalletProfile? solanaOfflineWallet = await loadOfflineWallet(
      chain: ChainKind.solana,
    );
    final WalletProfile? ethereumWallet = await loadWallet(
      chain: ChainKind.ethereum,
    );
    final WalletProfile? ethereumOfflineWallet = await loadOfflineWallet(
      chain: ChainKind.ethereum,
    );
    if (solanaWallet == null ||
        solanaOfflineWallet == null ||
        ethereumWallet == null ||
        ethereumOfflineWallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }

    final WalletBackupAccount solanaMainAccount = await _buildBackupAccount(
      chain: ChainKind.solana,
      role: 'main',
      accountIndex: 0,
      address: solanaWallet.address,
    );
    final WalletBackupAccount solanaOfflineAccount = await _buildBackupAccount(
      chain: ChainKind.solana,
      role: 'offline',
      accountIndex: 1,
      address: solanaOfflineWallet.address,
    );
    final WalletBackupAccount ethereumMainAccount = await _buildBackupAccount(
      chain: ChainKind.ethereum,
      role: 'main',
      accountIndex: 0,
      address: ethereumWallet.address,
    );
    final WalletBackupAccount ethereumOfflineAccount = await _buildBackupAccount(
      chain: ChainKind.ethereum,
      role: 'offline',
      accountIndex: 1,
      address: ethereumOfflineWallet.address,
    );

    final DateTime now = DateTime.now().toUtc();
    final String fileName = 'bitsend-wallet-backup-${_timestamp(now)}.json';
    final Directory baseDirectory = await _resolveBackupDirectory();
    final Directory backupDirectory = Directory(
      path.join(baseDirectory.path, 'bitsend_backups'),
    );
    await backupDirectory.create(recursive: true);

    final File file = File(path.join(backupDirectory.path, fileName));
    final JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    final String payload = encoder.convert(<String, dynamic>{
      'version': 1,
      'chains': <String>[ChainKind.solana.name, ChainKind.ethereum.name],
      'exportedAtUtc': now.toIso8601String(),
      'walletMode': solanaWallet.mode.name,
      'recoveryPhrase': solanaWallet.seedPhrase,
      'accounts': <Map<String, dynamic>>[
        solanaMainAccount.toJson(),
        solanaOfflineAccount.toJson(),
        ethereumMainAccount.toJson(),
        ethereumOfflineAccount.toJson(),
      ],
      'notes': <String>[
        'This file contains the recovery phrase and all derived private keys.',
        'Store it offline and delete any temporary copies after moving it to safe storage.',
      ],
    });
    await file.writeAsString('$payload\n', flush: true);

    return WalletBackupExport(fileName: fileName, filePath: file.path);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _walletMnemonicKey);
    await _storage.delete(key: _walletModeKey);
    await _storage.delete(key: _legacySolanaRpcEndpointKey);
    await _storage.delete(key: _legacyEthereumRpcEndpointKey);
    for (final ChainKind chain in ChainKind.values) {
      for (final ChainNetwork network in ChainNetwork.values) {
        await _storage.delete(key: _rpcEndpointKey(chain, network));
      }
    }
  }

  Future<WalletBackupAccount> _buildBackupAccount({
    required ChainKind chain,
    required String role,
    required int accountIndex,
    required String address,
  }) async {
    switch (chain) {
      case ChainKind.solana:
        final Ed25519HDKeyPair keyPair = await loadSigningKeyPair(
          account: accountIndex,
        );
        final Ed25519HDKeyPairData keyData = await keyPair.extract();
        try {
          return WalletBackupAccount(
            chain: chain,
            role: role,
            accountIndex: accountIndex,
            derivationPath: "m/44'/501'/$accountIndex'",
            address: address,
            privateKeyBase64: base64Encode(keyData.bytes),
          );
        } finally {
          keyData.destroy();
        }
      case ChainKind.ethereum:
        return WalletBackupAccount(
          chain: chain,
          role: role,
          accountIndex: accountIndex,
          derivationPath: "m/44'/60'/0'/0/$accountIndex",
          address: address,
          privateKeyBase64: base64Encode(
            _ethereumPrivateKeyBytesFromMnemonic(
              (await _storage.read(key: _walletMnemonicKey))!,
              account: accountIndex,
            ),
          ),
        );
    }
  }

  EthPrivateKey _ethereumCredentialsFromMnemonic(
    String mnemonic, {
    required int account,
  }) {
    final BigInt privateKey = _ethereumPrivateKeyFromMnemonic(
      mnemonic,
      account: account,
    );
    return EthPrivateKey.fromInt(privateKey);
  }

  BigInt _ethereumPrivateKeyFromMnemonic(
    String mnemonic, {
    required int account,
  }) {
    final List<String> words = mnemonic
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    final Uint8List seed = hd_wallet.mnemonicToSeed(words);
    final hd_wallet.ExtendedPrivateKey root = hd_wallet.ExtendedPrivateKey
        .master(seed, hd_wallet.xprv);
    final hd_wallet.ExtendedKey derived = root.forPath(
      "m/44'/60'/0'/0/$account",
    );
    return (derived as hd_wallet.ExtendedPrivateKey).key;
  }

  Uint8List _ethereumPrivateKeyBytesFromMnemonic(
    String mnemonic, {
    required int account,
  }) {
    final String hex = _ethereumPrivateKeyFromMnemonic(
      mnemonic,
      account: account,
    ).toRadixString(16).padLeft(64, '0');
    final Uint8List bytes = Uint8List(32);
    for (int index = 0; index < 32; index += 1) {
      final int start = index * 2;
      bytes[index] = int.parse(hex.substring(start, start + 2), radix: 16);
    }
    return bytes;
  }

  Future<Directory> _resolveBackupDirectory() async {
    final Directory? downloadsDirectory = await _tryDirectory(
      getDownloadsDirectory,
    );
    if (downloadsDirectory != null) {
      return downloadsDirectory;
    }

    final List<Directory>? externalDownloads = await _tryDirectories(
      () => getExternalStorageDirectories(type: StorageDirectory.downloads),
    );
    if (externalDownloads != null && externalDownloads.isNotEmpty) {
      return externalDownloads.first;
    }

    final Directory? externalStorage = await _tryDirectory(
      getExternalStorageDirectory,
    );
    if (externalStorage != null) {
      return externalStorage;
    }

    return getApplicationDocumentsDirectory();
  }

  Future<Directory?> _tryDirectory(
    Future<Directory?> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<List<Directory>?> _tryDirectories(
    Future<List<Directory>?> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  String _timestamp(DateTime value) {
    final String twoDigitMonth = value.month.toString().padLeft(2, '0');
    final String twoDigitDay = value.day.toString().padLeft(2, '0');
    final String twoDigitHour = value.hour.toString().padLeft(2, '0');
    final String twoDigitMinute = value.minute.toString().padLeft(2, '0');
    final String twoDigitSecond = value.second.toString().padLeft(2, '0');
    return '${value.year}$twoDigitMonth$twoDigitDay'
        '_$twoDigitHour$twoDigitMinute$twoDigitSecond';
  }

  String _rpcEndpointKey(ChainKind chain, ChainNetwork network) {
    return 'rpc_endpoint_${chain.name}_${network.name}';
  }
}
