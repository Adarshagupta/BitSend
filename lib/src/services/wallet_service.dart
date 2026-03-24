import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:solana/solana.dart';
import 'package:wallet/wallet.dart' as hd_wallet;
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import '../models/app_models.dart';

class WalletService {
  WalletService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _walletMnemonicKey = 'wallet_mnemonic';
  static const String _walletModeKey = 'wallet_mode';
  static const String _walletEvmAccountStrategyKey =
      'wallet_evm_account_strategy';
  static const String _offlineWalletVersionKey = 'offline_wallet_version';
  static const String _deviceBoundOfflineWalletVersion = 'device_bound_v1';
  static const String _legacySolanaRpcEndpointKey = 'rpc_endpoint_solana';
  static const String _legacyEthereumRpcEndpointKey = 'rpc_endpoint_ethereum';
  final FlutterSecureStorage _storage;

  Future<WalletProfile?> loadWallet({
    ChainKind chain = ChainKind.solana,
  }) async {
    return loadWalletForSlot(chain: chain, slot: 0);
  }

  Future<WalletProfile?> loadWalletForSlot({
    ChainKind chain = ChainKind.solana,
    int slot = 0,
  }) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }

    final String? modeValue = await _storage.read(key: _walletModeKey);
    final WalletSetupMode mode = modeValue == WalletSetupMode.restored.name
        ? WalletSetupMode.restored
        : WalletSetupMode.created;
    final EvmAccountStrategy evmAccountStrategy =
        await _loadEvmAccountStrategy(mode: mode);
    return _profileFromMnemonic(
      mnemonic,
      mode,
      chain: chain,
      account: accountIndexForSlot(
        chain: chain,
        slot: slot,
        offline: false,
        evmAccountStrategy: evmAccountStrategy,
      ),
    );
  }

  Future<WalletProfile?> loadOfflineWallet({
    ChainKind chain = ChainKind.solana,
  }) async {
    return loadOfflineWalletForSlot(chain: chain, slot: 0);
  }

  Future<WalletProfile?> loadOfflineWalletForSlot({
    ChainKind chain = ChainKind.solana,
    int slot = 0,
  }) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }
    final String? modeValue = await _storage.read(key: _walletModeKey);
    final WalletSetupMode mode = modeValue == WalletSetupMode.restored.name
        ? WalletSetupMode.restored
        : WalletSetupMode.created;
    await _ensureOfflineWalletKey(
      chain: chain,
      slot: slot,
      mnemonic: mnemonic,
    );
    return _loadOfflineProfileFromStoredKey(
      chain: chain,
      slot: slot,
      mode: mode,
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

  Future<WalletProfile> _persistWallet(
    String mnemonic,
    WalletSetupMode mode,
  ) async {
    await _deleteAllOfflineWalletKeys();
    await _storage.write(key: _walletMnemonicKey, value: mnemonic);
    await _storage.write(key: _walletModeKey, value: mode.name);
    await _storage.write(
      key: _walletEvmAccountStrategyKey,
      value: defaultEvmAccountStrategyForMode(mode).name,
    );
    await _storage.write(
      key: _offlineWalletVersionKey,
      value: _deviceBoundOfflineWalletVersion,
    );
    for (final ChainKind chain in ChainKind.values) {
      await _generateAndStoreOfflineWalletKey(chain: chain, slot: 0);
    }
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
      case ChainKind.base:
      case ChainKind.bnb:
      case ChainKind.polygon:
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

  Future<Ed25519HDKeyPair> loadOfflineSigningKeyPair({int slot = 0}) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw const FormatException('Wallet not initialized yet.');
    }
    await _ensureOfflineWalletKey(
      chain: ChainKind.solana,
      slot: slot,
      mnemonic: mnemonic,
    );
    final String? encoded = await _storage.read(
      key: _offlineWalletKey(ChainKind.solana, slot),
    );
    if (encoded == null || encoded.isEmpty) {
      throw const FormatException('Offline wallet is unavailable on this device.');
    }
    return Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: base64Decode(encoded),
    );
  }

  Future<EthPrivateKey> loadEvmSigningCredentials({
    required ChainKind chain,
    int? account,
    bool offline = false,
    int slot = 0,
  }) async {
    if (!chain.isEvm) {
      throw FormatException(
        '${chain.label} does not use EVM signing credentials.',
      );
    }
    if (offline) {
      final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
      if (mnemonic == null || mnemonic.isEmpty) {
        throw const FormatException('Wallet not initialized yet.');
      }
      await _ensureOfflineWalletKey(
        chain: chain,
        slot: slot,
        mnemonic: mnemonic,
      );
      final String? encoded = await _storage.read(
        key: _offlineWalletKey(chain, slot),
      );
      if (encoded == null || encoded.isEmpty) {
        throw const FormatException(
          'Offline wallet is unavailable on this device.',
        );
      }
      return EthPrivateKey.fromHex(encoded);
    }
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw const FormatException('Wallet not initialized yet.');
    }
    final EvmAccountStrategy evmAccountStrategy =
        await _loadEvmAccountStrategy();
    return _ethereumCredentialsFromMnemonic(
      mnemonic,
      account:
          account ??
          accountIndexForSlot(
            chain: chain,
            slot: slot,
            offline: offline,
            evmAccountStrategy: evmAccountStrategy,
          ),
    );
  }

  Future<EthPrivateKey> loadEthereumSigningCredentials({
    int account = 0,
  }) async {
    return loadEvmSigningCredentials(
      chain: ChainKind.ethereum,
      account: account,
    );
  }

  Future<EthPrivateKey> loadEthereumOfflineSigningCredentials() {
    return loadEvmSigningCredentials(
      chain: ChainKind.ethereum,
      offline: true,
    );
  }

  Future<EthPrivateKey> loadBaseSigningCredentials({int? account}) {
    return loadEvmSigningCredentials(chain: ChainKind.base, account: account);
  }

  Future<EthPrivateKey> loadBaseOfflineSigningCredentials() {
    return loadEvmSigningCredentials(chain: ChainKind.base, offline: true);
  }

  Future<void> saveRpcEndpoint(
    String endpoint, {
    ChainKind chain = ChainKind.solana,
    ChainNetwork network = ChainNetwork.testnet,
  }) async {
    await _storage.write(key: _rpcEndpointKey(chain, network), value: endpoint);
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
    return switch (chain) {
      ChainKind.solana => _storage.read(key: _legacySolanaRpcEndpointKey),
      ChainKind.ethereum => _storage.read(key: _legacyEthereumRpcEndpointKey),
      ChainKind.base => null,
      ChainKind.bnb => null,
      ChainKind.polygon => null,
    };
  }

  Future<WalletBackupExport> exportWalletBackup() async {
    final EvmAccountStrategy evmAccountStrategy =
        await _loadEvmAccountStrategy();
    final Map<ChainKind, WalletProfile?> wallets = <ChainKind, WalletProfile?>{
      for (final ChainKind chain in ChainKind.values)
        chain: await loadWallet(chain: chain),
    };
    if (wallets.values.any((WalletProfile? wallet) => wallet == null)) {
      throw const FormatException('Create or restore a wallet first.');
    }
    final List<WalletBackupAccount> mainAccounts = <WalletBackupAccount>[];
    for (final ChainKind chain in ChainKind.values) {
      final WalletProfile wallet = wallets[chain]!;
      mainAccounts.add(
        await _buildBackupAccount(
          chain: chain,
          role: 'main',
          accountIndex: accountIndexForSlot(
            chain: chain,
            slot: 0,
            offline: false,
            evmAccountStrategy: evmAccountStrategy,
          ),
          address: wallet.address,
        ),
      );
    }
    final WalletProfile primaryWallet = wallets[ChainKind.solana]!;
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
      'chains': ChainKind.values
          .map((ChainKind chain) => chain.name)
          .toList(growable: false),
      'exportedAtUtc': now.toIso8601String(),
      'walletMode': primaryWallet.mode.name,
      'evmAccountStrategy': evmAccountStrategy.name,
      'recoveryPhrase': primaryWallet.seedPhrase,
      'accounts': mainAccounts
          .map((WalletBackupAccount account) => account.toJson())
          .toList(growable: false),
      'notes': <String>[
        'This file contains the recovery phrase and the main-wallet private keys.',
        'The offline wallet is device-bound and is not included in this backup.',
        'Store it offline and delete any temporary copies after moving it to safe storage.',
      ],
    });
    await file.writeAsString('$payload\n', flush: true);

    return WalletBackupExport(fileName: fileName, filePath: file.path);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _walletMnemonicKey);
    await _storage.delete(key: _walletModeKey);
    await _storage.delete(key: _walletEvmAccountStrategyKey);
    await _storage.delete(key: _offlineWalletVersionKey);
    await _storage.delete(key: _legacySolanaRpcEndpointKey);
    await _storage.delete(key: _legacyEthereumRpcEndpointKey);
    await _deleteAllOfflineWalletKeys();
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
      case ChainKind.base:
      case ChainKind.bnb:
      case ChainKind.polygon:
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

  EvmAccountStrategy defaultEvmAccountStrategyForMode(WalletSetupMode mode) {
    return mode == WalletSetupMode.restored
        ? EvmAccountStrategy.compatibleUnified
        : EvmAccountStrategy.legacySeparated;
  }

  int accountIndexForSlot({
    required ChainKind chain,
    required int slot,
    required bool offline,
    EvmAccountStrategy evmAccountStrategy =
        EvmAccountStrategy.legacySeparated,
  }) {
    final int normalizedSlot = slot < 0 ? 0 : slot;
    if (chain == ChainKind.solana) {
      final int offset = normalizedSlot * 2;
      return offline ? offset + 1 : offset;
    }

    final int legacyOffset = switch (chain) {
      ChainKind.solana => normalizedSlot * 2,
      ChainKind.ethereum => normalizedSlot * 4,
      ChainKind.base => normalizedSlot * 4 + 2,
      ChainKind.bnb => 1000 + normalizedSlot * 4,
      ChainKind.polygon => 1000 + normalizedSlot * 4 + 2,
    };
    if (offline) {
      return legacyOffset + 1;
    }
    return switch (evmAccountStrategy) {
      EvmAccountStrategy.legacySeparated => legacyOffset,
      EvmAccountStrategy.compatibleUnified => normalizedSlot,
    };
  }

  Future<void> _ensureOfflineWalletKey({
    required ChainKind chain,
    required int slot,
    required String mnemonic,
  }) async {
    final String storageKey = _offlineWalletKey(chain, slot);
    final String? existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) {
      return;
    }
    final String? version = await _storage.read(key: _offlineWalletVersionKey);
    if (version == _deviceBoundOfflineWalletVersion) {
      await _generateAndStoreOfflineWalletKey(chain: chain, slot: slot);
      return;
    }
    await _migrateLegacyOfflineWalletKey(
      chain: chain,
      slot: slot,
      mnemonic: mnemonic,
    );
  }

  Future<void> _generateAndStoreOfflineWalletKey({
    required ChainKind chain,
    required int slot,
  }) async {
    switch (chain) {
      case ChainKind.solana:
        final Ed25519HDKeyPair keyPair = await Ed25519HDKeyPair.random();
        final Ed25519HDKeyPairData keyData = await keyPair.extract();
        try {
          await _storage.write(
            key: _offlineWalletKey(chain, slot),
            value: base64Encode(keyData.bytes),
          );
        } finally {
          keyData.destroy();
        }
        return;
      case ChainKind.ethereum:
      case ChainKind.base:
      case ChainKind.bnb:
      case ChainKind.polygon:
        final EthPrivateKey credentials = EthPrivateKey.createRandom(
          Random.secure(),
        );
        await _storage.write(
          key: _offlineWalletKey(chain, slot),
          value: web3_crypto.bytesToHex(
            credentials.privateKey,
            include0x: true,
          ),
        );
        return;
    }
  }

  Future<void> _migrateLegacyOfflineWalletKey({
    required ChainKind chain,
    required int slot,
    required String mnemonic,
  }) async {
    switch (chain) {
      case ChainKind.solana:
        final Ed25519HDKeyPair keyPair = await Ed25519HDKeyPair.fromMnemonic(
          mnemonic,
          account: accountIndexForSlot(
            chain: chain,
            slot: slot,
            offline: true,
          ),
        );
        final Ed25519HDKeyPairData keyData = await keyPair.extract();
        try {
          await _storage.write(
            key: _offlineWalletKey(chain, slot),
            value: base64Encode(keyData.bytes),
          );
        } finally {
          keyData.destroy();
        }
        return;
      case ChainKind.ethereum:
      case ChainKind.base:
      case ChainKind.bnb:
      case ChainKind.polygon:
        await _storage.write(
          key: _offlineWalletKey(chain, slot),
          value: web3_crypto.bytesToHex(
            _ethereumPrivateKeyBytesFromMnemonic(
              mnemonic,
              account: accountIndexForSlot(
                chain: chain,
                slot: slot,
                offline: true,
              ),
            ),
            include0x: true,
          ),
        );
        return;
    }
  }

  Future<WalletProfile?> _loadOfflineProfileFromStoredKey({
    required ChainKind chain,
    required int slot,
    required WalletSetupMode mode,
  }) async {
    final String? encoded = await _storage.read(key: _offlineWalletKey(chain, slot));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    switch (chain) {
      case ChainKind.solana:
        final Ed25519HDKeyPair keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
          privateKey: base64Decode(encoded),
        );
        return WalletProfile(
          chain: chain,
          address: keyPair.address,
          displayAddress: Formatters.shortAddress(keyPair.address),
          seedPhrase: '',
          mode: mode,
        );
      case ChainKind.ethereum:
      case ChainKind.base:
      case ChainKind.bnb:
      case ChainKind.polygon:
        final EthPrivateKey credentials = EthPrivateKey.fromHex(encoded);
        final EthereumAddress address = await credentials.extractAddress();
        final String addressHex = address.hexEip55;
        return WalletProfile(
          chain: chain,
          address: addressHex,
          displayAddress: Formatters.shortAddress(addressHex),
          seedPhrase: '',
          mode: mode,
        );
    }
  }

  Future<EvmAccountStrategy> _loadEvmAccountStrategy({
    WalletSetupMode? mode,
  }) async {
    final String? stored = await _storage.read(key: _walletEvmAccountStrategyKey);
    if (stored == EvmAccountStrategy.compatibleUnified.name) {
      return EvmAccountStrategy.compatibleUnified;
    }
    if (stored == EvmAccountStrategy.legacySeparated.name) {
      return EvmAccountStrategy.legacySeparated;
    }
    final WalletSetupMode effectiveMode = mode ?? await _loadWalletMode();
    final EvmAccountStrategy fallback = defaultEvmAccountStrategyForMode(
      effectiveMode,
    );
    await _storage.write(
      key: _walletEvmAccountStrategyKey,
      value: fallback.name,
    );
    return fallback;
  }

  Future<WalletSetupMode> _loadWalletMode() async {
    final String? modeValue = await _storage.read(key: _walletModeKey);
    return modeValue == WalletSetupMode.restored.name
        ? WalletSetupMode.restored
        : WalletSetupMode.created;
  }

  Future<void> _deleteAllOfflineWalletKeys() async {
    final Map<String, String> all = await _storage.readAll();
    for (final String key in all.keys) {
      if (key.startsWith('offline_wallet_key_')) {
        await _storage.delete(key: key);
      }
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
    final hd_wallet.ExtendedPrivateKey root =
        hd_wallet.ExtendedPrivateKey.master(seed, hd_wallet.xprv);
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

  Future<Directory?> _tryDirectory(Future<Directory?> Function() loader) async {
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

  String _offlineWalletKey(ChainKind chain, int slot) {
    final int normalizedSlot = slot < 0 ? 0 : slot;
    return 'offline_wallet_key_${chain.name}_$normalizedSlot';
  }
}
