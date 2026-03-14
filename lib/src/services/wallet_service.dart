import 'dart:convert';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:solana/solana.dart';

import '../models/app_models.dart';

class WalletService {
  WalletService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _walletMnemonicKey = 'wallet_mnemonic';
  static const String _walletModeKey = 'wallet_mode';
  static const String _rpcEndpointKey = 'rpc_endpoint';

  final FlutterSecureStorage _storage;

  Future<WalletProfile?> loadWallet() async {
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
      account: 0,
    );
  }

  Future<WalletProfile?> loadOfflineWallet() async {
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
      account: 0,
    );
  }

  Future<WalletProfile> _profileFromMnemonic(
    String mnemonic,
    WalletSetupMode mode, {
    required int account,
  }) async {
    final Ed25519HDKeyPair keyPair = await Ed25519HDKeyPair.fromMnemonic(
      mnemonic,
      account: account,
    );
    return WalletProfile(
      address: keyPair.address,
      displayAddress: Formatters.shortAddress(keyPair.address),
      seedPhrase: mnemonic,
      mode: mode,
    );
  }

  Future<Ed25519HDKeyPair> loadSigningKeyPair({int account = 0}) async {
    final String? mnemonic = await _storage.read(key: _walletMnemonicKey);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw const FormatException('Wallet not initialized yet.');
    }
    return Ed25519HDKeyPair.fromMnemonic(mnemonic, account: account);
  }

  Future<Ed25519HDKeyPair> loadOfflineSigningKeyPair() => loadSigningKeyPair(account: 1);

  Future<void> saveRpcEndpoint(String endpoint) async {
    await _storage.write(key: _rpcEndpointKey, value: endpoint);
  }

  Future<String?> loadRpcEndpoint() => _storage.read(key: _rpcEndpointKey);

  Future<WalletBackupExport> exportWalletBackup() async {
    final WalletProfile? wallet = await loadWallet();
    final WalletProfile? offlineWallet = await loadOfflineWallet();
    if (wallet == null || offlineWallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }

    final WalletBackupAccount mainAccount = await _buildBackupAccount(
      role: 'main',
      accountIndex: 0,
      address: wallet.address,
    );
    final WalletBackupAccount offlineAccount = await _buildBackupAccount(
      role: 'offline',
      accountIndex: 1,
      address: offlineWallet.address,
    );

    final DateTime now = DateTime.now().toUtc();
    final String fileName = 'bitsend-solana-backup-${_timestamp(now)}.json';
    final Directory baseDirectory = await _resolveBackupDirectory();
    final Directory backupDirectory = Directory(
      path.join(baseDirectory.path, 'bitsend_backups'),
    );
    await backupDirectory.create(recursive: true);

    final File file = File(path.join(backupDirectory.path, fileName));
    final JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    final String payload = encoder.convert(<String, dynamic>{
      'version': 1,
      'network': 'solana-devnet',
      'exportedAtUtc': now.toIso8601String(),
      'walletMode': wallet.mode.name,
      'recoveryPhrase': wallet.seedPhrase,
      'accounts': <Map<String, dynamic>>[
        mainAccount.toJson(),
        offlineAccount.toJson(),
      ],
      'notes': <String>[
        'This file contains the recovery phrase and both derived private keys.',
        'Store it offline and delete any temporary copies after moving it to safe storage.',
      ],
    });
    await file.writeAsString('$payload\n', flush: true);

    return WalletBackupExport(fileName: fileName, filePath: file.path);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _walletMnemonicKey);
    await _storage.delete(key: _walletModeKey);
    await _storage.delete(key: _rpcEndpointKey);
  }

  Future<WalletBackupAccount> _buildBackupAccount({
    required String role,
    required int accountIndex,
    required String address,
  }) async {
    final Ed25519HDKeyPair keyPair = await loadSigningKeyPair(
      account: accountIndex,
    );
    final Ed25519HDKeyPairData keyData = await keyPair.extract();
    try {
      return WalletBackupAccount(
        role: role,
        accountIndex: accountIndex,
        derivationPath: "m/44'/501'/$accountIndex'",
        address: address,
        privateKeyBase64: base64Encode(keyData.bytes),
      );
    } finally {
      keyData.destroy();
    }
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
}
