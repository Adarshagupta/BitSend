import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solana/dto.dart' show ConfirmationStatus, SignatureStatus;
import 'package:solana/solana.dart';
import 'package:uuid/uuid.dart';
import 'package:web3dart/web3dart.dart' show EthPrivateKey, TransactionReceipt;

import '../models/app_models.dart';
import '../services/bitgo_client_service.dart';
import '../services/ble_transport_service.dart';
import '../services/ethereum_service.dart';
import '../services/hotspot_transport_service.dart';
import '../services/local_store.dart';
import '../services/solana_service.dart';
import '../services/transport_contract.dart';
import '../services/wallet_service.dart';

const double minimumFundingSol = 0.05;
const int solFeeHeadroomLamports = 10000;
const Duration blockhashFreshnessWindow = Duration(seconds: 75);
const Duration ethereumContextFreshnessWindow = Duration(minutes: 5);
const Duration realtimeSettlementPollInterval = Duration(seconds: 2);
const int realtimeSettlementPollAttempts = 12;
const String defaultSolanaTestnetRpcEndpoint = 'https://api.devnet.solana.com';
const String defaultSolanaMainnetRpcEndpoint =
    'https://api.mainnet-beta.solana.com';
const String defaultEthereumTestnetRpcEndpoint =
    'https://ethereum-sepolia-rpc.publicnode.com';
const String defaultEthereumMainnetRpcEndpoint =
    'https://ethereum-rpc.publicnode.com';
const String legacyLocalBitGoBackendEndpoint = 'http://127.0.0.1:8788';
const String defaultBitGoBackendEndpoint =
    'https://bitsend-bitgo-backend.blueadarsh1.workers.dev';

