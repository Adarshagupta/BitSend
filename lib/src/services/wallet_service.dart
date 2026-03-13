import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Future<void> clearAll() async {
    await _storage.delete(key: _walletMnemonicKey);
    await _storage.delete(key: _walletModeKey);
    await _storage.delete(key: _rpcEndpointKey);
  }
}