class BitsendAppState extends ChangeNotifier {
  BitsendAppState({
    LocalStore? store,
    WalletService? walletService,
    HotspotTransportService? transportService,
    BleTransportService? bleTransportService,
    Connectivity? connectivity,
    NetworkInfo? networkInfo,
    SolanaService? solanaService,
    EthereumService? ethereumService,
    BitGoClientService? bitGoClientService,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _store = store ?? LocalStore(),
       _walletService = walletService ?? WalletService(),
       _hotspotTransportService = transportService ?? HotspotTransportService(),
       _bleTransportService = bleTransportService ?? BleTransportService(),
       _connectivity = connectivity ?? Connectivity(),
       _networkInfo = networkInfo ?? NetworkInfo(),
       _solanaService =
           solanaService ??
           SolanaService(rpcEndpoint: defaultSolanaTestnetRpcEndpoint),
       _ethereumService =
           ethereumService ??
           EthereumService(rpcEndpoint: defaultEthereumTestnetRpcEndpoint),
       _bitGoClientService =
           bitGoClientService ??
           BitGoClientService(endpoint: defaultBitGoBackendEndpoint),
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final WalletService _walletService;
  final HotspotTransportService _hotspotTransportService;
  final BleTransportService _bleTransportService;
  final Connectivity _connectivity;
  final NetworkInfo _networkInfo;
  final SolanaService _solanaService;
  final EthereumService _ethereumService;
  final BitGoClientService _bitGoClientService;
  final Uuid _uuid;
  final DateTime Function() _clock;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _initialized = false;
  bool _initializing = false;
  bool _localPermissionsGranted = false;
  bool _hasInternet = false;
  bool _hasLocalLink = false;
  bool _hasDevnet = false;
  bool _working = false;
  String? _statusMessage;
  String? _announcementMessage;
  String? _localIp;
  ChainKind _activeChain = ChainKind.solana;
  ChainNetwork _activeNetwork = ChainNetwork.testnet;
  WalletEngine _activeWalletEngine = WalletEngine.local;
  WalletProfile? _wallet;
  WalletProfile? _offlineWallet;
  final Map<ChainKind, WalletProfile?> _wallets = <ChainKind, WalletProfile?>{};
  final Map<ChainKind, WalletProfile?> _offlineWallets =
      <ChainKind, WalletProfile?>{};
  final Map<String, WalletEngine> _walletEngines = <String, WalletEngine>{};
  final Map<String, BitGoWalletSummary?> _bitgoWallets =
      <String, BitGoWalletSummary?>{};
  BitGoWalletSummary? _bitgoWallet;
  BitGoBackendMode _bitgoBackendMode = BitGoBackendMode.unknown;
  CachedBlockhash? _cachedBlockhash;
  EthereumPreparedContext? _cachedEthereumContext;
  int _mainBalanceLamports = 0;
  int _offlineBalanceLamports = 0;
  final Map<String, int> _mainBalances = <String, int>{};
  final Map<String, int> _offlineBalances = <String, int>{};
  final Map<String, String> _rpcEndpoints = <String, String>{
    'solana:testnet': defaultSolanaTestnetRpcEndpoint,
    'solana:mainnet': defaultSolanaMainnetRpcEndpoint,
    'ethereum:testnet': defaultEthereumTestnetRpcEndpoint,
    'ethereum:mainnet': defaultEthereumMainnetRpcEndpoint,
  };
  String _rpcEndpoint = defaultSolanaTestnetRpcEndpoint;
  String _bitgoEndpoint = defaultBitGoBackendEndpoint;
  SendDraft _sendDraft = const SendDraft();
  TransportKind _receiveTransport = TransportKind.hotspot;
  String? _lastSentTransferId;
  String? _lastReceivedTransferId;
  List<PendingTransfer> _pendingTransfers = <PendingTransfer>[];
  List<ReceiverDiscoveryItem> _bleReceivers = <ReceiverDiscoveryItem>[];
  bool _bleDiscovering = false;
  bool _realtimeSettlementSyncRunning = false;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get working => _working;
  String? get statusMessage => _statusMessage;
  ChainKind get activeChain => _activeChain;
  ChainNetwork get activeNetwork => _activeNetwork;
  WalletEngine get activeWalletEngine => _activeWalletEngine;
  WalletProfile? get wallet => _wallet;
  WalletProfile? get offlineWallet => _offlineWallet;
  BitGoWalletSummary? get bitgoWallet => _bitgoWallet;
  BitGoBackendMode get bitgoBackendMode => _bitgoBackendMode;
  bool get bitgoBackendIsLive => _bitgoBackendMode.isLive;
  bool get hasWallet => _wallet != null;
  bool get hasOfflineWallet => _offlineWallet != null;
  bool get hasInternet => _hasInternet;
  bool get hasLocalLink => _hasLocalLink;
  bool get hasDevnet => _hasDevnet;
  bool get localPermissionsGranted => _localPermissionsGranted;
  bool get hasOfflineReadyBlockhash => _activeWalletEngine == WalletEngine.bitgo
      ? true
      : _activeChain == ChainKind.solana
      ? _cachedBlockhash != null && !_isCachedBlockhashExpired
      : _cachedEthereumContext != null && !_isCachedEthereumContextExpired;
  bool get hasEnoughFunding =>
      mainBalanceSol >= _activeChain.minimumFundingAmountFor(_activeNetwork);
  bool get hasOfflineFunds => _activeWalletEngine == WalletEngine.bitgo
      ? _mainBalanceLamports > 0
      : offlineSpendableLamports > 0;
  double get mainBalanceSol =>
      _activeChain.amountFromBaseUnits(_mainBalanceLamports);
  double get offlineBalanceSol => _activeWalletEngine == WalletEngine.bitgo
      ? 0
      : _activeChain.amountFromBaseUnits(_offlineBalanceLamports);
  double get offlineSpendableBalanceSol =>
      _activeWalletEngine == WalletEngine.bitgo
      ? 0
      : _activeChain.amountFromBaseUnits(offlineSpendableLamports);
  String get rpcEndpoint => _rpcEndpoint;
  String get bitgoEndpoint => _bitgoEndpoint;
  String? get localIp => _localIp;
  String? get localEndpoint => _localIp == null
      ? null
      : 'http://$_localIp:${HotspotTransportService.port}';
  String? get announcementMessage => _announcementMessage;
  SendDraft get sendDraft => _sendDraft;
  TransportKind get receiveTransport => _receiveTransport;
  List<ReceiverDiscoveryItem> get bleReceivers =>
      List<ReceiverDiscoveryItem>.unmodifiable(_bleReceivers);
  bool get bleDiscovering => _bleDiscovering;
  String? get lastSentTransferId => _lastSentTransferId;
  String? get lastReceivedTransferId => _lastReceivedTransferId;
  bool get listenerRunning =>
      _hotspotTransportService.isListening || _bleTransportService.isListening;
  bool get hotspotListenerRunning => _hotspotTransportService.isListening;
  bool get bleListenerRunning => _bleTransportService.isListening;

  HomeStatus get homeStatus => HomeStatus(
    hasInternet: _hasInternet,
    hasLocalLink: _hasLocalLink,
    hasDevnet: _hasDevnet,
    walletEngine: _activeWalletEngine,
  );

  int get reservedOfflineLamports => _pendingTransfers
      .where((PendingTransfer transfer) {
        return transfer.senderAddress == _offlineWallet?.address &&
            transfer.chain == _activeChain &&
            transfer.network == _activeNetwork &&
            transfer.reservesOfflineFunds;
      })
      .fold<int>(
        0,
        (int total, PendingTransfer transfer) =>
            total + transfer.amountLamports,
      );

  int get offlineSpendableLamports {
    final int remaining = _offlineBalanceLamports - reservedOfflineLamports;
    return remaining < 0 ? 0 : remaining;
  }

  WalletSummary get walletSummary => WalletSummary(
    chain: _activeChain,
    network: _activeNetwork,
    balanceSol: mainBalanceSol,
    offlineBalanceSol: offlineBalanceSol,
    offlineAvailableSol: offlineSpendableBalanceSol,
    offlineWalletAddress: _activeWalletEngine == WalletEngine.local
        ? _offlineWallet?.address
        : null,
    readyForOffline: hasOfflineReadyBlockhash,
    blockhashAge: _activeWalletEngine == WalletEngine.bitgo
        ? null
        : _activeChain == ChainKind.solana
        ? (_cachedBlockhash == null
              ? null
              : _clock().difference(_cachedBlockhash!.fetchedAt))
        : (_cachedEthereumContext == null
              ? null
              : _clock().difference(_cachedEthereumContext!.fetchedAt)),
    localEndpoint: _activeWalletEngine == WalletEngine.local
        ? localEndpoint
        : null,
    walletEngine: _activeWalletEngine,
    primaryAddress: _activeWalletEngine == WalletEngine.bitgo
        ? _bitgoWallet?.address
        : _wallet?.address,
    primaryDisplayLabel: _activeWalletEngine == WalletEngine.bitgo
        ? _bitgoWallet?.displayLabel
        : _wallet?.displayAddress,
    bitgoWallet: _bitgoWallet,
  );

  List<PendingTransfer> get pendingTransfers {
    final List<PendingTransfer> sorted =
        List<PendingTransfer>.from(_pendingTransfers)..sort(
          (PendingTransfer a, PendingTransfer b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
    return sorted;
  }

  PendingTransfer? get lastSentTransfer =>
      _lastSentTransferId == null ? null : transferById(_lastSentTransferId!);

  PendingTransfer? get lastReceivedTransfer => _lastReceivedTransferId == null
      ? null
      : transferById(_lastReceivedTransferId!);

  String get bootRoute {
    if (!hasWallet) {
      return '/onboarding/welcome';
    }
    return '/home';
  }

  String get _activeScopeKey => _scopeKey(_activeChain, _activeNetwork);

  String _scopeKey(ChainKind chain, ChainNetwork network) {
    return '${chain.name}:${network.name}';
  }

  String _defaultRpcEndpointFor(ChainKind chain, ChainNetwork network) {
    return switch ((chain, network)) {
      (ChainKind.solana, ChainNetwork.testnet) =>
        defaultSolanaTestnetRpcEndpoint,
      (ChainKind.solana, ChainNetwork.mainnet) =>
        defaultSolanaMainnetRpcEndpoint,
      (ChainKind.ethereum, ChainNetwork.testnet) =>
        defaultEthereumTestnetRpcEndpoint,
      (ChainKind.ethereum, ChainNetwork.mainnet) =>
        defaultEthereumMainnetRpcEndpoint,
    };
  }

  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    notifyListeners();

    try {
      final String? savedBitGoEndpoint = await _store.loadSetting<String>(
        'bitgo_endpoint',
      );
      _bitgoEndpoint =
          savedBitGoEndpoint == null ||
              savedBitGoEndpoint.trim() == legacyLocalBitGoBackendEndpoint
          ? defaultBitGoBackendEndpoint
          : savedBitGoEndpoint;
      if (savedBitGoEndpoint == legacyLocalBitGoBackendEndpoint) {
        await _store.saveSetting('bitgo_endpoint', defaultBitGoBackendEndpoint);
      }
      _bitGoClientService.endpoint = _bitgoEndpoint;
      await _refreshBitGoBackendHealth(allowFailure: true);
      for (final ChainKind chain in ChainKind.values) {
        for (final ChainNetwork network in ChainNetwork.values) {
          _rpcEndpoints[_scopeKey(chain, network)] =
              await _walletService.loadRpcEndpoint(
                chain: chain,
                network: network,
              ) ??
              _defaultRpcEndpointFor(chain, network);
        }
      }
      final String? savedChainName = await _store.loadSetting<String>(
        'active_chain',
      );
      final String? savedNetworkName = await _store.loadSetting<String>(
        'active_network',
      );
      _activeChain = savedChainName == null
          ? ChainKind.solana
          : ChainKind.values.byName(savedChainName);
      _activeNetwork = savedNetworkName == null
          ? ChainNetwork.testnet
          : ChainNetwork.values.byName(savedNetworkName);
      await _loadWalletEngineForActiveScope();
      await _reloadWalletProfiles();
      _applyActiveChainSnapshot();
      _sendDraft = SendDraft(
        chain: _activeChain,
        network: _activeNetwork,
        walletEngine: _activeWalletEngine,
      );
      await _loadCachedReadinessForActiveScope();

      _pendingTransfers = await _store.loadTransfers();
      await _refreshLocalPermissions();
      await _refreshConnectivityState();
      if (_wallet != null) {
        await refreshWalletData();
        if (_hasInternet) {
          await broadcastPendingTransfers();
          await refreshSubmittedTransfers();
        }
      }

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        _,
      ) async {
        await _refreshConnectivityState();
        if (_hasInternet) {
          await refreshWalletData();
          await broadcastPendingTransfers();
          await refreshSubmittedTransfers();
        }
      });

      _initialized = true;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> createWallet() async {
    await _walletService.createWallet();
    await _reloadWalletProfiles();
    _applyActiveChainSnapshot();
    notifyListeners();
  }

  Future<void> restoreWallet(String seedPhrase) async {
    await _walletService.restoreWallet(seedPhrase);
    await _reloadWalletProfiles();
    _applyActiveChainSnapshot();
    notifyListeners();
  }

  Future<void> setActiveChain(ChainKind chain) async {
    if (_activeChain == chain) {
      return;
    }
    if (listenerRunning) {
      await _hotspotTransportService.stop();
      await _bleTransportService.stop();
    }
    _activeChain = chain;
    await _loadWalletEngineForActiveScope();
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = _sendDraft.copyWith(
      chain: chain,
      network: _activeNetwork,
      walletEngine: _activeWalletEngine,
      amountSol: 0,
      clearReceiver: true,
    );
    _applyActiveChainSnapshot();
    await _store.saveSetting('active_chain', chain.name);
    await _loadCachedReadinessForActiveScope();
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      notifyListeners();
    }
  }

  Future<void> setActiveNetwork(ChainNetwork network) async {
    if (_activeNetwork == network) {
      return;
    }
    if (listenerRunning) {
      await _hotspotTransportService.stop();
      await _bleTransportService.stop();
    }
    _activeNetwork = network;
    await _loadWalletEngineForActiveScope();
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = _sendDraft.copyWith(
      chain: _activeChain,
      network: network,
      walletEngine: _activeWalletEngine,
      amountSol: 0,
      clearReceiver: true,
    );
    _applyActiveChainSnapshot();
    await _store.saveSetting('active_network', network.name);
    await _loadCachedReadinessForActiveScope();
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      notifyListeners();
    }
  }

  Future<void> setActiveWalletEngine(WalletEngine engine) async {
    if (_activeWalletEngine == engine) {
      return;
    }
    if (listenerRunning) {
      await _hotspotTransportService.stop();
      await _bleTransportService.stop();
    }
    _activeWalletEngine = engine;
    _walletEngines[_activeScopeKey] = engine;
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = _sendDraft.copyWith(
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: engine,
      amountSol: 0,
      clearReceiver: true,
    );
    await _store.saveSetting(_walletEngineKey(_activeScopeKey), engine.name);
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      notifyListeners();
    }
  }

  Future<void> _reloadWalletProfiles() async {
    for (final ChainKind chain in ChainKind.values) {
      _wallets[chain] = await _walletService.loadWallet(chain: chain);
      _offlineWallets[chain] = await _walletService.loadOfflineWallet(
        chain: chain,
      );
    }
  }

  void _applyActiveChainSnapshot() {
    _wallet = _wallets[_activeChain];
    _offlineWallet = _offlineWallets[_activeChain];
    _bitgoWallet = _bitgoWallets[_activeScopeKey];
    _mainBalanceLamports = _mainBalances[_activeScopeKey] ?? 0;
    _offlineBalanceLamports = _offlineBalances[_activeScopeKey] ?? 0;
    _rpcEndpoint =
        _rpcEndpoints[_activeScopeKey] ??
        _defaultRpcEndpointFor(_activeChain, _activeNetwork);
    if (_activeChain == ChainKind.solana) {
      _solanaService.rpcEndpoint = _rpcEndpoint;
      _solanaService.network = _activeNetwork;
    } else {
      _ethereumService.rpcEndpoint = _rpcEndpoint;
      _ethereumService.network = _activeNetwork;
    }
    _bitGoClientService.endpoint = _bitgoEndpoint;
  }

  Future<void> _loadWalletEngineForActiveScope() async {
    _activeWalletEngine =
        await _store.loadSetting<String>(_walletEngineKey(_activeScopeKey)) ==
            WalletEngine.bitgo.name
        ? WalletEngine.bitgo
        : WalletEngine.local;
    _walletEngines[_activeScopeKey] = _activeWalletEngine;
  }

  Future<WalletBackupExport> exportWalletBackup() {
    return _runTaskWithResult(
      'Saving wallet backup...',
      _walletService.exportWalletBackup,
    );
  }

  Future<void> refreshWalletData() async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      await _refreshBitGoWalletData();
      return;
    }
    if (_wallet == null) {
      return;
    }

    try {
      if (_activeChain == ChainKind.solana) {
        _mainBalanceLamports = await _solanaService.getBalanceLamports(
          _wallet!.address,
        );
        _offlineBalanceLamports = _offlineWallet == null
            ? 0
            : await _solanaService.getBalanceLamports(_offlineWallet!.address);
      } else {
        _mainBalanceLamports = await _ethereumService.getBalanceBaseUnits(
          _wallet!.address,
        );
        _offlineBalanceLamports = _offlineWallet == null
            ? 0
            : await _ethereumService.getBalanceBaseUnits(
                _offlineWallet!.address,
              );
      }
      _mainBalances[_activeScopeKey] = _mainBalanceLamports;
      _offlineBalances[_activeScopeKey] = _offlineBalanceLamports;
      _hasDevnet = true;
      _hasInternet = true;
      _statusMessage = null;
      if (_activeChain == ChainKind.solana) {
        try {
          await _syncCachedBlockhashValidity();
        } catch (_) {
          await _clearCachedBlockhash();
        }
      }
    } catch (error) {
      _hasDevnet = false;
      _hasInternet = false;
      _statusMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> requestAirdrop({bool toOfflineWallet = false}) async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      throw const FormatException(
        'BitGo mode uses the backend-managed wallet. Fund it through the BitGo wallet flow instead of local airdrops.',
      );
    }
    if (_activeChain != ChainKind.solana) {
      throw const FormatException(
        'Ethereum faucet support is not built into the app yet. Use a Sepolia faucet and then refresh the balance.',
      );
    }
    if (_activeNetwork == ChainNetwork.mainnet) {
      throw const FormatException(
        'Airdrops are only available on Solana devnet.',
      );
    }
    final WalletProfile? targetWallet = toOfflineWallet
        ? _offlineWallet
        : _wallet;
    if (targetWallet == null) {
      return;
    }
    await _runTask(
      toOfflineWallet
          ? 'Requesting Solana devnet airdrop for the offline wallet...'
          : 'Requesting Solana devnet airdrop...',
      () async {
        await _refreshConnectivityState();
        try {
          await _solanaService.requestAirdrop(targetWallet.address, sol: 1);
          _hasDevnet = true;
          _hasInternet = true;
          _statusMessage = null;
        } on SocketException {
          _hasDevnet = false;
          _hasInternet = false;
          rethrow;
        } catch (error) {
          _statusMessage = error.toString();
          rethrow;
        }
        await refreshWalletData();
      },
    );
  }

  Future<void> prepareForOffline() async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      throw const FormatException(
        'BitGo mode does not use offline signing readiness.',
      );
    }
    await _runTask('Refreshing offline transaction readiness...', () async {
      if (_offlineWallet == null) {
        throw const FormatException('Create or restore a wallet first.');
      }
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw SocketException(
          _activeChain == ChainKind.solana
              ? 'Internet is required to fetch a fresh blockhash.'
              : 'Internet is required to fetch a fresh Ethereum nonce and gas quote.',
        );
      }
      if (_activeChain == ChainKind.solana) {
        await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
      } else {
        await _updateCachedEthereumContext(
          await _ethereumService.prepareTransferContext(
            _offlineWallet!.address,
          ),
        );
      }
      await refreshWalletData();
    });
  }

  Future<void> topUpOfflineWallet(double amountSol) async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      throw const FormatException(
        'BitGo mode does not use the local offline wallet.',
      );
    }
    await _runTask('Moving funds into the offline wallet...', () async {
      if (_wallet == null || _offlineWallet == null) {
        throw const FormatException('Create or restore a wallet first.');
      }
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to top up the offline wallet.',
        );
      }

      final int lamports = _activeChain.amountToBaseUnits(amountSol);
      if (lamports <= 0) {
        throw const FormatException('Enter an amount greater than zero.');
      }
      final int feeHeadroom = _activeChain == ChainKind.solana
          ? solFeeHeadroomLamports
          : _estimatedEthereumFeeHeadroom();
      if (lamports + feeHeadroom > _mainBalanceLamports) {
        throw const FormatException(
          'Main wallet balance is too low for that top up amount plus network fees.',
        );
      }

      if (_activeChain == ChainKind.solana) {
        final Ed25519HDKeyPair sender = await _walletService
            .loadSigningKeyPair();
        final String signature = await _solanaService.sendTransferNow(
          sender: sender,
          receiverAddress: _offlineWallet!.address,
          lamports: lamports,
        );
        await _solanaService.waitForConfirmation(signature);
        await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
      } else {
        final EthPrivateKey sender = await _walletService
            .loadEthereumSigningCredentials();
        final String signature = await _ethereumService.sendTransferNow(
          sender: sender,
          senderAddress: _wallet!.address,
          receiverAddress: _offlineWallet!.address,
          amountBaseUnits: lamports,
        );
        await _ethereumService.waitForConfirmation(signature);
        await _updateCachedEthereumContext(
          await _ethereumService.prepareTransferContext(
            _offlineWallet!.address,
          ),
        );
      }
      await refreshWalletData();
    });
  }

  Future<void> requestBlePermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    _localPermissionsGranted = statuses.values.every(
      (PermissionStatus status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );
    notifyListeners();
  }

  Future<void> requestLocalPermissions() {
    return requestBlePermissions();
  }

  Future<void> setRpcEndpoint(String value) async {
    final String endpoint = value.trim();
    if (endpoint.isEmpty) {
      return;
    }

    _rpcEndpoint = endpoint;
    _rpcEndpoints[_activeScopeKey] = endpoint;
    if (_activeChain == ChainKind.solana) {
      _solanaService.rpcEndpoint = endpoint;
    } else {
      _ethereumService.rpcEndpoint = endpoint;
    }
    await _walletService.saveRpcEndpoint(
      endpoint,
      chain: _activeChain,
      network: _activeNetwork,
    );
    await refreshWalletData();
    notifyListeners();
  }

  Future<void> setBitGoEndpoint(String value) async {
    final String endpoint = _normalizeEndpoint(value);
    if (endpoint.isEmpty) {
      return;
    }
    _bitgoEndpoint = endpoint;
    _bitGoClientService.endpoint = endpoint;
    _bitGoClientService.clearSession();
    _bitgoBackendMode = BitGoBackendMode.unknown;
    await _store.saveSetting('bitgo_endpoint', endpoint);
    if (_activeWalletEngine == WalletEngine.bitgo) {
      await refreshWalletData();
    } else {
      await _refreshBitGoBackendHealth(allowFailure: true);
      notifyListeners();
    }
  }

  Future<void> connectBitGoDemo() async {
    await _runTask('Connecting BitGo demo session...', () async {
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to connect the BitGo demo wallet.',
        );
      }
      await _refreshBitGoBackendHealth();
      final BitGoDemoSession session = await _bitGoClientService
          .createDemoSession();
      _syncBitGoWallets(session.wallets);
      await refreshWalletData();
    });
  }

  void updateReceiver({
    required String receiverAddress,
    String receiverLabel = '',
    String receiverEndpoint = '',
    String receiverPeripheralId = '',
    String receiverPeripheralName = '',
  }) {
    _sendDraft = _sendDraft.copyWith(
      receiverAddress: receiverAddress.trim(),
      receiverLabel: receiverLabel.trim(),
      receiverEndpoint: _normalizeEndpoint(receiverEndpoint),
      receiverPeripheralId: receiverPeripheralId.trim(),
      receiverPeripheralName: receiverPeripheralName.trim(),
    );
    notifyListeners();
  }

  void setSendTransport(TransportKind kind) {
    _sendDraft = _sendDraft.copyWith(
      chain: _activeChain,
      network: _activeNetwork,
      transport: kind,
      clearReceiver: true,
    );
    notifyListeners();
  }

  void setReceiveTransport(TransportKind kind) {
    _receiveTransport = kind;
    notifyListeners();
  }

  void updateAmount(double amountSol) {
    _sendDraft = _sendDraft.copyWith(amountSol: amountSol);
    notifyListeners();
  }

  void clearDraft() {
    _sendDraft = SendDraft(
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: _activeWalletEngine,
    );
    notifyListeners();
  }

  void clearAnnouncement() {
    _announcementMessage = null;
    notifyListeners();
  }

  void acknowledgeLastReceivedTransfer() {
    _lastReceivedTransferId = null;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    await _refreshConnectivityState();
    if (_wallet != null && _hasInternet) {
      await refreshWalletData();
      await broadcastPendingTransfers();
      await refreshSubmittedTransfers();
    } else if (_wallet != null) {
      notifyListeners();
    }
  }

  Future<void> scanBleReceivers() async {
    await requestBlePermissions();
    _bleDiscovering = true;
    notifyListeners();
    try {
      _bleReceivers = await _bleTransportService.discover();
    } finally {
      _bleDiscovering = false;
      notifyListeners();
    }
  }

  Future<PendingTransfer> sendCurrentDraft() async {
    if (_activeWalletEngine == WalletEngine.local &&
        (_wallet == null || _offlineWallet == null)) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (_sendDraft.receiverAddress.isEmpty) {
      throw const FormatException('Receiver address is required.');
    }
    if (_activeWalletEngine == WalletEngine.local &&
        _sendDraft.transport == TransportKind.hotspot &&
        _sendDraft.receiverEndpoint.isEmpty) {
      throw const FormatException(
        'Receiver endpoint is required for hotspot transfer.',
      );
    }
    if (_activeWalletEngine == WalletEngine.local &&
        _sendDraft.transport == TransportKind.ble &&
        _sendDraft.receiverPeripheralId.isEmpty) {
      throw const FormatException('Select a BLE receiver before sending.');
    }
    if (_activeChain == ChainKind.ethereum &&
        !_ethereumService.isValidAddress(_sendDraft.receiverAddress) &&
        _ethereumService.isEnsName(_sendDraft.receiverLabel)) {
      _sendDraft = _sendDraft.copyWith(
        receiverAddress: await _ethereumService.resolveEnsAddress(
          _sendDraft.receiverLabel,
        ),
      );
      notifyListeners();
    }
    if (!_isValidAddressForChain(_sendDraft.receiverAddress, _activeChain)) {
      throw FormatException(
        _activeChain == ChainKind.solana
            ? 'Receiver address is not a valid Solana address.'
            : 'Receiver address or ENS name is not valid.',
      );
    }
    final int lamports = _activeChain.amountToBaseUnits(_sendDraft.amountSol);
    if (lamports <= 0) {
      throw const FormatException('Enter an amount greater than zero.');
    }
    await _refreshConnectivityState();
    if (_activeWalletEngine == WalletEngine.bitgo) {
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to send with BitGo mode.',
        );
      }
      try {
        await _refreshBitGoBackendHealth();
      } catch (error) {
        if (_shouldAutoFallbackBitGo(error)) {
          return _fallbackBitGoDraftToLocalAndSend(
            'BitGo backend is unavailable. Switched to Local mode and retrying with the offline wallet.',
          );
        }
        rethrow;
      }
      if (!_bitgoBackendMode.isLive) {
        return _fallbackBitGoDraftToLocalAndSend(
          'BitGo backend is in demo mode. Switched to Local mode and retrying with the offline wallet.',
        );
      }
      await _ensureBitGoSession();
      final BitGoWalletSummary? wallet = _bitgoWallet;
      if (wallet == null) {
        throw FormatException(
          'BitGo demo wallet is not configured for ${_activeNetwork.labelFor(_activeChain)}.',
        );
      }
      if (lamports > _mainBalanceLamports) {
        throw const FormatException(
          'Amount exceeds the available BitGo wallet balance.',
        );
      }
      final String transferId = _uuid.v4();
      final DateTime createdAt = _clock();
      final BitGoTransferSnapshot snapshot;
      try {
        snapshot = await _bitGoClientService.submitTransfer(
          chain: _activeChain,
          network: _activeNetwork,
          walletId: wallet.walletId,
          receiverAddress: _sendDraft.receiverAddress,
          amountBaseUnits: lamports,
          clientTransferId: transferId,
        );
      } catch (error) {
        if (_shouldAutoFallbackBitGo(error)) {
          return _fallbackBitGoDraftToLocalAndSend(
            'BitGo submit failed. Switched to Local mode and retrying with the offline wallet.',
          );
        }
        rethrow;
      }
      final TransferStatus status = _bitgoStatusToTransferStatus(
        snapshot.status,
      );
      final PendingTransfer transfer = PendingTransfer(
        transferId: transferId,
        chain: _activeChain,
        network: _activeNetwork,
        walletEngine: WalletEngine.bitgo,
        direction: TransferDirection.outbound,
        status: status,
        amountLamports: lamports,
        senderAddress: wallet.address,
        receiverAddress: _sendDraft.receiverAddress,
        transport: _sendDraft.transport,
        createdAt: createdAt,
        updatedAt: snapshot.updatedAt ?? createdAt,
        remoteEndpoint: _sendDraft.transport == TransportKind.hotspot
            ? (_sendDraft.receiverEndpoint.isEmpty
                  ? 'Address discovery'
                  : _sendDraft.receiverEndpoint)
            : (_sendDraft.receiverPeripheralName.isEmpty
                  ? 'BLE discovery'
                  : _sendDraft.receiverPeripheralName),
        transactionSignature: snapshot.transactionSignature,
        explorerUrl: snapshot.explorerUrl,
        lastError: status.isError ? snapshot.message : null,
        confirmedAt: status == TransferStatus.confirmed
            ? snapshot.updatedAt ?? createdAt
            : null,
        bitgoWalletId: wallet.walletId,
        bitgoTransferId: snapshot.bitgoTransferId,
        backendStatus: snapshot.status,
      );
      await _persistTransfer(transfer);
      _lastSentTransferId = transfer.transferId;
      clearDraft();
      if (_hasInternet) {
        unawaited(_startRealtimeSettlementSync());
      }
      return transfer;
    }

    final int feeHeadroom = _activeChain == ChainKind.solana
        ? solFeeHeadroomLamports
        : _estimatedEthereumFeeHeadroom();
    if (lamports + feeHeadroom > offlineSpendableLamports) {
      throw const FormatException(
        'Amount exceeds the available offline wallet balance after network fees.',
      );
    }

    if (_activeChain == ChainKind.solana) {
      if (_hasInternet) {
        await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
      } else {
        await _ensureFreshCachedBlockhash();
      }
    } else {
      if (_hasInternet) {
        await _updateCachedEthereumContext(
          await _ethereumService.prepareTransferContext(
            _offlineWallet!.address,
          ),
        );
      } else {
        await _ensureFreshEthereumContext();
      }
    }

    final String transferId = _uuid.v4();
    final DateTime createdAt = _clock();
    final OfflineEnvelope envelope;
    final ValidatedTransactionDetails details;
    if (_activeChain == ChainKind.solana) {
      final Ed25519HDKeyPair sender = await _walletService
          .loadOfflineSigningKeyPair();
      envelope = await _solanaService.createSignedEnvelope(
        sender: sender,
        receiverAddress: _sendDraft.receiverAddress,
        lamports: lamports,
        cachedBlockhash: _cachedBlockhash!,
        transferId: transferId,
        createdAt: createdAt,
        transportKind: _sendDraft.transport,
      );
      details = _solanaService.validateEnvelope(envelope);
    } else {
      final EthPrivateKey sender = await _walletService
          .loadEthereumOfflineSigningCredentials();
      envelope = await _ethereumService.createSignedEnvelope(
        sender: sender,
        senderAddress: _offlineWallet!.address,
        receiverAddress: _sendDraft.receiverAddress,
        amountBaseUnits: lamports,
        preparedContext: _cachedEthereumContext!,
        transferId: transferId,
        createdAt: createdAt,
        transportKind: _sendDraft.transport,
      );
      details = _ethereumService.validateEnvelope(envelope);
    }

    if (_sendDraft.transport == TransportKind.hotspot) {
      final Uri endpoint = Uri.parse(_sendDraft.receiverEndpoint);
      await _hotspotTransportService.send(
        endpoint: endpoint,
        envelope: envelope,
      );
    } else {
      await _bleTransportService.send(
        peripheralId: _sendDraft.receiverPeripheralId,
        envelope: envelope,
      );
    }

    final PendingTransfer transfer = PendingTransfer(
      transferId: transferId,
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.outbound,
      status: TransferStatus.sentOffline,
      amountLamports: lamports,
      senderAddress: _offlineWallet!.address,
      receiverAddress: _sendDraft.receiverAddress,
      transport: _sendDraft.transport,
      createdAt: createdAt,
      updatedAt: createdAt,
      envelope: envelope,
      remoteEndpoint: _sendDraft.transport == TransportKind.hotspot
          ? _sendDraft.receiverEndpoint
          : _sendDraft.receiverPeripheralName,
      transactionSignature: details.transactionSignature,
    );

    await _persistTransfer(transfer);
    _lastSentTransferId = transfer.transferId;
    if (_hasInternet) {
      unawaited(_broadcastTransferInBackground(transfer));
      unawaited(_startRealtimeSettlementSync());
    }
    clearDraft();
    return transfer;
  }

  Future<PendingTransfer> _fallbackBitGoDraftToLocalAndSend(
    String reason,
  ) async {
    final SendDraft preservedDraft = _sendDraft;
    _activeWalletEngine = WalletEngine.local;
    _walletEngines[_activeScopeKey] = WalletEngine.local;
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = preservedDraft.copyWith(walletEngine: WalletEngine.local);
    if (_sendDraft.transport == TransportKind.hotspot &&
        _sendDraft.receiverEndpoint.isEmpty &&
        _sendDraft.receiverPeripheralId.isNotEmpty) {
      _sendDraft = _sendDraft.copyWith(transport: TransportKind.ble);
    }
    _announcementMessage = reason;
    _statusMessage = reason;
    await _store.saveSetting(
      _walletEngineKey(_activeScopeKey),
      WalletEngine.local.name,
    );
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      notifyListeners();
    }
    if (_sendDraft.transport == TransportKind.hotspot &&
        _sendDraft.receiverEndpoint.isEmpty) {
      throw const FormatException(
        'BitGo fallback switched to Local mode. Receiver endpoint is still required for hotspot handoff.',
      );
    }
    if (_sendDraft.transport == TransportKind.ble &&
        _sendDraft.receiverPeripheralId.isEmpty) {
      throw const FormatException(
        'BitGo fallback switched to Local mode. Select a BLE receiver before retrying.',
      );
    }
    return sendCurrentDraft();
  }

  bool _shouldAutoFallbackBitGo(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    final String normalized = error.toString().toLowerCase();
    return normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('timed out') ||
        normalized.contains('bitgo backend request failed (500)') ||
        normalized.contains('unexpected bitgo backend error');
  }

  Future<void> startReceiver() async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      throw const FormatException(
        'BitGo mode does not use offline receive. Switch to Local mode to listen over hotspot or BLE.',
      );
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (_receiveTransport == TransportKind.ble) {
      await requestBlePermissions();
    }
    await _refreshConnectivityState();
    if (_receiveTransport == TransportKind.hotspot) {
      await _bleTransportService.stop();
      await _hotspotTransportService.start(onEnvelope: _handleIncomingEnvelope);
    } else {
      await _hotspotTransportService.stop();
      await _bleTransportService.start(
        onEnvelope: _handleIncomingEnvelope,
        receiverChain: _activeChain,
        receiverNetwork: _activeNetwork,
        receiverDisplayAddress: _wallet!.displayAddress,
        receiverAddress: _wallet!.address,
      );
    }
    notifyListeners();
  }

  Future<void> stopReceiver() async {
    await _hotspotTransportService.stop();
    await _bleTransportService.stop();
    notifyListeners();
  }

  Future<void> retryBroadcast(String transferId) async {
    final PendingTransfer? transfer = transferById(transferId);
    if (transfer == null ||
        !transfer.canBroadcast ||
        transfer.chain != _activeChain ||
        transfer.network != _activeNetwork) {
      return;
    }
    await _broadcastTransfer(transfer);
  }

  Future<void> broadcastPendingTransfers() async {
    final List<PendingTransfer> pending = _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.canBroadcast &&
              transfer.chain == _activeChain &&
              transfer.network == _activeNetwork;
        })
        .toList(growable: false);

    for (final PendingTransfer transfer in pending) {
      await _broadcastTransfer(transfer);
    }
  }

  Future<void> broadcastPendingInboundTransfers() async {
    await broadcastPendingTransfers();
  }

  Future<void> refreshSubmittedTransfers() async {
    final List<PendingTransfer> submitted = _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.walletEngine == WalletEngine.local &&
              transfer.transactionSignature != null &&
              transfer.chain == _activeChain &&
              transfer.network == _activeNetwork &&
              (transfer.status == TransferStatus.sentOffline ||
                  transfer.status == TransferStatus.receivedPendingBroadcast ||
                  transfer.status == TransferStatus.broadcastSubmitted ||
                  transfer.status == TransferStatus.broadcasting ||
                  transfer.status == TransferStatus.broadcastFailed);
        })
        .toList(growable: false);

    bool shouldRefreshBalances = false;
    for (final PendingTransfer transfer in submitted) {
      if (transfer.chain == ChainKind.solana) {
        final SignatureStatus? status = await _solanaService.getSignatureStatus(
          transfer.transactionSignature!,
        );
        if (status == null) {
          continue;
        }
        if (status.err != null) {
          await _persistTransfer(
            transfer.copyWith(
              status: TransferStatus.broadcastFailed,
              updatedAt: _clock(),
              lastError: status.err.toString(),
            ),
          );
          continue;
        }
        final TransferStatus? nextStatus = _nextStatusForSignature(status);
        if (nextStatus == null) {
          continue;
        }
        if (nextStatus == TransferStatus.broadcastSubmitted &&
            transfer.status != TransferStatus.broadcastSubmitted) {
          await _persistTransfer(
            transfer.copyWith(
              status: nextStatus,
              updatedAt: _clock(),
              explorerUrl: _solanaService
                  .explorerUrlFor(transfer.transactionSignature!)
                  .toString(),
              clearLastError: true,
            ),
          );
          continue;
        }
        if (nextStatus == TransferStatus.confirmed &&
            transfer.status != TransferStatus.confirmed) {
          shouldRefreshBalances = true;
          await _persistTransfer(
            transfer.copyWith(
              status: nextStatus,
              updatedAt: _clock(),
              explorerUrl: _solanaService
                  .explorerUrlFor(transfer.transactionSignature!)
                  .toString(),
              confirmedAt: _clock(),
              clearLastError: true,
            ),
          );
        }
        continue;
      }

      final TransactionReceipt? receipt = await _ethereumService
          .getTransactionReceipt(transfer.transactionSignature!);
      if (receipt == null) {
        continue;
      }
      if (receipt.status == false) {
        await _persistTransfer(
          transfer.copyWith(
            status: TransferStatus.broadcastFailed,
            updatedAt: _clock(),
            lastError:
                'Ethereum rejected the signed transfer during settlement.',
          ),
        );
        continue;
      }
      if (transfer.status != TransferStatus.confirmed) {
        shouldRefreshBalances = true;
        await _persistTransfer(
          transfer.copyWith(
            status: TransferStatus.confirmed,
            updatedAt: _clock(),
            explorerUrl: _ethereumService
                .explorerUrlFor(transfer.transactionSignature!)
                .toString(),
            confirmedAt: _clock(),
            clearLastError: true,
          ),
        );
      }
    }

    final List<PendingTransfer> bitgoTransfers = _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.walletEngine == WalletEngine.bitgo &&
              transfer.chain == _activeChain &&
              transfer.network == _activeNetwork &&
              transfer.bitgoTransferId != null;
        })
        .toList(growable: false);
    if (bitgoTransfers.isNotEmpty) {
      await _ensureBitGoSession();
    }
    for (final PendingTransfer transfer in bitgoTransfers) {
      final BitGoTransferSnapshot snapshot = await _bitGoClientService
          .fetchTransfer(transfer.transferId);
      final TransferStatus nextStatus = _bitgoStatusToTransferStatus(
        snapshot.status,
      );
      if (nextStatus == transfer.status &&
          snapshot.transactionSignature == transfer.transactionSignature &&
          snapshot.explorerUrl == transfer.explorerUrl &&
          snapshot.message == transfer.lastError &&
          snapshot.status == transfer.backendStatus) {
        continue;
      }
      if (nextStatus == TransferStatus.confirmed) {
        shouldRefreshBalances = true;
      }
      await _persistTransfer(
        transfer.copyWith(
          status: nextStatus,
          updatedAt: snapshot.updatedAt ?? _clock(),
          transactionSignature:
              snapshot.transactionSignature ?? transfer.transactionSignature,
          explorerUrl: snapshot.explorerUrl ?? transfer.explorerUrl,
          lastError: nextStatus.isError ? snapshot.message : null,
          clearLastError: !nextStatus.isError,
          confirmedAt: nextStatus == TransferStatus.confirmed
              ? (snapshot.updatedAt ?? _clock())
              : transfer.confirmedAt,
          bitgoTransferId: snapshot.bitgoTransferId,
          bitgoWalletId: snapshot.bitgoWalletId,
          backendStatus: snapshot.status,
        ),
      );
    }

    if (shouldRefreshBalances && _wallet != null && _hasInternet) {
      await refreshWalletData();
    }
  }

  List<PendingTransfer> transfersFor(TransferDirection direction) {
    return pendingTransfers
        .where(
          (PendingTransfer transfer) =>
              transfer.direction == direction &&
              transfer.chain == _activeChain &&
              transfer.network == _activeNetwork,
        )
        .toList(growable: false);
  }

  List<PendingTransferListItem> listItemsFor(TransferDirection direction) {
    final DateTime now = _clock();
    return transfersFor(direction)
        .map(
          (PendingTransfer transfer) => PendingTransferListItem(
            transferId: transfer.transferId,
            amountLabel: Formatters.asset(transfer.amountSol, transfer.chain),
            counterpartyLabel: Formatters.shortAddress(
              transfer.counterpartyAddress,
            ),
            ageLabel: Formatters.relativeAge(transfer.updatedAt, now),
            status: transfer.status,
            direction: transfer.direction,
          ),
        )
        .toList(growable: false);
  }

  List<PendingTransfer> recentActivity() => pendingTransfers
      .where(
        (PendingTransfer transfer) =>
            transfer.chain == _activeChain &&
            transfer.network == _activeNetwork,
      )
      .take(3)
      .toList(growable: false);

  PendingTransfer? transferById(String transferId) {
    for (final PendingTransfer transfer in _pendingTransfers) {
      if (transfer.transferId == transferId) {
        return transfer;
      }
    }
    return null;
  }

  List<TransferTimelineState> timelineFor(PendingTransfer transfer) {
    if (transfer.walletEngine == WalletEngine.bitgo) {
      final int currentIndex = switch (transfer.status) {
        TransferStatus.created => 0,
        TransferStatus.broadcasting => 1,
        TransferStatus.broadcastSubmitted => 2,
        TransferStatus.confirmed => 3,
        TransferStatus.broadcastFailed || TransferStatus.expired => 1,
        TransferStatus.sentOffline ||
        TransferStatus.receivedPendingBroadcast => 1,
      };
      final List<_TimelineNode> steps = <_TimelineNode>[
        const _TimelineNode(
          title: 'Prepared',
          caption: 'Receiver and amount were prepared in BitGo mode.',
        ),
        const _TimelineNode(
          title: 'Broadcasting',
          caption: 'The backend is orchestrating submission through BitGo.',
        ),
        const _TimelineNode(
          title: 'Submitted',
          caption: 'BitGo accepted and submitted the transfer.',
        ),
        const _TimelineNode(
          title: 'Confirmed',
          caption: 'The transfer reached confirmed on-chain status.',
        ),
      ];
      final List<TransferTimelineState> timeline = <TransferTimelineState>[];
      for (int index = 0; index < steps.length; index++) {
        final _TimelineNode step = steps[index];
        timeline.add(
          TransferTimelineState(
            title: step.title,
            caption: step.caption,
            isComplete:
                index < currentIndex ||
                (transfer.status == TransferStatus.confirmed &&
                    index <= currentIndex),
            isCurrent: index == currentIndex,
            isError: transfer.status.isError && index == currentIndex,
          ),
        );
      }
      return timeline;
    }

    final List<_TimelineNode> steps = <_TimelineNode>[
      const _TimelineNode(
        title: 'Signed',
        caption:
            'Transaction was signed locally with the sender offline wallet.',
      ),
      _TimelineNode(
        title: transfer.isInbound ? 'Received offline' : 'Sent offline',
        caption: transfer.isInbound
            ? 'Receiver validated and stored the signed transfer.'
            : 'Signed transaction envelope was delivered over the local link.',
      ),
      const _TimelineNode(
        title: 'Broadcasting',
        caption:
            'Either device can later submit the signed transaction to the chain RPC.',
      ),
      const _TimelineNode(
        title: 'Submitted',
        caption: 'The RPC node accepted the transaction signature.',
      ),
      const _TimelineNode(
        title: 'Confirmed',
        caption: 'The transfer reached confirmed status on-chain.',
      ),
    ];

    final int currentIndex = switch (transfer.status) {
      TransferStatus.created => 0,
      TransferStatus.sentOffline ||
      TransferStatus.receivedPendingBroadcast => 1,
      TransferStatus.broadcasting => 2,
      TransferStatus.broadcastSubmitted => 3,
      TransferStatus.confirmed => 4,
      TransferStatus.broadcastFailed || TransferStatus.expired => 2,
    };

    final List<TransferTimelineState> timeline = <TransferTimelineState>[];
    for (int index = 0; index < steps.length; index++) {
      final _TimelineNode step = steps[index];
      timeline.add(
        TransferTimelineState(
          title: step.title,
          caption: step.caption,
          isComplete:
              index < currentIndex ||
              (transfer.status == TransferStatus.confirmed &&
                  index <= currentIndex),
          isCurrent: index == currentIndex,
          isError: transfer.status.isError && index == currentIndex,
        ),
      );
    }
    return timeline;
  }

  Future<void> clearLocalData() async {
    await _hotspotTransportService.stop();
    await _bleTransportService.stop();
    await _walletService.clearAll();
    await _store.clearAll();
    _rpcEndpoints[_scopeKey(ChainKind.solana, ChainNetwork.testnet)] =
        defaultSolanaTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.solana, ChainNetwork.mainnet)] =
        defaultSolanaMainnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.ethereum, ChainNetwork.testnet)] =
        defaultEthereumTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.ethereum, ChainNetwork.mainnet)] =
        defaultEthereumMainnetRpcEndpoint;
    _rpcEndpoint = defaultSolanaTestnetRpcEndpoint;
    _solanaService.rpcEndpoint = defaultSolanaTestnetRpcEndpoint;
    _solanaService.network = ChainNetwork.testnet;
    _ethereumService.rpcEndpoint = defaultEthereumTestnetRpcEndpoint;
    _ethereumService.network = ChainNetwork.testnet;
    _activeChain = ChainKind.solana;
    _activeNetwork = ChainNetwork.testnet;
    _activeWalletEngine = WalletEngine.local;
    _wallet = null;
    _offlineWallet = null;
    _bitgoWallet = null;
    _bitgoBackendMode = BitGoBackendMode.unknown;
    _wallets.clear();
    _offlineWallets.clear();
    _walletEngines.clear();
    _bitgoWallets.clear();
    _cachedBlockhash = null;
    _cachedEthereumContext = null;
    _mainBalanceLamports = 0;
    _offlineBalanceLamports = 0;
    _mainBalances.clear();
    _offlineBalances.clear();
    _bitgoEndpoint = defaultBitGoBackendEndpoint;
    _bitGoClientService.endpoint = defaultBitGoBackendEndpoint;
    _bitGoClientService.clearSession();
    _sendDraft = const SendDraft();
    _receiveTransport = TransportKind.hotspot;
    _pendingTransfers = <PendingTransfer>[];
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _bleDiscovering = false;
    _lastSentTransferId = null;
    _lastReceivedTransferId = null;
    _statusMessage = null;
    _announcementMessage = null;
    notifyListeners();
  }

  Future<void> _persistTransfer(PendingTransfer transfer) async {
    await _store.upsertTransfer(transfer);
    _pendingTransfers = List<PendingTransfer>.from(_pendingTransfers);
    final int index = _pendingTransfers.indexWhere(
      (PendingTransfer item) => item.transferId == transfer.transferId,
    );
    if (index == -1) {
      _pendingTransfers.add(transfer);
    } else {
      _pendingTransfers[index] = transfer;
    }
    notifyListeners();
  }

  Future<TransportReceiveResult> _handleIncomingEnvelope(
    OfflineEnvelope envelope,
  ) async {
    final ValidatedTransactionDetails details =
        envelope.chain == ChainKind.solana
        ? _solanaService.validateEnvelope(envelope)
        : _ethereumService.validateEnvelope(envelope);

    if (_wallet == null) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Receiver wallet is not initialized.',
      );
    }
    if (envelope.chain != _activeChain || envelope.network != _activeNetwork) {
      return TransportReceiveResult(
        accepted: false,
        message:
            'Receiver is listening on ${_activeChain.networkLabelFor(_activeNetwork)}, but this transfer is for ${envelope.chain.networkLabelFor(envelope.network)}.',
      );
    }
    if (details.receiverAddress != _wallet!.address) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Signed transfer is not addressed to this wallet.',
      );
    }
    if (await _store.findByTransferId(envelope.transferId) != null ||
        await _store.findBySignature(details.transactionSignature) != null) {
      _announcementMessage = 'Already received';
      notifyListeners();
      return const TransportReceiveResult(
        accepted: true,
        message: 'Already received.',
      );
    }

    final PendingTransfer transfer = PendingTransfer(
      transferId: envelope.transferId,
      chain: envelope.chain,
      network: envelope.network,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.inbound,
      status: TransferStatus.receivedPendingBroadcast,
      amountLamports: envelope.amountLamports,
      senderAddress: envelope.senderAddress,
      receiverAddress: envelope.receiverAddress,
      transport: TransportKind.values.byName(envelope.transportHint),
      createdAt: envelope.createdAt,
      updatedAt: _clock(),
      envelope: envelope,
      remoteEndpoint: envelope.transportHint,
      transactionSignature: details.transactionSignature,
    );
    await _persistTransfer(transfer);
    _lastReceivedTransferId = transfer.transferId;
    if (_hasInternet) {
      unawaited(_broadcastTransferInBackground(transfer));
      unawaited(_startRealtimeSettlementSync());
    }
    return const TransportReceiveResult(
      accepted: true,
      message: 'Stored successfully.',
    );
  }

  Future<void> _broadcastTransfer(PendingTransfer transfer) async {
    if (!_hasInternet) {
      return;
    }
    await _persistTransfer(
      transfer.copyWith(
        status: TransferStatus.broadcasting,
        updatedAt: _clock(),
        clearLastError: true,
      ),
    );

    try {
      if (transfer.walletEngine == WalletEngine.bitgo) {
        await _ensureBitGoSession();
        final BitGoTransferSnapshot snapshot = await _bitGoClientService
            .submitTransfer(
              chain: transfer.chain,
              network: transfer.network,
              walletId: transfer.bitgoWalletId!,
              receiverAddress: transfer.receiverAddress,
              amountBaseUnits: transfer.amountLamports,
              clientTransferId: transfer.transferId,
            );
        final TransferStatus nextStatus = _bitgoStatusToTransferStatus(
          snapshot.status,
        );
        await _persistTransfer(
          transfer.copyWith(
            status: nextStatus,
            updatedAt: snapshot.updatedAt ?? _clock(),
            transactionSignature:
                snapshot.transactionSignature ?? transfer.transactionSignature,
            explorerUrl: snapshot.explorerUrl ?? transfer.explorerUrl,
            lastError: nextStatus.isError ? snapshot.message : null,
            clearLastError: !nextStatus.isError,
            confirmedAt: nextStatus == TransferStatus.confirmed
                ? (snapshot.updatedAt ?? _clock())
                : transfer.confirmedAt,
            bitgoTransferId: snapshot.bitgoTransferId,
            bitgoWalletId: snapshot.bitgoWalletId,
            backendStatus: snapshot.status,
          ),
        );
        unawaited(_startRealtimeSettlementSync());
        return;
      }
      final String signature = transfer.chain == ChainKind.solana
          ? await _solanaService.broadcastSignedTransaction(
              transfer.envelope!.signedTransactionBase64,
            )
          : await _ethereumService.broadcastSignedTransaction(
              transfer.envelope!.signedTransactionBase64,
            );
      await _persistTransfer(
        transfer.copyWith(
          status: TransferStatus.broadcastSubmitted,
          updatedAt: _clock(),
          transactionSignature: signature,
          explorerUrl:
              (transfer.chain == ChainKind.solana
                      ? _solanaService.explorerUrlFor(signature)
                      : _ethereumService.explorerUrlFor(signature))
                  .toString(),
        ),
      );
      unawaited(_startRealtimeSettlementSync());
    } catch (error) {
      bool reconciled = false;
      try {
        reconciled = await _reconcileBroadcastAfterError(transfer);
      } catch (_) {
        reconciled = false;
      }
      if (reconciled) {
        return;
      }
      final String message = _cleanErrorMessage(error);
      final TransferStatus status = _isExpiredBroadcastMessage(message)
          ? TransferStatus.expired
          : TransferStatus.broadcastFailed;
      await _persistTransfer(
        transfer.copyWith(
          status: status,
          updatedAt: _clock(),
          lastError: message,
        ),
      );
    }
  }

  Future<void> _refreshConnectivityState() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    _localIp = await _resolveLocalIp();
    _hasLocalLink = _localIp != null && _localIp!.isNotEmpty;
    final bool hasTransport = !results.contains(ConnectivityResult.none);
    if (hasTransport) {
      try {
        _hasDevnet = _activeChain == ChainKind.solana
            ? await _solanaService.isDevnetReachable()
            : await _ethereumService.isReachable();
      } catch (_) {
        _hasDevnet = false;
      }
    } else {
      _hasDevnet = false;
    }
    _hasInternet = _hasDevnet;
    notifyListeners();
  }

  Future<void> _refreshLocalPermissions() async {
    final PermissionStatus location = await Permission.locationWhenInUse.status;
    final PermissionStatus bluetoothScan =
        await Permission.bluetoothScan.status;
    final PermissionStatus bluetoothConnect =
        await Permission.bluetoothConnect.status;
    final PermissionStatus bluetoothAdvertise =
        await Permission.bluetoothAdvertise.status;
    _localPermissionsGranted =
        <PermissionStatus>[
          location,
          bluetoothScan,
          bluetoothConnect,
          bluetoothAdvertise,
        ].every((PermissionStatus status) {
          return status == PermissionStatus.granted ||
              status == PermissionStatus.limited;
        });
  }

  bool get _isCachedBlockhashExpired {
    if (_cachedBlockhash == null) {
      return true;
    }
    return _clock().difference(_cachedBlockhash!.fetchedAt) >
        blockhashFreshnessWindow;
  }

  bool get _isCachedEthereumContextExpired {
    if (_cachedEthereumContext == null) {
      return true;
    }
    return _clock().difference(_cachedEthereumContext!.fetchedAt) >
        ethereumContextFreshnessWindow;
  }

  Future<void> _ensureFreshCachedBlockhash() async {
    if (_activeChain != ChainKind.solana) {
      return _ensureFreshEthereumContext();
    }
    if (_cachedBlockhash == null || _isCachedBlockhashExpired) {
      try {
        await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
        return;
      } catch (_) {
        throw const FormatException(
          'Refresh offline send readiness while online before sending from the offline wallet.',
        );
      }
    }

    if (!_hasInternet) {
      return;
    }

    bool stillValid;
    try {
      stillValid = await _solanaService.isBlockhashValid(
        _cachedBlockhash!.blockhash,
      );
    } catch (_) {
      return;
    }
    if (!stillValid) {
      await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
    }
  }

  Future<void> _ensureFreshEthereumContext() async {
    if (_cachedEthereumContext == null || _isCachedEthereumContextExpired) {
      if (!_hasInternet || _offlineWallet == null) {
        throw const FormatException(
          'Refresh offline send readiness while online before sending from the offline wallet.',
        );
      }
      await _updateCachedEthereumContext(
        await _ethereumService.prepareTransferContext(_offlineWallet!.address),
      );
    }
  }

  Future<void> _syncCachedBlockhashValidity() async {
    if (_cachedBlockhash == null || !_hasDevnet) {
      return;
    }

    final bool stillValid = await _solanaService.isBlockhashValid(
      _cachedBlockhash!.blockhash,
    );
    if (!stillValid) {
      await _clearCachedBlockhash();
    }
  }

  Future<void> _loadCachedReadinessForActiveScope() async {
    _cachedBlockhash = null;
    _cachedEthereumContext = null;
    final Map<String, dynamic>? cachedBlockhashJson = await _store
        .loadSetting<Map<String, dynamic>>(
          _cachedBlockhashKey(_activeScopeKey),
        );
    if (cachedBlockhashJson != null) {
      _cachedBlockhash = CachedBlockhash.fromJson(cachedBlockhashJson);
    }
    final Map<String, dynamic>? cachedEthereumContextJson = await _store
        .loadSetting<Map<String, dynamic>>(
          _cachedEthereumContextKey(_activeScopeKey),
        );
    if (cachedEthereumContextJson != null) {
      _cachedEthereumContext = EthereumPreparedContext.fromJson(
        cachedEthereumContextJson,
      );
    }
  }

  Future<void> _updateCachedBlockhash(CachedBlockhash blockhash) async {
    _cachedBlockhash = blockhash;
    await _store.saveSetting(
      _cachedBlockhashKey(_activeScopeKey),
      blockhash.toJson(),
    );
  }

  Future<void> _clearCachedBlockhash() async {
    _cachedBlockhash = null;
    await _store.saveSetting(_cachedBlockhashKey(_activeScopeKey), null);
  }

  Future<void> _updateCachedEthereumContext(
    EthereumPreparedContext context,
  ) async {
    _cachedEthereumContext = context;
    await _store.saveSetting(
      _cachedEthereumContextKey(_activeScopeKey),
      context.toJson(),
    );
  }

  Future<void> _startRealtimeSettlementSync() async {
    if (_realtimeSettlementSyncRunning || !_hasInternet || _wallet == null) {
      return;
    }
    _realtimeSettlementSyncRunning = true;
    try {
      for (int attempt = 0; attempt < realtimeSettlementPollAttempts; attempt++) {
        if (!_hasRealtimeSettlementPendingForActiveScope()) {
          break;
        }
        if (attempt > 0) {
          await Future<void>.delayed(realtimeSettlementPollInterval);
        }
        await refreshSubmittedTransfers();
      }
    } catch (_) {
      // Ignore opportunistic refresh failures; normal status refresh still works.
    } finally {
      _realtimeSettlementSyncRunning = false;
    }
  }

  Future<void> _broadcastTransferInBackground(PendingTransfer transfer) async {
    try {
      await _broadcastTransfer(transfer);
    } catch (_) {
      // Background settlement should never surface an uncaught async error.
    }
  }

  TransferStatus? _nextStatusForSignature(SignatureStatus status) {
    return switch (status.confirmationStatus) {
      ConfirmationStatus.processed => TransferStatus.broadcastSubmitted,
      ConfirmationStatus.confirmed ||
      ConfirmationStatus.finalized => TransferStatus.confirmed,
    };
  }

  Future<bool> _reconcileBroadcastAfterError(PendingTransfer transfer) async {
    if (transfer.walletEngine == WalletEngine.bitgo) {
      await _ensureBitGoSession();
      final BitGoTransferSnapshot snapshot = await _bitGoClientService
          .fetchTransfer(transfer.transferId);
      final TransferStatus nextStatus = _bitgoStatusToTransferStatus(
        snapshot.status,
      );
      await _persistTransfer(
        transfer.copyWith(
          status: nextStatus,
          updatedAt: snapshot.updatedAt ?? _clock(),
          transactionSignature:
              snapshot.transactionSignature ?? transfer.transactionSignature,
          explorerUrl: snapshot.explorerUrl ?? transfer.explorerUrl,
          lastError: nextStatus.isError ? snapshot.message : null,
          clearLastError: !nextStatus.isError,
          confirmedAt: nextStatus == TransferStatus.confirmed
              ? (snapshot.updatedAt ?? _clock())
              : transfer.confirmedAt,
          bitgoTransferId: snapshot.bitgoTransferId,
          bitgoWalletId: snapshot.bitgoWalletId,
          backendStatus: snapshot.status,
        ),
      );
      return nextStatus != TransferStatus.broadcastFailed;
    }
    final String? signature = transfer.transactionSignature;
    if (signature == null) {
      return false;
    }

    if (transfer.chain == ChainKind.ethereum) {
      final TransactionReceipt? receipt = await _ethereumService
          .getTransactionReceipt(signature);
      if (receipt == null) {
        return false;
      }
      if (receipt.status == false) {
        await _persistTransfer(
          transfer.copyWith(
            status: TransferStatus.broadcastFailed,
            updatedAt: _clock(),
            lastError:
                'Ethereum rejected the signed transfer during settlement.',
          ),
        );
        return true;
      }
      await _persistTransfer(
        transfer.copyWith(
          status: TransferStatus.confirmed,
          updatedAt: _clock(),
          transactionSignature: signature,
          explorerUrl: _ethereumService.explorerUrlFor(signature).toString(),
          confirmedAt: _clock(),
          clearLastError: true,
        ),
      );
      return true;
    }

    final SignatureStatus? status = await _solanaService.getSignatureStatus(
      signature,
    );
    if (status == null) {
      return false;
    }
    if (status.err != null) {
      await _persistTransfer(
        transfer.copyWith(
          status: TransferStatus.broadcastFailed,
          updatedAt: _clock(),
          lastError: status.err.toString(),
        ),
      );
      return true;
    }

    final TransferStatus? nextStatus = _nextStatusForSignature(status);
    if (nextStatus == null) {
      return false;
    }

    await _persistTransfer(
      transfer.copyWith(
        status: nextStatus,
        updatedAt: _clock(),
        transactionSignature: signature,
        explorerUrl: _solanaService.explorerUrlFor(signature).toString(),
        confirmedAt: nextStatus == TransferStatus.confirmed ? _clock() : null,
        clearLastError: true,
      ),
    );
    return true;
  }

  bool _isExpiredBroadcastMessage(String message) {
    final String normalized = message.toLowerCase();
    return normalized.contains('expired before settlement') ||
        normalized.contains('blockhash not found') ||
        normalized.contains('block height exceeded') ||
        normalized.contains('transaction expired') ||
        normalized.contains('signature has expired');
  }

  Future<void> _refreshBitGoWalletData() async {
    try {
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to sync the BitGo wallet.',
        );
      }
      await _refreshBitGoBackendHealth();
      await _ensureBitGoSession();
      _syncBitGoWallets(await _bitGoClientService.fetchWallets());
      final BitGoWalletSummary? wallet = _bitgoWallets[_activeScopeKey];
      if (wallet == null) {
        throw FormatException(
          'BitGo demo wallet is not configured for ${_activeNetwork.labelFor(_activeChain)}.',
        );
      }
      _bitgoWallet = wallet;
      _mainBalanceLamports = wallet.balanceBaseUnits;
      _offlineBalanceLamports = 0;
      _mainBalances[_activeScopeKey] = _mainBalanceLamports;
      _offlineBalances[_activeScopeKey] = 0;
      _hasDevnet = true;
      _hasInternet = true;
      _statusMessage = null;
    } catch (error) {
      _hasDevnet = false;
      _hasInternet = false;
      _statusMessage = error.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _ensureBitGoSession() async {
    _bitGoClientService.endpoint = _bitgoEndpoint;
    if (_bitGoClientService.hasSession) {
      return;
    }
    final BitGoDemoSession session = await _bitGoClientService
        .createDemoSession();
    _syncBitGoWallets(session.wallets);
  }

  Future<void> _refreshBitGoBackendHealth({bool allowFailure = false}) async {
    try {
      final BitGoBackendHealth health = await _bitGoClientService.fetchHealth();
      _bitgoBackendMode = health.mode;
    } catch (_) {
      _bitgoBackendMode = BitGoBackendMode.unknown;
      if (!allowFailure) {
        rethrow;
      }
    }
  }

  bool _hasRealtimeSettlementPendingForActiveScope() {
    return _pendingTransfers.any((PendingTransfer transfer) {
      if (transfer.chain != _activeChain || transfer.network != _activeNetwork) {
        return false;
      }
      if (transfer.walletEngine == WalletEngine.local) {
        return transfer.transactionSignature != null &&
            (transfer.status == TransferStatus.sentOffline ||
                transfer.status == TransferStatus.receivedPendingBroadcast ||
                transfer.status == TransferStatus.broadcastSubmitted ||
                transfer.status == TransferStatus.broadcasting ||
                transfer.status == TransferStatus.broadcastFailed);
      }
      return transfer.walletEngine == WalletEngine.bitgo &&
          transfer.bitgoTransferId != null &&
          transfer.status != TransferStatus.confirmed &&
          transfer.status != TransferStatus.expired &&
          !transfer.status.isError;
    });
  }

  void _syncBitGoWallets(List<BitGoWalletSummary> wallets) {
    for (final BitGoWalletSummary wallet in wallets) {
      _bitgoWallets[_scopeKey(wallet.chain, wallet.network)] = wallet;
    }
    _bitgoWallet = _bitgoWallets[_activeScopeKey];
  }

  TransferStatus _bitgoStatusToTransferStatus(String rawStatus) {
    final String normalized = rawStatus.trim().toLowerCase();
    if (normalized == 'confirmed' || normalized == 'success') {
      return TransferStatus.confirmed;
    }
    if (normalized == 'submitted' ||
        normalized == 'broadcastsubmitted' ||
        normalized == 'accepted' ||
        normalized == 'broadcasted') {
      return TransferStatus.broadcastSubmitted;
    }
    if (normalized == 'failed' ||
        normalized == 'rejected' ||
        normalized == 'error') {
      return TransferStatus.broadcastFailed;
    }
    if (normalized == 'expired') {
      return TransferStatus.expired;
    }
    return TransferStatus.broadcasting;
  }

  bool _isValidAddressForChain(String address, ChainKind chain) {
    final String normalized = address.trim();
    return chain == ChainKind.solana
        ? isValidAddress(normalized)
        : _ethereumService.isValidAddress(normalized);
  }

  bool looksLikeEthereumEnsName(String value) {
    return _ethereumService.isEnsName(value);
  }

  Future<String> resolveEthereumEnsName(String value) {
    return _ethereumService.resolveEnsAddress(value);
  }

  int _estimatedEthereumFeeHeadroom() {
    final EthereumPreparedContext? context = _cachedEthereumContext;
    if (context == null) {
      return ChainKind.ethereum.fallbackFeeHeadroomBaseUnits;
    }
    return context.gasPriceWei * EthereumService.transferGasLimit;
  }

  String _cachedBlockhashKey(String scopeKey) => 'cached_blockhash_$scopeKey';

  String _cachedEthereumContextKey(String scopeKey) =>
      'cached_eth_context_$scopeKey';

  String _walletEngineKey(String scopeKey) => 'wallet_engine_$scopeKey';

  String _cleanErrorMessage(Object error) {
    final String text = error.toString();
    if (text.startsWith('FormatException: ')) {
      return text.replaceFirst('FormatException: ', '');
    }
    if (text.startsWith('StateError: ')) {
      return text.replaceFirst('StateError: ', '');
    }
    if (text.startsWith('HttpException: ')) {
      return text.replaceFirst('HttpException: ', '');
    }
    return text;
  }

  Future<void> _runTask(
    String status,
    Future<void> Function() operation,
  ) async {
    await _runTaskWithResult<void>(status, () async {
      await operation();
    });
  }

  Future<T> _runTaskWithResult<T>(
    String status,
    Future<T> Function() operation,
  ) async {
    _working = true;
    _statusMessage = status;
    notifyListeners();
    try {
      final T result = await operation();
      _statusMessage = null;
      return result;
    } catch (error) {
      _statusMessage = error.toString();
      rethrow;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    unawaited(_hotspotTransportService.stop());
    unawaited(_bleTransportService.dispose());
    super.dispose();
  }

  String _normalizeEndpoint(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }

  Future<String?> _resolveLocalIp() async {
    final String? wifiIp = await _networkInfo.getWifiIP();
    if (wifiIp != null && wifiIp.isNotEmpty) {
      return wifiIp;
    }

    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          if (address.isLoopback) {
            continue;
          }
          final String value = address.address;
          if (_isPrivateIpv4(value)) {
            return value;
          }
        }
      }
    } catch (_) {
      // Ignore interface enumeration failures and leave the local IP unset.
    }

    return null;
  }

  bool _isPrivateIpv4(String value) {
    final List<String> segments = value.split('.');
    if (segments.length != 4) {
      return false;
    }
    final int? first = int.tryParse(segments[0]);
    final int? second = int.tryParse(segments[1]);
    if (first == null || second == null) {
      return false;
    }
    if (first == 10) {
      return true;
    }
    if (first == 192 && second == 168) {
      return true;
    }
    return first == 172 && second >= 16 && second <= 31;
  }
}

class _TimelineNode {
  const _TimelineNode({required this.title, required this.caption});

  final String title;
  final String caption;
}
