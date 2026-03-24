import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
import '../services/device_auth_service.dart';
import '../services/ethereum_service.dart';
import '../services/fileverse_client_service.dart';
import '../services/home_widget_service.dart';
import '../services/hotspot_transport_service.dart';
import '../services/local_store.dart';
import '../services/offline_voucher_client_service.dart';
import '../services/offline_voucher_service.dart';
import '../services/price_service.dart';
import '../services/relay_client_service.dart';
import '../services/relay_crypto_service.dart';
import '../services/solana_service.dart';
import '../services/swap_service.dart';
import '../services/transport_contract.dart';
import '../services/ultrasonic_transport_service.dart';
import '../services/wallet_service.dart';

const double minimumFundingSol = 0.05;
const int solFeeHeadroomLamports = 10000;
const Duration blockhashFreshnessWindow = Duration(seconds: 75);
const Duration ethereumContextFreshnessWindow = Duration(minutes: 5);
const Duration readinessAutoRetryDelay = Duration(seconds: 30);
const Duration solanaReadinessAutoRefreshLead = Duration(seconds: 15);
const Duration evmReadinessAutoRefreshLead = Duration(minutes: 1);
const Duration realtimeSettlementPollInterval = Duration(seconds: 2);
const int realtimeSettlementPollAttempts = 12;
const Duration offlineVoucherClaimReceiptPollDelay = Duration(seconds: 15);
const Duration offlineVoucherClaimRetryBaseDelay = Duration(seconds: 20);
const Duration offlineVoucherClaimRetryMaxDelay = Duration(minutes: 10);
const int offlineVoucherClaimSponsorThreshold = 3;
const int erc20DiscoveryChunkSize = 100000;
const int erc20InitialDiscoveryLookbackBlocks = 2000000;
const String defaultSolanaTestnetRpcEndpoint = 'https://api.devnet.solana.com';
const String defaultSolanaMainnetRpcEndpoint =
    'https://api.mainnet-beta.solana.com';
const String defaultEthereumTestnetRpcEndpoint =
    'https://ethereum-sepolia-rpc.publicnode.com';
const String defaultEthereumMainnetRpcEndpoint =
    'https://ethereum-rpc.publicnode.com';
const String defaultBaseTestnetRpcEndpoint = 'https://sepolia.base.org';
const String defaultBaseMainnetRpcEndpoint = 'https://mainnet.base.org';
const String defaultBnbTestnetRpcEndpoint =
    'https://bsc-testnet-dataseed.bnbchain.org';
const String defaultBnbMainnetRpcEndpoint = 'https://bsc-dataseed.bnbchain.org';
const String defaultPolygonTestnetRpcEndpoint = 'https://polygon-amoy.drpc.org';
const String defaultPolygonMainnetRpcEndpoint = 'https://polygon.drpc.org';
const String legacyLocalBitGoBackendEndpoint = 'http://127.0.0.1:8788';
const String defaultBitGoBackendEndpoint =
    'https://bitsend-bitgo-backend.blueadarsh1.workers.dev';
const String defaultZeroExSwapApiKey = String.fromEnvironment(
  'ZERO_EX_API_KEY',
  defaultValue: '',
);

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
    DeviceAuthService? deviceAuthService,
    BitGoClientService? bitGoClientService,
    FileverseClientService? fileverseClientService,
    PriceService? priceService,
    SwapService? swapService,
    HomeScreenWidgetService? homeScreenWidgetService,
    RelayClientService? relayClientService,
    OfflineVoucherClientService? offlineVoucherClientService,
    OfflineVoucherService? offlineVoucherService,
    RelayCryptoService? relayCryptoService,
    UltrasonicTransportService? ultrasonicTransportService,
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
       _deviceAuthService = deviceAuthService ?? DeviceAuthService(),
       _bitGoClientService =
           bitGoClientService ??
           BitGoClientService(endpoint: defaultBitGoBackendEndpoint),
       _fileverseClientService =
           fileverseClientService ??
           FileverseClientService(endpoint: defaultBitGoBackendEndpoint),
       _priceService = priceService ?? PriceService(),
       _swapService = swapService ?? SwapService(),
       _homeScreenWidgetService =
           homeScreenWidgetService ?? HomeScreenWidgetService(),
       _relayClientService =
           relayClientService ??
           RelayClientService(endpoint: defaultBitGoBackendEndpoint),
       _offlineVoucherClientService =
           offlineVoucherClientService ??
           OfflineVoucherClientService(endpoint: defaultBitGoBackendEndpoint),
       _offlineVoucherService = offlineVoucherService ?? OfflineVoucherService(),
       _relayCryptoService = relayCryptoService ?? RelayCryptoService(),
       _ultrasonicTransportService =
           ultrasonicTransportService ?? UltrasonicTransportService(),
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
  final DeviceAuthService _deviceAuthService;
  final BitGoClientService _bitGoClientService;
  final FileverseClientService _fileverseClientService;
  final PriceService _priceService;
  SwapService? _swapService;
  final HomeScreenWidgetService _homeScreenWidgetService;
  final RelayClientService _relayClientService;
  final OfflineVoucherClientService _offlineVoucherClientService;
  final OfflineVoucherService _offlineVoucherService;
  final RelayCryptoService _relayCryptoService;
  final UltrasonicTransportService _ultrasonicTransportService;
  final Uuid _uuid;
  final DateTime Function() _clock;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<String>? _homeWidgetLaunchRouteSubscription;
  Timer? _autoReadinessRefreshTimer;

  bool _initialized = false;
  bool _initializing = false;
  bool _localPermissionsGranted = false;
  bool _ultrasonicPermissionsGranted = false;
  bool _ultrasonicSupported = false;
  bool _hasInternet = false;
  bool _hasLocalLink = false;
  bool _hasDevnet = false;
  bool _working = false;
  String? _statusMessage;
  String? _announcementMessage;
  int _announcementSerial = 0;
  bool _deviceAuthAvailable = false;
  bool _deviceAuthHasBiometricOption = false;
  bool _deviceUnlocked = true;
  String? _localIp;
  ChainKind _activeChain = ChainKind.ethereum;
  ChainNetwork _activeNetwork = ChainNetwork.testnet;
  WalletEngine _activeWalletEngine = WalletEngine.local;
  WalletProfile? _wallet;
  WalletProfile? _offlineWallet;
  final Map<ChainKind, WalletProfile?> _wallets = <ChainKind, WalletProfile?>{};
  final Map<ChainKind, WalletProfile?> _offlineWallets =
      <ChainKind, WalletProfile?>{};
  final Map<ChainKind, int> _selectedAccountSlots = <ChainKind, int>{};
  final Map<ChainKind, int> _accountCounts = <ChainKind, int>{};
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
  final Map<String, int> _mainTrackedAssetBalances = <String, int>{};
  final Map<String, int> _offlineTrackedAssetBalances = <String, int>{};
  final List<SendContact> _contacts = <SendContact>[];
  final List<TokenAllowanceEntry> _allowanceEntries =
      <TokenAllowanceEntry>[];
  final Map<String, Map<String, TrackedAssetDefinition>>
      _discoveredTrackedAssets =
      <String, Map<String, TrackedAssetDefinition>>{};
  final Map<String, int> _erc20DiscoveryHighWaterMarks = <String, int>{};
  final Map<String, List<NftHolding>> _nftHoldingsByScope =
      <String, List<NftHolding>>{};
  final Map<String, double> _usdPrices = <String, double>{};
  final Map<String, String> _rpcEndpoints = <String, String>{
    'solana:testnet': defaultSolanaTestnetRpcEndpoint,
    'solana:mainnet': defaultSolanaMainnetRpcEndpoint,
    'ethereum:testnet': defaultEthereumTestnetRpcEndpoint,
    'ethereum:mainnet': defaultEthereumMainnetRpcEndpoint,
    'base:testnet': defaultBaseTestnetRpcEndpoint,
    'base:mainnet': defaultBaseMainnetRpcEndpoint,
    'bnb:testnet': defaultBnbTestnetRpcEndpoint,
    'bnb:mainnet': defaultBnbMainnetRpcEndpoint,
    'polygon:testnet': defaultPolygonTestnetRpcEndpoint,
    'polygon:mainnet': defaultPolygonMainnetRpcEndpoint,
  };
  String _rpcEndpoint = defaultEthereumTestnetRpcEndpoint;
  String _bitgoEndpoint = defaultBitGoBackendEndpoint;
  String _swapApiKey = defaultZeroExSwapApiKey;
  int? _swapSlippageBps;
  SendDraft _sendDraft = const SendDraft();
  TransportKind _receiveTransport = TransportKind.hotspot;
  String? _lastSentTransferId;
  String? _lastReceivedTransferId;
  List<PendingTransfer> _pendingTransfers = <PendingTransfer>[];
  List<ReceiverDiscoveryItem> _bleReceivers = <ReceiverDiscoveryItem>[];
  bool _bleDiscovering = false;
  bool _ultrasonicListenerRunning = false;
  bool _autoRefreshingReadiness = false;
  PendingRelaySession? _activeUltrasonicSession;
  final Map<String, PendingRelaySession> _pendingRelaySessions =
      <String, PendingRelaySession>{};
  final Map<String, List<OfflineVoucherEscrowSession>>
      _offlineVoucherEscrowSessionsByScope =
      <String, List<OfflineVoucherEscrowSession>>{};
  final Map<String, String> _offlineVoucherSettlementContracts =
      <String, String>{};
  final Map<String, OfflineVoucherClaimAttempt> _offlineVoucherClaimAttempts =
      <String, OfflineVoucherClaimAttempt>{};
  bool _realtimeSettlementSyncRunning = false;
  bool _offlineVoucherClaimSyncRunning = false;
  String? _pendingHomeWidgetRoute;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get working => _working;
  String? get statusMessage => _statusMessage;
  bool get deviceAuthAvailable => _deviceAuthAvailable;
  bool get deviceAuthHasBiometricOption => _deviceAuthHasBiometricOption;
  bool get requiresBiometricSetup =>
      hasWallet && !_deviceAuthHasBiometricOption;
  bool get requiresDeviceUnlock =>
      hasWallet && _deviceAuthHasBiometricOption && !_deviceUnlocked;
  String get deviceUnlockMethodLabel => 'biometric unlock';
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
  bool get ultrasonicPermissionsGranted => _ultrasonicPermissionsGranted;
  bool get ultrasonicSupported => _ultrasonicSupported;
  bool get ultrasonicListenerRunning => _ultrasonicListenerRunning;
  bool get autoRefreshingReadiness => _autoRefreshingReadiness;
  PendingRelaySession? get activeUltrasonicSession => _activeUltrasonicSession;
  List<PendingRelaySession> get pendingRelaySessions =>
      List<PendingRelaySession>.unmodifiable(
        _pendingRelaySessions.values.toList(growable: false),
      );
  List<OfflineVoucherClaimAttempt> get pendingOfflineVoucherClaims =>
      List<OfflineVoucherClaimAttempt>.unmodifiable(
        _offlineVoucherClaimAttempts.values.toList(growable: false)
          ..sort(
            (OfflineVoucherClaimAttempt a, OfflineVoucherClaimAttempt b) =>
                a.nextAttemptAt.compareTo(b.nextAttemptAt),
          ),
      );
  List<OfflineVoucherEscrowSession> get offlineVoucherEscrowSessionsForActiveScope =>
      List<OfflineVoucherEscrowSession>.unmodifiable(
        (_offlineVoucherEscrowSessionsByScope[_activeScopeKey] ??
                const <OfflineVoucherEscrowSession>[])
            .where(
              (OfflineVoucherEscrowSession session) =>
                  !session.isRefunded &&
                  session.commitment.expiresAt.isAfter(_clock().toUtc()),
            )
            .toList(growable: false)
          ..sort(
            (
              OfflineVoucherEscrowSession a,
              OfflineVoucherEscrowSession b,
            ) => a.commitment.expiresAt.compareTo(b.commitment.expiresAt),
          ),
      );
  String get offlineVoucherSettlementContractAddress =>
      _offlineVoucherSettlementContracts[_activeScopeKey] ?? '';
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
  int get estimatedSendFeeHeadroomBaseUnits =>
      _activeWalletEngine == WalletEngine.bitgo
      ? 0
      : _activeChain == ChainKind.solana
      ? solFeeHeadroomLamports
      : _estimatedEthereumFeeHeadroom();
  double get estimatedSendFeeHeadroomSol =>
      _activeChain.amountFromBaseUnits(estimatedSendFeeHeadroomBaseUnits);
  int get estimatedOnlineSendFeeHeadroomBaseUnits =>
      _activeChain == ChainKind.solana
      ? solFeeHeadroomLamports
      : _activeChain.isEvm
      ? (_activeChain.fallbackFeeHeadroomBaseUnits *
                _sendDraft.gasSpeed.multiplier)
            .round()
      : _activeChain.fallbackFeeHeadroomBaseUnits;
  double get estimatedOnlineSendFeeHeadroomSol =>
      _activeChain.amountFromBaseUnits(estimatedOnlineSendFeeHeadroomBaseUnits);
  double get maxSendAmountSol {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      return mainBalanceSol;
    }
    final int maximumBaseUnits =
        offlineSpendableLamports - estimatedSendFeeHeadroomBaseUnits;
    if (maximumBaseUnits <= 0) {
      return 0;
    }
    return _activeChain.amountFromBaseUnits(maximumBaseUnits);
  }
  double get maxOnlineSendAmountSol {
    final int maximumBaseUnits =
        _mainBalanceLamports - estimatedOnlineSendFeeHeadroomBaseUnits;
    if (maximumBaseUnits <= 0) {
      return 0;
    }
    return _activeChain.amountFromBaseUnits(maximumBaseUnits);
  }
  double? get portfolioUsdTotal {
    if (!hasWallet) {
      return 0;
    }
    final Iterable<AssetPortfolioHolding> positiveHoldings = portfolioHoldings
        .where((AssetPortfolioHolding holding) => holding.totalBalance > 0);
    if (positiveHoldings.isEmpty) {
      return 0;
    }
    double total = 0;
    bool hasAnyPricedHolding = false;
    for (final AssetPortfolioHolding holding in positiveHoldings) {
      final double? price = _usdPriceForHolding(holding);
      if (price == null) {
        continue;
      }
      hasAnyPricedHolding = true;
      total += holding.totalBalance * price;
    }
    return hasAnyPricedHolding ? total : null;
  }

  double? get activeScopeUsdTotal {
    if (!hasWallet) {
      return 0;
    }
    final Iterable<AssetPortfolioHolding> positiveHoldings = portfolioHoldings
        .where(
          (AssetPortfolioHolding holding) =>
              holding.chain == _activeChain &&
              holding.network == _activeNetwork &&
              holding.totalBalance > 0,
        );
    if (positiveHoldings.isEmpty) {
      return 0;
    }
    double total = 0;
    bool hasAnyPricedHolding = false;
    for (final AssetPortfolioHolding holding in positiveHoldings) {
      final double? price = _usdPriceForHolding(holding);
      if (price == null) {
        continue;
      }
      hasAnyPricedHolding = true;
      total += holding.totalBalance * price;
    }
    return hasAnyPricedHolding ? total : null;
  }

  String get rpcEndpoint => _rpcEndpoint;
  String get bitgoEndpoint => _bitgoEndpoint;
  String get swapApiKey => _swapApiKey;
  bool get hasSwapApiKey => _swapApiKey.trim().isNotEmpty;
  int? get swapSlippageBps => _swapSlippageBps;
  bool get swapSupportedOnActiveScope =>
      _activeWalletEngine == WalletEngine.local &&
      _activeChain.isEvm &&
      _activeNetwork.isMainnet;
  String? get localIp => _localIp;
  String? get localEndpoint => _localIp == null
      ? null
      : 'http://$_localIp:${HotspotTransportService.port}';
  String? get announcementMessage => _announcementMessage;
  int get announcementSerial => _announcementSerial;
  SendDraft get sendDraft => _sendDraft;
  int get activeAccountSlot => _selectedAccountSlots[_activeChain] ?? 0;
  int get accountCountForActiveChain => _accountCounts[_activeChain] ?? 1;
  TransportKind get receiveTransport => _receiveTransport;
  List<ReceiverDiscoveryItem> get bleReceivers =>
      List<ReceiverDiscoveryItem>.unmodifiable(_bleReceivers);
  bool get bleDiscovering => _bleDiscovering;
  String? get lastSentTransferId => _lastSentTransferId;
  String? get lastReceivedTransferId => _lastReceivedTransferId;
  bool get listenerRunning =>
      _hotspotTransportService.isListening ||
      _bleTransportService.isListening ||
      _ultrasonicListenerRunning;
  bool get hotspotListenerRunning => _hotspotTransportService.isListening;
  bool get bleListenerRunning => _bleTransportService.isListening;
  List<SendContact> get contactsForActiveScope => List<SendContact>.unmodifiable(
    _contacts
        .where(
          (SendContact contact) =>
              contact.chain == _activeChain &&
              contact.network == _activeNetwork,
        )
        .toList(growable: false),
  );
  List<TokenAllowanceEntry> get allowanceEntriesForActiveScope =>
      List<TokenAllowanceEntry>.unmodifiable(
        _allowanceEntries
            .where(
              (TokenAllowanceEntry entry) =>
                  entry.chain == _activeChain &&
                  entry.network == _activeNetwork &&
                  entry.ownerAddress == (_wallet?.address ?? ''),
            )
            .toList(growable: false)
          ..sort(
            (TokenAllowanceEntry a, TokenAllowanceEntry b) =>
                b.updatedAt.compareTo(a.updatedAt),
          ),
      );
  List<NftHolding> get nftHoldingsForActiveScope =>
      List<NftHolding>.unmodifiable(
        _nftHoldingsByScope[_activeScopeKey] ?? const <NftHolding>[],
      );
  List<TrackedAssetDefinition> get trackedAssetsForActiveScope =>
      List<TrackedAssetDefinition>.unmodifiable(
        _trackedAssetsForScope(_activeChain, _activeNetwork),
      );
  List<TrackedAssetDefinition> get tokenAssetsForActiveScope =>
      List<TrackedAssetDefinition>.unmodifiable(
        _trackedAssetsForScope(_activeChain, _activeNetwork)
            .where((TrackedAssetDefinition asset) => !asset.isNative)
            .toList(growable: false),
      );

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

  List<AssetPortfolioHolding> get portfolioHoldings {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      final WalletSummary summary = walletSummary;
      if ((summary.primaryAddress == null || summary.primaryAddress!.isEmpty) &&
          summary.balanceSol <= 0) {
        return const <AssetPortfolioHolding>[];
      }
      return <AssetPortfolioHolding>[
        AssetPortfolioHolding(
          chain: summary.chain,
          network: summary.network,
          totalBalance: summary.balanceSol,
          mainBalance: summary.balanceSol,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId:
              '${summary.chain.name}:${summary.network.name}:native',
          symbol: summary.chain.assetDisplayLabel,
          displayName: summary.chain.label,
          assetDecimals: summary.chain.decimals,
          mainAddress: summary.primaryAddress,
        ),
      ];
    }

    final List<AssetPortfolioHolding> allHoldings = <AssetPortfolioHolding>[];
    for (final ChainKind chain in ChainKind.values) {
      final String scopeKey = _scopeKey(chain, _activeNetwork);
      final WalletProfile? mainWallet = _wallets[chain];
      final WalletProfile? protectedWallet = _offlineWallets[chain];
      final int mainBalanceBaseUnits = _mainBalances[scopeKey] ?? 0;
      final int protectedBalanceBaseUnits = _offlineBalances[scopeKey] ?? 0;
      final int reservedBalanceBaseUnits = _reservedOfflineBaseUnitsFor(
        chain: chain,
        network: _activeNetwork,
        protectedAddress: protectedWallet?.address,
      );
      final double totalBalance = chain.amountFromBaseUnits(
        mainBalanceBaseUnits + protectedBalanceBaseUnits,
      );
      if (mainWallet == null &&
          protectedWallet == null &&
          totalBalance <= 0 &&
          reservedBalanceBaseUnits <= 0) {
        continue;
      }
      final List<TrackedAssetDefinition> scopedAssets = _trackedAssetsForScope(
        chain,
        _activeNetwork,
      );
      final TrackedAssetDefinition nativeAsset = scopedAssets.firstWhere(
        (TrackedAssetDefinition asset) => asset.isNative,
      );
      allHoldings.add(
        AssetPortfolioHolding(
          chain: chain,
          network: _activeNetwork,
          totalBalance: totalBalance,
          mainBalance: chain.amountFromBaseUnits(mainBalanceBaseUnits),
          protectedBalance: chain.amountFromBaseUnits(
            protectedBalanceBaseUnits,
          ),
          spendableBalance: chain.amountFromBaseUnits(
            max(protectedBalanceBaseUnits - reservedBalanceBaseUnits, 0),
          ),
          reservedBalance: chain.amountFromBaseUnits(reservedBalanceBaseUnits),
          assetId: nativeAsset.id,
          symbol: nativeAsset.symbol,
          displayName: nativeAsset.displayName,
          assetDecimals: nativeAsset.decimals,
          mainAddress: mainWallet?.address,
          protectedAddress: protectedWallet?.address,
        ),
      );

      for (final TrackedAssetDefinition asset in scopedAssets.where(
        (TrackedAssetDefinition asset) => !asset.isNative,
      )) {
        final int mainTokenBalanceBaseUnits =
            _mainTrackedAssetBalances[asset.id] ?? 0;
        final int protectedTokenBalanceBaseUnits =
            _offlineTrackedAssetBalances[asset.id] ?? 0;
        final double tokenTotalBalance = asset.amountFromBaseUnits(
          mainTokenBalanceBaseUnits + protectedTokenBalanceBaseUnits,
        );
        if (tokenTotalBalance <= 0) {
          continue;
        }
        allHoldings.add(
          AssetPortfolioHolding(
            chain: chain,
            network: _activeNetwork,
            totalBalance: tokenTotalBalance,
            mainBalance: asset.amountFromBaseUnits(mainTokenBalanceBaseUnits),
            protectedBalance: asset.amountFromBaseUnits(
              protectedTokenBalanceBaseUnits,
            ),
            spendableBalance: asset.amountFromBaseUnits(
              protectedTokenBalanceBaseUnits,
            ),
            reservedBalance: 0,
            assetId: asset.id,
            symbol: asset.symbol,
            displayName: asset.displayName,
            assetDecimals: asset.decimals,
            contractAddress: asset.contractAddress,
            isNative: false,
            mainAddress: mainWallet?.address,
            protectedAddress: protectedWallet?.address,
          ),
        );
      }
    }

    final List<AssetPortfolioHolding> visibleHoldings = allHoldings
        .where(
          (AssetPortfolioHolding holding) =>
              holding.totalBalance > 0 || holding.chain == _activeChain,
        )
        .toList(growable: false);
    final List<AssetPortfolioHolding> sorted = (
      visibleHoldings.isNotEmpty ? visibleHoldings : allHoldings
    ).toList(growable: false)
      ..sort((AssetPortfolioHolding a, AssetPortfolioHolding b) {
        final int amountCompare = b.totalBalance.compareTo(a.totalBalance);
        if (amountCompare != 0) {
          return amountCompare;
        }
        return a.chain.label.compareTo(b.chain.label);
      });
    return List<AssetPortfolioHolding>.unmodifiable(sorted);
  }

  TrackedAssetDefinition get currentSendAssetDefinition =>
      _sendAssetDefinitionForDraft(_sendDraft);

  AssetPortfolioHolding get currentSendAssetHolding =>
      _holdingForTrackedAsset(currentSendAssetDefinition);

  List<AssetPortfolioHolding> get availableSendAssetHoldings {
    final List<TrackedAssetDefinition> assets = _trackedAssetsForScope(
      _sendDraft.chain,
      _sendDraft.network,
    );
    final bool tokenSendingEnabled =
        _sendDraft.walletEngine == WalletEngine.local &&
        _sendDraft.transport == TransportKind.online &&
        _sendDraft.chain.isEvm;
    final List<AssetPortfolioHolding> holdings = <AssetPortfolioHolding>[];
    for (final TrackedAssetDefinition asset in assets) {
      if (!tokenSendingEnabled && !asset.isNative) {
        continue;
      }
      if (!asset.isNative &&
          (_mainTrackedAssetBalances[asset.id] ?? 0) <= 0 &&
          asset.id != currentSendAssetDefinition.id) {
        continue;
      }
      holdings.add(_holdingForTrackedAsset(asset));
    }
    holdings.sort((AssetPortfolioHolding a, AssetPortfolioHolding b) {
      if (a.isNative != b.isNative) {
        return a.isNative ? -1 : 1;
      }
      final int balanceCompare = b.mainBalance.compareTo(a.mainBalance);
      if (balanceCompare != 0) {
        return balanceCompare;
      }
      return a.resolvedSymbol.compareTo(b.resolvedSymbol);
    });
    return List<AssetPortfolioHolding>.unmodifiable(holdings);
  }

  double get sourceBalanceForCurrentSendAsset {
    final TrackedAssetDefinition asset = currentSendAssetDefinition;
    if (!asset.isNative) {
      return asset.amountFromBaseUnits(_mainTrackedAssetBalances[asset.id] ?? 0);
    }
    if (_sendDraft.walletEngine == WalletEngine.bitgo) {
      return mainBalanceSol;
    }
    if (_sendDraft.transport == TransportKind.online) {
      return mainBalanceSol;
    }
    return offlineSpendableBalanceSol;
  }

  double get maxSendAmountForCurrentAsset {
    final TrackedAssetDefinition asset = currentSendAssetDefinition;
    if (asset.isNative) {
      if (_sendDraft.walletEngine == WalletEngine.bitgo) {
        return mainBalanceSol;
      }
      return _sendDraft.transport == TransportKind.online
          ? maxOnlineSendAmountSol
          : maxSendAmountSol;
    }
    if (_sendDraft.walletEngine != WalletEngine.local ||
        _sendDraft.transport != TransportKind.online) {
      return 0;
    }
    if (_mainBalanceLamports <= estimatedOnlineSendFeeHeadroomBaseUnits) {
      return 0;
    }
    return asset.amountFromBaseUnits(_mainTrackedAssetBalances[asset.id] ?? 0);
  }

  double? _usdPriceForHolding(AssetPortfolioHolding holding) {
    return _usdPrices[holding.resolvedSymbol.toUpperCase()];
  }

  double? usdPriceForHolding(AssetPortfolioHolding holding) {
    return _usdPriceForHolding(holding);
  }

  Future<void> _refreshPortfolioUsdPrices() async {
    if (!_hasInternet) {
      return;
    }
    final Set<String> symbols = portfolioHoldings
        .where((AssetPortfolioHolding holding) => holding.totalBalance > 0)
        .map((AssetPortfolioHolding holding) => holding.resolvedSymbol.toUpperCase())
        .toSet();
    if (symbols.isEmpty) {
      return;
    }
    try {
      final Map<String, double> prices = await _priceService.fetchUsdPrices(
        symbols,
      );
      _usdPrices.addAll(prices);
    } catch (_) {
      // Keep the last known price cache if live refresh fails.
    }
  }

  List<PendingTransfer> get transferHistory {
    final List<PendingTransfer> sorted =
        List<PendingTransfer>.from(_pendingTransfers)..sort(
          (PendingTransfer a, PendingTransfer b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
    return sorted;
  }

  List<PendingTransfer> get pendingTransfers => transferHistory
      .where((PendingTransfer transfer) => transfer.isVisibleInPendingQueue)
      .toList(growable: false);
  String? get pendingHomeWidgetRoute => _pendingHomeWidgetRoute;

  PendingTransfer? get lastSentTransfer =>
      _lastSentTransferId == null ? null : transferById(_lastSentTransferId!);

  PendingTransfer? get lastReceivedTransfer => _lastReceivedTransferId == null
      ? null
      : transferById(_lastReceivedTransferId!);

  String get bootRoute {
    if (!hasWallet) {
      return '/onboarding/welcome';
    }
    if (requiresBiometricSetup || requiresDeviceUnlock) {
      return '/unlock';
    }
    return '/home';
  }

  String get _activeScopeKey => _scopeKey(_activeChain, _activeNetwork);
  String get _activeReadinessScopeKey =>
      '${_activeScopeKey}:account_$activeAccountSlot';

  String _scopeKey(ChainKind chain, ChainNetwork network) {
    return '${chain.name}:${network.name}';
  }

  SwapService get _effectiveSwapService {
    return _swapService ??= SwapService(apiKey: _swapApiKey);
  }

  int? _normalizeSwapSlippageBps(int? value) {
    if (value == null || value <= 0) {
      return null;
    }
    return value.clamp(30, 10000);
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
      (ChainKind.base, ChainNetwork.testnet) => defaultBaseTestnetRpcEndpoint,
      (ChainKind.base, ChainNetwork.mainnet) => defaultBaseMainnetRpcEndpoint,
      (ChainKind.bnb, ChainNetwork.testnet) => defaultBnbTestnetRpcEndpoint,
      (ChainKind.bnb, ChainNetwork.mainnet) => defaultBnbMainnetRpcEndpoint,
      (ChainKind.polygon, ChainNetwork.testnet) =>
        defaultPolygonTestnetRpcEndpoint,
      (ChainKind.polygon, ChainNetwork.mainnet) =>
        defaultPolygonMainnetRpcEndpoint,
    };
  }

  void _handleHomeWidgetRoute(String route) {
    final String normalized = route.trim();
    if (normalized.isEmpty) {
      return;
    }
    _pendingHomeWidgetRoute = normalized;
    notifyListeners();
  }

  String _homeWidgetStatusTone(WalletSummary summary) {
    if (!hasWallet) {
      return 'muted';
    }
    if (summary.walletEngine == WalletEngine.bitgo) {
      return 'info';
    }
    if (summary.offlineBalanceSol <= 0) {
      return 'warning';
    }
    if (summary.readyForOffline) {
      return 'ready';
    }
    return 'warning';
  }

  HomeScreenWidgetSnapshot _buildHomeWidgetSnapshot() {
    final WalletSummary summary = walletSummary;
    final bool usingBitGo = summary.walletEngine == WalletEngine.bitgo;
    final double totalNativeBalance = usingBitGo
        ? summary.balanceSol
        : summary.balanceSol + summary.offlineBalanceSol;
    final double? scopeUsdTotal = activeScopeUsdTotal;
    final String primaryValue = scopeUsdTotal == null
        ? Formatters.asset(totalNativeBalance, summary.chain)
        : Formatters.usd(scopeUsdTotal);
    final String supportingLabel = !hasWallet
        ? 'Open Bitsend to finish setup'
        : 'Est. ${summary.chain.label} value';
    final String primaryDetail = hasWallet
        ? 'Main ${Formatters.asset(summary.balanceSol, summary.chain)}'
        : 'Main --';
    final String secondaryDetail = !hasWallet
        ? 'Offline --'
        : usingBitGo
        ? 'Available ${Formatters.asset(summary.balanceSol, summary.chain)}'
        : 'Can send ${Formatters.asset(summary.offlineAvailableSol, summary.chain)}';
    final String walletLabel = !hasWallet
        ? 'Set up a wallet to use quick actions.'
        : usingBitGo
        ? (summary.primaryDisplayLabel ??
              Formatters.shortAddress(summary.primaryAddress ?? ''))
        : summary.offlineWalletAddress == null
        ? 'Offline signer unavailable'
        : 'Signer ${Formatters.shortAddress(summary.offlineWalletAddress!)}';
    final String statusLabel = !hasWallet
        ? 'Set up'
        : usingBitGo
        ? 'BitGo'
        : summary.offlineBalanceSol <= 0
        ? 'Needs funds'
        : summary.readyForOffline
        ? 'Ready'
        : 'Syncing';
    return HomeScreenWidgetSnapshot(
      chainLabel: summary.chain.label,
      networkLabel: summary.network.shortLabelFor(summary.chain),
      primaryValue: primaryValue,
      supportingLabel: supportingLabel,
      primaryDetail: primaryDetail,
      secondaryDetail: secondaryDetail,
      statusLabel: statusLabel,
      statusTone: _homeWidgetStatusTone(summary),
      walletLabel: walletLabel,
    );
  }

  Future<void> _syncHomeScreenWidgets() async {
    await _homeScreenWidgetService.syncSnapshot(_buildHomeWidgetSnapshot());
  }

  void clearPendingHomeWidgetRoute() {
    _pendingHomeWidgetRoute = null;
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
      _fileverseClientService.endpoint = _bitgoEndpoint;
      final String? savedSwapApiKey = await _store.loadSetting<String>(
        'swap_api_key',
      );
      _swapApiKey =
          savedSwapApiKey == null || savedSwapApiKey.trim().isEmpty
          ? defaultZeroExSwapApiKey
          : savedSwapApiKey.trim();
      _swapSlippageBps = _normalizeSwapSlippageBps(
        await _store.loadSetting<int>('swap_slippage_bps'),
      );
      _effectiveSwapService.apiKey = _swapApiKey;
      _relayClientService.endpoint = _bitgoEndpoint;
      _offlineVoucherClientService.endpoint = _bitgoEndpoint;
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
          ? ChainKind.ethereum
          : ChainKind.values.byName(savedChainName);
      _activeNetwork = savedNetworkName == null
          ? ChainNetwork.testnet
          : ChainNetwork.values.byName(savedNetworkName);
      await _loadAccountPreferences();
      await _loadWalletEngineForActiveScope();
      await _reloadWalletProfiles();
      await _refreshDeviceAuthSupport(lockWallet: true);
      _applyActiveChainSnapshot();
      _sendDraft = SendDraft(
        chain: _activeChain,
        network: _activeNetwork,
        walletEngine: _activeWalletEngine,
      );
      await _loadCachedReadinessForActiveScope();
      _pendingTransfers = await _store.loadTransfers();
      await _loadPendingRelaySessions();
      await _loadOfflineVoucherEscrowSessions();
      await _loadOfflineVoucherSettlementContracts();
      await _loadOfflineVoucherClaimAttempts();
      await _loadContacts();
      await _loadAllowanceEntries();
      await _loadDiscoveredTrackedAssets();
      await _loadErc20DiscoveryHighWaterMarks();
      await _refreshLocalPermissions();
      _ultrasonicSupported = await _ultrasonicTransportService.isSupported() ||
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
      _homeWidgetLaunchRouteSubscription ??= _homeScreenWidgetService
          .launchRoutes
          .listen(_handleHomeWidgetRoute);
      _pendingHomeWidgetRoute ??=
          await _homeScreenWidgetService.consumePendingLaunchRoute();

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        _,
      ) async {
        await _runStartupNetworkSync();
      });

      _initialized = true;
      await _syncHomeScreenWidgets();
      unawaited(_runStartupNetworkSync());
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> createWallet() async {
    await _ensureMandatoryBiometricSetup(
      action:
          'Set up fingerprint or face unlock on this device before creating a Bitsend wallet.',
    );
    await _walletService.createWallet();
    await _reloadWalletProfiles();
    await _refreshDeviceAuthSupport(lockWallet: true);
    _applyActiveChainSnapshot();
    await _syncHomeScreenWidgets();
    notifyListeners();
    final bool unlocked = await authenticateDevice(
      reason: 'Confirm biometric unlock to finish setting up Bitsend.',
      forcePrompt: true,
    );
    if (!unlocked) {
      throw const FormatException(
        'Biometric unlock is required to finish setting up Bitsend.',
      );
    }
    notifyListeners();
  }

  Future<void> restoreWallet(String seedPhrase) async {
    await _ensureMandatoryBiometricSetup(
      action:
          'Set up fingerprint or face unlock on this device before restoring a Bitsend wallet.',
    );
    await _walletService.restoreWallet(seedPhrase);
    await _reloadWalletProfiles();
    if (_activeNetwork != ChainNetwork.mainnet) {
      _activeNetwork = ChainNetwork.mainnet;
      await _loadWalletEngineForActiveScope();
      _sendDraft = _sendDraft.copyWith(
        chain: _activeChain,
        network: _activeNetwork,
        walletEngine: _activeWalletEngine,
        assetId: _defaultSendAssetIdFor(_activeChain, _activeNetwork),
        amountSol: 0,
        clearReceiver: true,
      );
      await _store.saveSetting('active_network', _activeNetwork.name);
    }
    await _refreshDeviceAuthSupport(lockWallet: true);
    _applyActiveChainSnapshot();
    await _syncHomeScreenWidgets();
    notifyListeners();
    final bool unlocked = await authenticateDevice(
      reason: 'Confirm biometric unlock to finish restoring Bitsend.',
      forcePrompt: true,
    );
    if (!unlocked) {
      throw const FormatException(
        'Biometric unlock is required to finish restoring Bitsend.',
      );
    }
    notifyListeners();
  }

  Future<void> _refreshDeviceAuthSupport({required bool lockWallet}) async {
    if (!hasWallet) {
      final DeviceAuthSupport support = await _deviceAuthService.loadSupport();
      _deviceAuthAvailable = support.isAvailable;
      _deviceAuthHasBiometricOption = support.hasBiometricOption;
      _deviceUnlocked = true;
      return;
    }
    final DeviceAuthSupport support = await _deviceAuthService.loadSupport();
    _deviceAuthAvailable = support.isAvailable;
    _deviceAuthHasBiometricOption = support.hasBiometricOption;
    _deviceUnlocked = !_deviceAuthHasBiometricOption || !lockWallet;
  }

  Future<bool> authenticateDevice({
    String? reason,
    bool forcePrompt = false,
  }) async {
    if (!hasWallet) {
      return true;
    }
    if (!_deviceAuthHasBiometricOption) {
      throw const FormatException(
        'Bitsend requires fingerprint or face unlock on this device. Set it up in system settings to continue.',
      );
    }
    if (_deviceUnlocked && !forcePrompt) {
      return true;
    }
    final bool unlocked = await _deviceAuthService.authenticate(
      reason:
          reason ??
          'Unlock Bitsend with fingerprint or face unlock.',
    );
    if (unlocked) {
      _deviceUnlocked = true;
      notifyListeners();
    }
    return unlocked;
  }

  void lockWalletForSession() {
    if (!hasWallet || !_deviceAuthHasBiometricOption) {
      return;
    }
    _deviceUnlocked = false;
    notifyListeners();
  }

  Future<void> _ensureMandatoryBiometricSetup({
    required String action,
  }) async {
    final DeviceAuthSupport support = await _deviceAuthService.loadSupport();
    _deviceAuthAvailable = support.isAvailable;
    _deviceAuthHasBiometricOption = support.hasBiometricOption;
    if (!support.hasBiometricOption) {
      _deviceUnlocked = false;
      notifyListeners();
      throw FormatException(action);
    }
  }

  Future<bool> openSystemSettings() {
    return openAppSettings();
  }

  Future<void> setActiveChain(ChainKind chain) async {
    if (_activeChain == chain) {
      return;
    }
    if (listenerRunning) {
      await _hotspotTransportService.stop();
      await _bleTransportService.stop();
      await _ultrasonicTransportService.stop();
      _ultrasonicListenerRunning = false;
    }
    _activeChain = chain;
    await _loadWalletEngineForActiveScope();
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = _sendDraft.copyWith(
      chain: chain,
      network: _activeNetwork,
      walletEngine: _activeWalletEngine,
      assetId: _defaultSendAssetIdFor(chain, _activeNetwork),
      amountSol: 0,
      clearReceiver: true,
    );
    _applyActiveChainSnapshot();
    _syncActiveUltrasonicSessionForScope();
    await _store.saveSetting('active_chain', chain.name);
    await _loadCachedReadinessForActiveScope();
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      await _syncHomeScreenWidgets();
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
      await _ultrasonicTransportService.stop();
      _ultrasonicListenerRunning = false;
    }
    _activeNetwork = network;
    await _loadWalletEngineForActiveScope();
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = _sendDraft.copyWith(
      chain: _activeChain,
      network: network,
      walletEngine: _activeWalletEngine,
      assetId: _defaultSendAssetIdFor(_activeChain, network),
      amountSol: 0,
      clearReceiver: true,
    );
    _applyActiveChainSnapshot();
    _syncActiveUltrasonicSessionForScope();
    await _store.saveSetting('active_network', network.name);
    await _loadCachedReadinessForActiveScope();
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      await _syncHomeScreenWidgets();
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
      await _ultrasonicTransportService.stop();
      _ultrasonicListenerRunning = false;
    }
    _activeWalletEngine = engine;
    _walletEngines[_activeScopeKey] = engine;
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _sendDraft = _sendDraft.copyWith(
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: engine,
      assetId: _defaultSendAssetIdFor(_activeChain, _activeNetwork),
      amountSol: 0,
      clearReceiver: true,
    );
    _syncActiveUltrasonicSessionForScope();
    await _store.saveSetting(_walletEngineKey(_activeScopeKey), engine.name);
    await _refreshConnectivityState();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      await _syncHomeScreenWidgets();
      notifyListeners();
    }
  }

  Future<List<WalletAccountSummary>> loadAccountSummariesForActiveChain() async {
    final int total = accountCountForActiveChain;
    final List<WalletAccountSummary> summaries = <WalletAccountSummary>[];
    for (int slot = 0; slot < total; slot += 1) {
      final WalletProfile? mainWallet = await _walletService.loadWalletForSlot(
        chain: _activeChain,
        slot: slot,
      );
      final WalletProfile? protectedWallet =
          await _walletService.loadOfflineWalletForSlot(
            chain: _activeChain,
            slot: slot,
          );
      summaries.add(
        WalletAccountSummary(
          chain: _activeChain,
          slotIndex: slot,
          mainWallet: mainWallet,
          protectedWallet: protectedWallet,
          selected: slot == activeAccountSlot,
        ),
      );
    }
    return summaries;
  }

  Future<void> switchActiveAccountSlot(int slot) async {
    final int normalized = slot < 0 ? 0 : slot;
    final int maxCount = accountCountForActiveChain;
    if (normalized >= maxCount || normalized == activeAccountSlot) {
      return;
    }
    _selectedAccountSlots[_activeChain] = normalized;
    await _saveAccountPreferences();
    _nftHoldingsByScope.remove(_activeScopeKey);
    await _reloadWalletProfiles();
    _applyActiveChainSnapshot();
    await _loadCachedReadinessForActiveScope();
    _syncActiveUltrasonicSessionForScope();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      await _syncHomeScreenWidgets();
      notifyListeners();
    }
  }

  Future<void> addAccountForActiveChain() async {
    final int nextSlot = accountCountForActiveChain;
    _accountCounts[_activeChain] = nextSlot + 1;
    _selectedAccountSlots[_activeChain] = nextSlot;
    await _saveAccountPreferences();
    _nftHoldingsByScope.remove(_activeScopeKey);
    await _reloadWalletProfiles();
    _applyActiveChainSnapshot();
    await _loadCachedReadinessForActiveScope();
    _syncActiveUltrasonicSessionForScope();
    if (_wallet != null) {
      await refreshWalletData();
    } else {
      await _syncHomeScreenWidgets();
      notifyListeners();
    }
  }

  Future<void> _reloadWalletProfiles() async {
    for (final ChainKind chain in ChainKind.values) {
      final int slot = _selectedAccountSlots[chain] ?? 0;
      _wallets[chain] = await _walletService.loadWalletForSlot(
        chain: chain,
        slot: slot,
      );
      _offlineWallets[chain] = await _walletService.loadOfflineWalletForSlot(
        chain: chain,
        slot: slot,
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
      _ethereumService.chain = _activeChain;
      _ethereumService.rpcEndpoint = _rpcEndpoint;
      _ethereumService.network = _activeNetwork;
    }
    _bitGoClientService.endpoint = _bitgoEndpoint;
    _fileverseClientService.endpoint = _bitgoEndpoint;
    _relayClientService.endpoint = _bitgoEndpoint;
    _scheduleAutoReadinessRefresh();
  }

  Future<void> _loadWalletEngineForActiveScope() async {
    _activeWalletEngine =
        await _store.loadSetting<String>(_walletEngineKey(_activeScopeKey)) ==
            WalletEngine.bitgo.name
        ? WalletEngine.bitgo
        : WalletEngine.local;
    _walletEngines[_activeScopeKey] = _activeWalletEngine;
  }

  Future<void> _loadAccountPreferences() async {
    final Map<String, dynamic>? rawSlots = await _store
        .loadSetting<Map<String, dynamic>>(_selectedAccountSlotsKey);
    final Map<String, dynamic>? rawCounts = await _store
        .loadSetting<Map<String, dynamic>>(_accountCountsKey);
    _selectedAccountSlots.clear();
    _accountCounts.clear();
    for (final ChainKind chain in ChainKind.values) {
      final int slot = rawSlots == null
          ? 0
          : _parseFlexibleInt(rawSlots[chain.name]);
      final int count = rawCounts == null
          ? 1
          : _parseFlexibleInt(rawCounts[chain.name]);
      _selectedAccountSlots[chain] = slot < 0 ? 0 : slot;
      _accountCounts[chain] = count <= 0 ? 1 : count;
    }
  }

  Future<void> _saveAccountPreferences() async {
    await _store.saveSetting(
      _selectedAccountSlotsKey,
      <String, int>{
        for (final ChainKind chain in ChainKind.values)
          chain.name: _selectedAccountSlots[chain] ?? 0,
      },
    );
    await _store.saveSetting(
      _accountCountsKey,
      <String, int>{
        for (final ChainKind chain in ChainKind.values)
          chain.name: _accountCounts[chain] ?? 1,
      },
    );
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
      await _refreshPortfolioUsdPrices();
      await _syncHomeScreenWidgets();
      notifyListeners();
      return;
    }
    if (_wallet == null) {
      _scheduleAutoReadinessRefresh();
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
      await _refreshTrackedAssetBalancesForChain(
        chain: _activeChain,
        network: _activeNetwork,
        wallet: _wallet,
        offlineWallet: _offlineWallet,
      );
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
      await _refreshPortfolioUsdPrices();
    } catch (error) {
      _hasDevnet = false;
      _hasInternet = false;
      _statusMessage = error.toString();
    }
    _scheduleAutoReadinessRefresh();
    await _syncHomeScreenWidgets();
    notifyListeners();
  }

  Future<void> refreshPortfolioBalances() async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      await refreshWalletData();
      return;
    }

    final List<ChainKind> chains = ChainKind.values.where((ChainKind chain) {
      final String scopeKey = _scopeKey(chain, _activeNetwork);
      return _wallets[chain] != null ||
          _offlineWallets[chain] != null ||
          (_mainBalances[scopeKey] ?? 0) > 0 ||
          (_offlineBalances[scopeKey] ?? 0) > 0;
    }).toList(growable: false);
    if (chains.isEmpty) {
      return;
    }

    bool refreshedAny = false;
    String? firstFailure;
    for (final ChainKind chain in chains) {
      final WalletProfile? mainWallet = _wallets[chain];
      final WalletProfile? protectedWallet = _offlineWallets[chain];
      try {
        final (int mainBalanceBaseUnits, int protectedBalanceBaseUnits) =
            await _fetchBalancesForChain(
              chain: chain,
              network: _activeNetwork,
              wallet: mainWallet,
              offlineWallet: protectedWallet,
            );
        final String scopeKey = _scopeKey(chain, _activeNetwork);
        _mainBalances[scopeKey] = mainBalanceBaseUnits;
        _offlineBalances[scopeKey] = protectedBalanceBaseUnits;
        await _refreshTrackedAssetBalancesForChain(
          chain: chain,
          network: _activeNetwork,
          wallet: mainWallet,
          offlineWallet: protectedWallet,
        );
        refreshedAny = true;
      } catch (error) {
        firstFailure ??= error.toString();
      }
    }

    if (refreshedAny) {
      _hasDevnet = true;
      _hasInternet = true;
      _statusMessage = null;
      await _refreshPortfolioUsdPrices();
    } else if (firstFailure != null) {
      _hasDevnet = false;
      _hasInternet = false;
      _statusMessage = firstFailure;
    }

    _applyActiveChainSnapshot();
    await _syncHomeScreenWidgets();
    notifyListeners();
  }

  Future<void> requestAirdrop({bool toOfflineWallet = false}) async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      throw const FormatException(
        'BitGo mode uses the backend-managed wallet. Fund it through the BitGo wallet flow instead of local airdrops.',
      );
    }
    if (_activeChain != ChainKind.solana) {
      throw FormatException(
        '${_activeChain.label} faucet support is not built into the app yet. Use a ${_activeNetwork.labelFor(_activeChain)} faucet and then refresh the balance.',
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

  Future<(int mainBalanceBaseUnits, int protectedBalanceBaseUnits)>
  _fetchBalancesForChain({
    required ChainKind chain,
    required ChainNetwork network,
    required WalletProfile? wallet,
    required WalletProfile? offlineWallet,
  }) async {
    final String endpoint =
        _rpcEndpoints[_scopeKey(chain, network)] ??
        _defaultRpcEndpointFor(chain, network);
    if (chain == ChainKind.solana) {
      final SolanaService service = SolanaService(rpcEndpoint: endpoint)
        ..network = network;
      return (
        wallet == null ? 0 : await service.getBalanceLamports(wallet.address),
        offlineWallet == null
            ? 0
            : await service.getBalanceLamports(offlineWallet.address),
      );
    }

    final EthereumService service = EthereumService(rpcEndpoint: endpoint)
      ..chain = chain
      ..network = network;
    return (
      wallet == null ? 0 : await service.getBalanceBaseUnits(wallet.address),
      offlineWallet == null
          ? 0
          : await service.getBalanceBaseUnits(offlineWallet.address),
    );
  }

  Future<void> _refreshTrackedAssetBalancesForChain({
    required ChainKind chain,
    required ChainNetwork network,
    required WalletProfile? wallet,
    required WalletProfile? offlineWallet,
  }) async {
    if (chain == ChainKind.solana) {
      return;
    }
    final String endpoint =
        _rpcEndpoints[_scopeKey(chain, network)] ??
        _defaultRpcEndpointFor(chain, network);
    final EthereumService service = EthereumService(rpcEndpoint: endpoint)
      ..chain = chain
      ..network = network;
    await _discoverTrackedAssetsForChain(
      chain: chain,
      network: network,
      wallet: wallet,
      offlineWallet: offlineWallet,
      service: service,
    );
    final List<TrackedAssetDefinition> tokenAssets = _trackedAssetsForScope(
      chain,
      network,
    ).where((TrackedAssetDefinition asset) => !asset.isNative).toList(
      growable: false,
    );
    if (tokenAssets.isEmpty) {
      return;
    }

    for (final TrackedAssetDefinition asset in tokenAssets) {
      try {
        final int mainBalanceBaseUnits = wallet == null
            ? 0
            : await service.getTokenBalanceBaseUnits(
                ownerAddress: wallet.address,
                contractAddress: asset.contractAddress!,
              );
        final int protectedBalanceBaseUnits = offlineWallet == null
            ? 0
            : await service.getTokenBalanceBaseUnits(
                ownerAddress: offlineWallet.address,
                contractAddress: asset.contractAddress!,
              );
        _mainTrackedAssetBalances[asset.id] = mainBalanceBaseUnits;
        _offlineTrackedAssetBalances[asset.id] = protectedBalanceBaseUnits;
      } catch (_) {
        _mainTrackedAssetBalances.putIfAbsent(asset.id, () => 0);
        _offlineTrackedAssetBalances.putIfAbsent(asset.id, () => 0);
      }
    }
  }

  List<TrackedAssetDefinition> _trackedAssetsForScope(
    ChainKind chain,
    ChainNetwork network,
  ) {
    final Map<String, TrackedAssetDefinition> merged =
        <String, TrackedAssetDefinition>{};
    for (final TrackedAssetDefinition asset in trackedAssetsForScope(
      chain,
      network,
    )) {
      merged[trackedAssetLookupKey(asset)] = asset;
    }
    final Map<String, TrackedAssetDefinition>? discovered =
        _discoveredTrackedAssets[_scopeKey(chain, network)];
    if (discovered != null) {
      for (final TrackedAssetDefinition asset in discovered.values) {
        if (asset.isNative) {
          continue;
        }
        merged.putIfAbsent(trackedAssetLookupKey(asset), () => asset);
      }
    }
    return merged.values.toList(growable: false);
  }

  Future<void> _discoverTrackedAssetsForChain({
    required ChainKind chain,
    required ChainNetwork network,
    required WalletProfile? wallet,
    required WalletProfile? offlineWallet,
    required EthereumService service,
  }) async {
    final List<String> ownerAddresses = <String>[
      if (wallet != null) wallet.address,
      if (offlineWallet != null &&
          offlineWallet.address != wallet?.address)
        offlineWallet.address,
    ];
    if (ownerAddresses.isEmpty) {
      return;
    }

    final String scopeKey = _scopeKey(chain, network);
    final Map<String, TrackedAssetDefinition> discoveredAssetsForScope =
        _discoveredTrackedAssets.putIfAbsent(
          scopeKey,
          () => <String, TrackedAssetDefinition>{},
        );
    final Set<String> knownContracts = <String>{
      for (final TrackedAssetDefinition asset in _trackedAssetsForScope(
        chain,
        network,
      ))
        if (!asset.isNative && asset.contractAddress != null)
          asset.contractAddress!.trim().toLowerCase(),
    };

    bool assetsChanged = false;
    bool cursorsChanged = false;
    int? latestBlock;
    for (final String ownerAddress in ownerAddresses) {
      try {
        latestBlock ??= await service.getBlockNumber();
        final String cursorKey = _erc20DiscoveryCursorKey(
          scopeKey,
          ownerAddress,
        );
        final int fromBlock =
            _erc20DiscoveryHighWaterMarks[cursorKey] == null
            ? _initialErc20DiscoveryStartBlock(latestBlock!)
            : _erc20DiscoveryHighWaterMarks[cursorKey]! + 1;
        if (fromBlock > latestBlock!) {
          continue;
        }
        final Set<String> discoveredContracts =
            await service.discoverErc20Contracts(
              ownerAddress: ownerAddress,
              fromBlock: fromBlock,
              toBlock: latestBlock,
              chunkSize: erc20DiscoveryChunkSize,
            );
        for (final String contractAddress in discoveredContracts) {
          final String normalized = contractAddress.trim().toLowerCase();
          if (normalized.isEmpty || knownContracts.contains(normalized)) {
            continue;
          }
          try {
            final TrackedAssetDefinition asset = await service.describeErc20Asset(
              contractAddress,
            );
            discoveredAssetsForScope[trackedAssetLookupKey(asset)] = asset;
            knownContracts.add(normalized);
            assetsChanged = true;
          } catch (_) {
            // Skip malformed token contracts and keep scanning others.
          }
        }
        _erc20DiscoveryHighWaterMarks[cursorKey] = latestBlock!;
        cursorsChanged = true;
      } catch (_) {
        // ERC-20 discovery is best-effort; keep known assets if scanning fails.
      }
    }

    if (assetsChanged) {
      await _saveDiscoveredTrackedAssets();
    }
    if (cursorsChanged) {
      await _saveErc20DiscoveryHighWaterMarks();
    }
  }

  int _reservedOfflineBaseUnitsFor({
    required ChainKind chain,
    required ChainNetwork network,
    required String? protectedAddress,
  }) {
    if (protectedAddress == null || protectedAddress.isEmpty) {
      return 0;
    }
    return _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.senderAddress == protectedAddress &&
              transfer.chain == chain &&
              transfer.network == network &&
              transfer.reservesOfflineFunds;
        })
        .fold<int>(
          0,
          (int total, PendingTransfer transfer) =>
              total + transfer.amountLamports,
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
              : 'Internet is required to fetch a fresh ${_activeChain.label} nonce and gas quote.',
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

  Future<void> topUpOfflineWallet(double amount, {String? assetId}) async {
    if (_activeWalletEngine == WalletEngine.bitgo) {
      throw const FormatException(
        'BitGo mode does not use the local offline wallet.',
      );
    }
    final TrackedAssetDefinition asset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: assetId ?? '',
    );
    await _runTask('Moving ${asset.symbol} into the offline wallet...', () async {
      if (_wallet == null || _offlineWallet == null) {
        throw const FormatException('Create or restore a wallet first.');
      }
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to top up the offline wallet.',
        );
      }

      final int amountBaseUnits = asset.amountToBaseUnits(amount);
      if (amountBaseUnits <= 0) {
        throw const FormatException('Enter an amount greater than zero.');
      }

      if (_activeChain == ChainKind.solana) {
        if (!asset.isNative) {
          throw const FormatException(
            'Solana offline top-up currently supports SOL only.',
          );
        }
        _mainBalanceLamports = await _solanaService.getBalanceLamports(
          _wallet!.address,
        );
        _mainBalances[_activeScopeKey] = _mainBalanceLamports;
        final int availableAfterFees =
            _mainBalanceLamports - solFeeHeadroomLamports;
        if (availableAfterFees <= 0 || amountBaseUnits > availableAfterFees) {
          final int safeAvailable = availableAfterFees > 0
              ? availableAfterFees
              : 0;
          throw FormatException(
            'Main wallet balance is too low after network fees. Available to move: ${Formatters.asset(_activeChain.amountFromBaseUnits(safeAvailable), _activeChain)}.',
          );
        }
        final Ed25519HDKeyPair sender = await _walletService
            .loadSigningKeyPair();
        final String signature = await _solanaService.sendTransferNow(
          sender: sender,
          receiverAddress: _offlineWallet!.address,
          lamports: amountBaseUnits,
        );
        await _solanaService.waitForConfirmation(signature);
        await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
        await refreshWalletData();
        return;
      }

      _mainBalanceLamports = await _ethereumService.getBalanceBaseUnits(
        _wallet!.address,
      );
      _mainBalances[_activeScopeKey] = _mainBalanceLamports;
      final EthereumPreparedContext senderContext = await _ethereumService
          .prepareTransferContext(_wallet!.address);

      if (asset.isNative) {
        final int feeHeadroom =
            senderContext.gasPriceWei * EthereumService.transferGasLimit;
        final int availableAfterFees = _mainBalanceLamports - feeHeadroom;
        if (availableAfterFees <= 0 || amountBaseUnits > availableAfterFees) {
          final int safeAvailable = availableAfterFees > 0
              ? availableAfterFees
              : 0;
          throw FormatException(
            'Main wallet balance is too low after network fees. Available to move: ${Formatters.asset(_activeChain.amountFromBaseUnits(safeAvailable), _activeChain)}.',
          );
        }
        final EthPrivateKey sender = await _walletService
            .loadEvmSigningCredentials(chain: _activeChain);
        final String signature = await _ethereumService.sendTransferNow(
          sender: sender,
          senderAddress: _wallet!.address,
          receiverAddress: _offlineWallet!.address,
          amountBaseUnits: amountBaseUnits,
        );
        await _ethereumService.waitForConfirmation(signature);
        await _updateCachedEthereumContext(
          await _ethereumService.prepareTransferContext(
            _offlineWallet!.address,
          ),
        );
        await refreshWalletData();
        return;
      }

      if (!_activeChain.isEvm || asset.contractAddress == null) {
        throw const FormatException(
          'Token top-up is available only on supported EVM chains.',
        );
      }

      final int mainTokenBalanceBaseUnits =
          await _ethereumService.getTokenBalanceBaseUnits(
            ownerAddress: _wallet!.address,
            contractAddress: asset.contractAddress!,
          );
      _mainTrackedAssetBalances[asset.id] = mainTokenBalanceBaseUnits;
      if (amountBaseUnits > mainTokenBalanceBaseUnits) {
        throw FormatException(
          'Amount exceeds the available ${asset.symbol} balance in the main wallet.',
        );
      }

      final int gasLimit = await _ethereumService.estimateTokenTransferGas(
        senderAddress: _wallet!.address,
        receiverAddress: _offlineWallet!.address,
        contractAddress: asset.contractAddress!,
        amountBaseUnits: amountBaseUnits,
      );
      final int feeHeadroom = senderContext.gasPriceWei * gasLimit;
      if (_mainBalanceLamports <= 0 || feeHeadroom > _mainBalanceLamports) {
        throw FormatException(
          'Not enough ${_activeChain.assetDisplayLabel} to cover network fees for the ${asset.symbol} transfer.',
        );
      }

      final EthPrivateKey sender = await _walletService.loadEvmSigningCredentials(
        chain: _activeChain,
      );
      final String signature = await _ethereumService.sendTokenTransferNow(
        sender: sender,
        senderAddress: _wallet!.address,
        receiverAddress: _offlineWallet!.address,
        contractAddress: asset.contractAddress!,
        amountBaseUnits: amountBaseUnits,
      );
      await _ethereumService.waitForConfirmation(signature);
      await _updateCachedEthereumContext(
        await _ethereumService.prepareTransferContext(_offlineWallet!.address),
      );
      await refreshWalletData();
    });
  }

  Future<void> requestBlePermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    bool isAllowed(PermissionStatus status) {
      return status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
    }

    _localPermissionsGranted =
        <PermissionStatus>[
          statuses[Permission.bluetoothScan] ?? PermissionStatus.denied,
          statuses[Permission.bluetoothConnect] ?? PermissionStatus.denied,
          statuses[Permission.bluetoothAdvertise] ?? PermissionStatus.denied,
        ].every(isAllowed);
    notifyListeners();
  }

  Future<void> requestLocalPermissions() {
    return requestBlePermissions();
  }

  Future<void> requestUltrasonicPermissions() async {
    final PermissionStatus status = await Permission.microphone.request();
    _ultrasonicPermissionsGranted =
        status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    notifyListeners();
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
      _ethereumService.chain = _activeChain;
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

  Future<void> setOfflineVoucherSettlementContractAddress(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isNotEmpty &&
        (!_activeChain.isEvm || !_ethereumService.isValidAddress(trimmed))) {
      throw const FormatException('Enter a valid EVM settlement contract address.');
    }
    if (trimmed.isEmpty) {
      _offlineVoucherSettlementContracts.remove(_activeScopeKey);
    } else {
      _offlineVoucherSettlementContracts[_activeScopeKey] = trimmed;
    }
    await _saveOfflineVoucherSettlementContracts();
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
    _fileverseClientService.endpoint = endpoint;
    _fileverseClientService.clearSession();
    _relayClientService.endpoint = endpoint;
    _offlineVoucherClientService.endpoint = endpoint;
    _bitgoBackendMode = BitGoBackendMode.unknown;
    await _store.saveSetting('bitgo_endpoint', endpoint);
    if (_activeWalletEngine == WalletEngine.bitgo) {
      await refreshWalletData();
    } else {
      await _refreshBitGoBackendHealth(allowFailure: true);
      notifyListeners();
    }
  }

  Future<void> connectBitGo() async {
    await _runTask('Connecting wallet backend...', () async {
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to connect the BitGo wallet backend.',
        );
      }
      await _refreshBitGoBackendHealth();
      final BitGoDemoSession session = await _bitGoClientService
          .createSession();
      _syncBitGoWallets(session.wallets);
      await refreshWalletData();
    });
  }

  Future<void> connectBitGoDemo() => connectBitGo();

  Future<BitGoBackendHealth> fetchBackendHealth() async {
    _bitGoClientService.endpoint = _bitgoEndpoint;
    final BitGoBackendHealth health = await _bitGoClientService.fetchHealth();
    _bitgoBackendMode = health.mode;
    notifyListeners();
    return health;
  }

  void updateReceiver({
    required String receiverAddress,
    String receiverLabel = '',
    String receiverEndpoint = '',
    String receiverPeripheralId = '',
    String receiverPeripheralName = '',
    String receiverSessionToken = '',
    String receiverRelayId = '',
    String receiverPreferredChain = '',
    String receiverPreferredToken = '',
  }) {
    _sendDraft = _sendDraft.copyWith(
      receiverAddress: receiverAddress.trim(),
      receiverLabel: receiverLabel.trim(),
      receiverEndpoint: _normalizeEndpoint(receiverEndpoint),
      receiverPeripheralId: receiverPeripheralId.trim(),
      receiverPeripheralName: receiverPeripheralName.trim(),
      receiverSessionToken: receiverSessionToken.trim(),
      receiverRelayId: receiverRelayId.trim(),
      receiverPreferredChain: receiverPreferredChain.trim(),
      receiverPreferredToken: receiverPreferredToken.trim(),
    );
    notifyListeners();
  }

  void setSendTransport(TransportKind kind) {
    _sendDraft = _sendDraft.copyWith(
      chain: _activeChain,
      network: _activeNetwork,
      transport: kind,
      assetId: kind == TransportKind.online &&
              _activeWalletEngine == WalletEngine.local &&
              _activeChain.isEvm
          ? _sendDraft.assetId
          : _defaultSendAssetIdFor(_activeChain, _activeNetwork),
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

  Future<void> saveCurrentReceiverAsContact(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Contact name is required.');
    }
    final String address = _sendDraft.receiverAddress.trim();
    if (address.isEmpty) {
      throw const FormatException('Receiver address is required.');
    }
    final SendContact contact = SendContact(
      id: '${_activeChain.name}:${_activeNetwork.name}:${address.toLowerCase()}',
      name: trimmedName,
      address: address,
      chain: _activeChain,
      network: _activeNetwork,
      createdAt: _clock(),
    );
    _contacts.removeWhere((SendContact item) => item.id == contact.id);
    _contacts.add(contact);
    _contacts.sort((SendContact a, SendContact b) => a.name.compareTo(b.name));
    await _saveContacts();
    _sendDraft = _sendDraft.copyWith(receiverLabel: trimmedName);
    notifyListeners();
  }

  void selectContact(SendContact contact) {
    _sendDraft = _sendDraft.copyWith(
      receiverAddress: contact.address,
      receiverLabel: contact.name,
    );
    notifyListeners();
  }

  void setSendGasSpeed(GasSpeed gasSpeed) {
    if (_sendDraft.gasSpeed == gasSpeed) {
      return;
    }
    _sendDraft = _sendDraft.copyWith(gasSpeed: gasSpeed);
    notifyListeners();
  }

  void selectSendAsset(String assetId) {
    final TrackedAssetDefinition asset = _sendAssetDefinitionFor(
      chain: _sendDraft.chain,
      network: _sendDraft.network,
      assetId: assetId,
    );
    final bool canUseToken =
        asset.isNative ||
        (_sendDraft.walletEngine == WalletEngine.local &&
            _sendDraft.transport == TransportKind.online &&
            _sendDraft.chain.isEvm);
    _sendDraft = _sendDraft.copyWith(
      assetId: canUseToken
          ? asset.id
          : _defaultSendAssetIdFor(_sendDraft.chain, _sendDraft.network),
      amountSol: 0,
    );
    notifyListeners();
  }

  Future<TrackedAssetDefinition> importTrackedToken({
    required String contractAddress,
  }) async {
    if (!_activeChain.isEvm) {
      throw const FormatException('Token import is only available on EVM chains.');
    }
    final String endpoint =
        _rpcEndpoints[_activeScopeKey] ??
        _defaultRpcEndpointFor(_activeChain, _activeNetwork);
    final EthereumService service = EthereumService(rpcEndpoint: endpoint)
      ..chain = _activeChain
      ..network = _activeNetwork;
    final TrackedAssetDefinition asset = await service.describeErc20Asset(
      contractAddress.trim(),
    );
    final String scopeKey = _activeScopeKey;
    _discoveredTrackedAssets
        .putIfAbsent(scopeKey, () => <String, TrackedAssetDefinition>{})[
      trackedAssetLookupKey(asset)
    ] = asset;
    await _saveDiscoveredTrackedAssets();
    await _refreshTrackedAssetBalancesForChain(
      chain: _activeChain,
      network: _activeNetwork,
      wallet: _wallet,
      offlineWallet: _offlineWallet,
    );
    await _refreshPortfolioUsdPrices();
    selectSendAsset(asset.id);
    return asset;
  }

  Future<TokenAllowanceEntry> refreshTokenAllowance({
    required String assetId,
    required String spenderAddress,
    String spenderLabel = '',
  }) async {
    if (!_activeChain.isEvm) {
      throw const FormatException('Approvals are only available on EVM chains.');
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    final TrackedAssetDefinition asset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: assetId,
    );
    if (asset.isNative || asset.contractAddress == null) {
      throw const FormatException('Choose an ERC-20 token to manage approvals.');
    }
    final String normalizedSpender = spenderAddress.trim();
    if (!_ethereumService.isValidAddress(normalizedSpender)) {
      throw const FormatException('Enter a valid spender address.');
    }
    final int allowanceBaseUnits = await _ethereumService
        .getTokenAllowanceBaseUnits(
          ownerAddress: _wallet!.address,
          spenderAddress: normalizedSpender,
          contractAddress: asset.contractAddress!,
        );
    final TokenAllowanceEntry entry = TokenAllowanceEntry(
      id:
          '${_activeChain.name}:${_activeNetwork.name}:${_wallet!.address.toLowerCase()}:${asset.contractAddress!.toLowerCase()}:${normalizedSpender.toLowerCase()}',
      chain: _activeChain,
      network: _activeNetwork,
      ownerAddress: _wallet!.address,
      assetId: asset.id,
      tokenSymbol: asset.symbol,
      tokenDisplayName: asset.displayName,
      tokenDecimals: asset.decimals,
      tokenContractAddress: asset.contractAddress!,
      spenderAddress: normalizedSpender,
      spenderLabel: spenderLabel.trim(),
      allowanceBaseUnits: allowanceBaseUnits,
      updatedAt: _clock(),
    );
    await _upsertAllowanceEntry(entry);
    return entry;
  }

  Future<TokenAllowanceQuote> quoteTokenAllowance({
    required String assetId,
    required String spenderAddress,
    required double amount,
  }) async {
    if (!_activeChain.isEvm) {
      throw const FormatException('Approvals are only available on EVM chains.');
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    final TrackedAssetDefinition asset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: assetId,
    );
    if (asset.isNative || asset.contractAddress == null) {
      throw const FormatException('Choose an ERC-20 token to manage approvals.');
    }
    if (!_ethereumService.isValidAddress(spenderAddress.trim())) {
      throw const FormatException('Enter a valid spender address.');
    }
    final int currentAllowance = await _ethereumService.getTokenAllowanceBaseUnits(
      ownerAddress: _wallet!.address,
      spenderAddress: spenderAddress.trim(),
      contractAddress: asset.contractAddress!,
    );
    final int proposedAllowance = asset.amountToBaseUnits(amount);
    final int fee;
    if (_hasInternet) {
      final EthereumPreparedContext context = await _ethereumService
          .prepareTransferContext(_wallet!.address);
      final int gasPriceWei = _applyGasSpeedToWei(context.gasPriceWei);
      final int gasLimit = await _ethereumService.estimateTokenApprovalGas(
        senderAddress: _wallet!.address,
        spenderAddress: spenderAddress.trim(),
        contractAddress: asset.contractAddress!,
        amountBaseUnits: proposedAllowance,
      );
      fee = gasPriceWei * gasLimit;
    } else {
      fee = estimatedOnlineSendFeeHeadroomBaseUnits;
    }
    return TokenAllowanceQuote(
      currentAllowanceBaseUnits: currentAllowance,
      proposedAllowanceBaseUnits: proposedAllowance,
      networkFeeBaseUnits: fee,
      isEstimate: !_hasInternet,
    );
  }

  Future<TokenAllowanceEntry> approveTokenAllowance({
    required String assetId,
    required String spenderAddress,
    required double amount,
    String spenderLabel = '',
  }) {
    final TrackedAssetDefinition asset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: assetId,
    );
    return approveTokenAllowanceBaseUnits(
      assetId: assetId,
      spenderAddress: spenderAddress,
      amountBaseUnits: asset.amountToBaseUnits(amount),
      spenderLabel: spenderLabel,
    );
  }

  Future<TokenAllowanceEntry> approveTokenAllowanceBaseUnits({
    required String assetId,
    required String spenderAddress,
    required int amountBaseUnits,
    String spenderLabel = '',
  }) async {
    if (!_activeChain.isEvm) {
      throw const FormatException('Approvals are only available on EVM chains.');
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (!_hasInternet) {
      throw const SocketException(
        'Internet is required to submit an approval transaction.',
      );
    }
    final TrackedAssetDefinition asset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: assetId,
    );
    if (asset.isNative || asset.contractAddress == null) {
      throw const FormatException('Choose an ERC-20 token to manage approvals.');
    }
    final EthPrivateKey signer = await _walletService.loadEvmSigningCredentials(
      chain: _activeChain,
      slot: activeAccountSlot,
    );
    final int gasPriceWei = _applyGasSpeedToWei(
      (await _ethereumService.prepareTransferContext(_wallet!.address))
          .gasPriceWei,
    );
    final String txHash = await _ethereumService.sendApproveNow(
      sender: signer,
      senderAddress: _wallet!.address,
      spenderAddress: spenderAddress.trim(),
      contractAddress: asset.contractAddress!,
      amountBaseUnits: amountBaseUnits,
      gasPriceWeiOverride: gasPriceWei,
    );
    await _ethereumService.waitForConfirmation(txHash);
    final TokenAllowanceEntry entry = await refreshTokenAllowance(
      assetId: assetId,
      spenderAddress: spenderAddress,
      spenderLabel: spenderLabel,
    );
    final TokenAllowanceEntry updated = entry.copyWith(
      updatedAt: _clock(),
      lastTransactionHash: txHash,
      spenderLabel: spenderLabel.trim().isEmpty
          ? entry.spenderLabel
          : spenderLabel.trim(),
    );
    await _upsertAllowanceEntry(updated);
    return updated;
  }

  Future<TokenAllowanceEntry> revokeTokenAllowance({
    required String assetId,
    required String spenderAddress,
    String spenderLabel = '',
  }) {
    return approveTokenAllowance(
      assetId: assetId,
      spenderAddress: spenderAddress,
      amount: 0,
      spenderLabel: spenderLabel,
    );
  }

  Future<void> removeAllowanceEntry(String entryId) async {
    _allowanceEntries.removeWhere((TokenAllowanceEntry entry) => entry.id == entryId);
    await _saveAllowanceEntries();
    notifyListeners();
  }

  Future<SwapQuote> quoteSwap({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  }) async {
    await _refreshConnectivityState();
    final ({
      TrackedAssetDefinition sellAsset,
      TrackedAssetDefinition buyAsset,
      int sellAmountBaseUnits,
      int chainId
    }) request = _resolveSwapRequest(
      sellAssetId: sellAssetId,
      buyAssetId: buyAssetId,
      sellAmount: sellAmount,
    );
    final SwapQuote quote = await _effectiveSwapService.fetchPrice(
      chainId: request.chainId,
      sellTokenAddress: SwapService.tokenAddressForAsset(request.sellAsset),
      buyTokenAddress: SwapService.tokenAddressForAsset(request.buyAsset),
      sellAmountBaseUnits: request.sellAmountBaseUnits,
      takerAddress: _wallet!.address,
      slippageBps: _swapSlippageBps,
    );
    _validateSwapQuote(
      quote: quote,
      sellAsset: request.sellAsset,
      sellAmountBaseUnits: request.sellAmountBaseUnits,
    );
    return quote;
  }

  Future<PendingTransfer> executeSwap({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  }) async {
    await _refreshConnectivityState();
    final ({
      TrackedAssetDefinition sellAsset,
      TrackedAssetDefinition buyAsset,
      int sellAmountBaseUnits,
      int chainId
    }) request = _resolveSwapRequest(
      sellAssetId: sellAssetId,
      buyAssetId: buyAssetId,
      sellAmount: sellAmount,
    );
    SwapQuote quote = await _effectiveSwapService.fetchQuote(
      chainId: request.chainId,
      sellTokenAddress: SwapService.tokenAddressForAsset(request.sellAsset),
      buyTokenAddress: SwapService.tokenAddressForAsset(request.buyAsset),
      sellAmountBaseUnits: request.sellAmountBaseUnits,
      takerAddress: _wallet!.address,
      slippageBps: _swapSlippageBps,
    );
    _validateSwapQuote(
      quote: quote,
      sellAsset: request.sellAsset,
      sellAmountBaseUnits: request.sellAmountBaseUnits,
    );
    if (!request.sellAsset.isNative && quote.requiresAllowance) {
      final String spenderAddress = quote.allowanceIssue!.spenderAddress;
      await approveTokenAllowanceBaseUnits(
        assetId: request.sellAsset.id,
        spenderAddress: spenderAddress,
        amountBaseUnits: request.sellAmountBaseUnits,
        spenderLabel: '0x Swap',
      );
      quote = await _effectiveSwapService.fetchQuote(
        chainId: request.chainId,
        sellTokenAddress: SwapService.tokenAddressForAsset(request.sellAsset),
        buyTokenAddress: SwapService.tokenAddressForAsset(request.buyAsset),
        sellAmountBaseUnits: request.sellAmountBaseUnits,
        takerAddress: _wallet!.address,
        slippageBps: _swapSlippageBps,
      );
      _validateSwapQuote(
        quote: quote,
        sellAsset: request.sellAsset,
        sellAmountBaseUnits: request.sellAmountBaseUnits,
      );
      if (quote.requiresAllowance) {
        throw const FormatException(
          'Token allowance is still not ready. Try again in a few seconds.',
        );
      }
    }
    final SwapTransactionRequest? transaction = quote.transaction;
    if (transaction == null) {
      throw const FormatException(
        'The swap route did not return an executable transaction.',
      );
    }
    final EthPrivateKey signer = await _walletService.loadEvmSigningCredentials(
      chain: _activeChain,
      slot: activeAccountSlot,
    );
    final String txHash = await _ethereumService.sendContractTransactionNow(
      sender: signer,
      senderAddress: _wallet!.address,
      toAddress: transaction.toAddress,
      dataHex: transaction.dataHex,
      valueBaseUnits: transaction.valueBaseUnits,
      gasLimit: transaction.gasLimit > 0 ? transaction.gasLimit : null,
      gasPriceWeiOverride: transaction.gasPriceWei > 0
          ? transaction.gasPriceWei
          : null,
    );
    final DateTime createdAt = _clock();
    final PendingTransfer transfer = PendingTransfer(
      transferId: _uuid.v4(),
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.outbound,
      status: TransferStatus.broadcastSubmitted,
      amountLamports: request.sellAmountBaseUnits,
      senderAddress: _wallet!.address,
      receiverAddress: transaction.toAddress,
      transport: TransportKind.online,
      createdAt: createdAt,
      updatedAt: createdAt,
      assetId: request.sellAsset.id,
      assetSymbol: request.sellAsset.symbol,
      assetDisplayName:
          '${request.sellAsset.displayName} → ${request.buyAsset.displayName}',
      assetDecimals: request.sellAsset.decimals,
      assetContractAddress: request.sellAsset.contractAddress,
      isNativeAsset: request.sellAsset.isNative,
      remoteEndpoint:
          '0x Swap • ${request.sellAsset.symbol} → ${request.buyAsset.symbol}',
      transactionSignature: txHash,
      explorerUrl: _ethereumService.explorerUrlFor(txHash).toString(),
    );
    await _persistTransfer(transfer);
    _lastSentTransferId = transfer.transferId;
    await refreshWalletData();
    if (_hasInternet) {
      unawaited(_startRealtimeSettlementSync());
      unawaited(refreshSubmittedTransfers());
    }
    return transfer;
  }

  ({
    TrackedAssetDefinition sellAsset,
    TrackedAssetDefinition buyAsset,
    int sellAmountBaseUnits,
    int chainId
  }) _resolveSwapRequest({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  }) {
    if (!swapSupportedOnActiveScope) {
      throw const FormatException(
        'Swaps are available only in Local wallet mode on supported EVM mainnets.',
      );
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (!_hasInternet) {
      throw const SocketException(
        'Internet is required to build and submit swap quotes.',
      );
    }
    if (!hasSwapApiKey) {
      throw const FormatException(
        'Add your 0x API key in Settings before using swaps.',
      );
    }
    final int? chainId = SwapService.supportedChainIdFor(
      _activeChain,
      _activeNetwork,
    );
    if (chainId == null) {
      throw const FormatException(
        'Swaps are not available on this chain or network yet.',
      );
    }
    final TrackedAssetDefinition sellAsset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: sellAssetId,
    );
    final TrackedAssetDefinition buyAsset = _sendAssetDefinitionFor(
      chain: _activeChain,
      network: _activeNetwork,
      assetId: buyAssetId,
    );
    if (sellAsset.id == buyAsset.id) {
      throw const FormatException('Choose two different assets to swap.');
    }
    final int sellAmountBaseUnits = sellAsset.amountToBaseUnits(sellAmount);
    if (sellAmountBaseUnits <= 0) {
      throw const FormatException('Enter an amount greater than zero.');
    }
    final AssetPortfolioHolding holding = _holdingForTrackedAsset(sellAsset);
    if (sellAmount > holding.mainBalance) {
      throw FormatException(
        'Amount exceeds the available ${sellAsset.symbol} balance.',
      );
    }
    return (
      sellAsset: sellAsset,
      buyAsset: buyAsset,
      sellAmountBaseUnits: sellAmountBaseUnits,
      chainId: chainId,
    );
  }

  void _validateSwapQuote({
    required SwapQuote quote,
    required TrackedAssetDefinition sellAsset,
    required int sellAmountBaseUnits,
  }) {
    if (!quote.liquidityAvailable) {
      throw const FormatException(
        'No on-chain liquidity is available for this pair right now.',
      );
    }
    if (quote.balanceIssue != null) {
      throw FormatException(
        _swapBalanceErrorMessage(quote.balanceIssue!, sellAsset),
      );
    }
    final int networkFeeBaseUnits = quote.totalNetworkFeeBaseUnits ?? 0;
    if (!sellAsset.isNative && networkFeeBaseUnits > _mainBalanceLamports) {
      throw FormatException(
        'Not enough ${_activeChain.assetDisplayLabel} to cover swap gas.',
      );
    }
    if (sellAsset.isNative &&
        sellAmountBaseUnits + networkFeeBaseUnits > _mainBalanceLamports) {
      throw FormatException(
        'Not enough ${sellAsset.symbol} to cover the swap amount and gas.',
      );
    }
  }

  String _swapBalanceErrorMessage(
    SwapBalanceIssue issue,
    TrackedAssetDefinition sellAsset,
  ) {
    if (sellAsset.isNative) {
      return 'Not enough ${sellAsset.symbol} for this swap.';
    }
    return 'Not enough ${sellAsset.symbol} in the main wallet for this swap.';
  }

  Future<void> refreshNftHoldings() async {
    if (!_activeChain.isEvm || _wallet == null) {
      _nftHoldingsByScope[_activeScopeKey] = const <NftHolding>[];
      notifyListeners();
      return;
    }
    if (!_hasInternet) {
      throw const SocketException(
        'Internet is required to refresh NFT holdings.',
      );
    }
    final int latestBlock = await _ethereumService.getBlockNumber();
    final List<NftHolding> holdings = await _ethereumService
        .discoverErc721Holdings(
          ownerAddress: _wallet!.address,
          fromBlock: _initialErc20DiscoveryStartBlock(latestBlock),
          toBlock: latestBlock,
          chunkSize: erc20DiscoveryChunkSize,
        );
    _nftHoldingsByScope[_activeScopeKey] = holdings;
    notifyListeners();
  }

  Future<DappSignResult> signDappRequest(DappSignRequest request) async {
    if (!request.chain.isEvm) {
      throw const FormatException('Dapp signing is only available on EVM chains.');
    }
    await setActiveChain(request.chain);
    await setActiveNetwork(request.network);
    if (_activeWalletEngine != WalletEngine.local) {
      await setActiveWalletEngine(WalletEngine.local);
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    final EthPrivateKey signer = await _walletService.loadEvmSigningCredentials(
      chain: _activeChain,
      slot: activeAccountSlot,
    );
    return switch (request.method) {
      DappRequestMethod.personalSign => DappSignResult(
        request: request,
        result: _ethereumService.signPersonalMessageHex(
          signer: signer,
          message: request.message ?? '',
        ),
        completedAt: _clock(),
      ),
      DappRequestMethod.ethSign => DappSignResult(
        request: request,
        result: _ethereumService.signPayloadHex(
          signer: signer,
          payload: _decodeDappPayloadBytes(request),
        ),
        completedAt: _clock(),
      ),
      DappRequestMethod.sendTransaction => DappSignResult(
        request: request,
        result: await _ethereumService.sendContractTransactionNow(
          sender: signer,
          senderAddress: _wallet!.address,
          toAddress: request.toAddress!,
          dataHex: request.dataHex,
          valueBaseUnits: request.valueBaseUnits,
          gasPriceWeiOverride: _applyGasSpeedToWei(
            (await _ethereumService.prepareTransferContext(_wallet!.address))
                .gasPriceWei,
          ),
        ),
        completedAt: _clock(),
        isTransaction: true,
      ),
    };
  }

  Future<SendQuote> quoteCurrentDraft({double? amountSol}) async {
    final double requestedAmount = amountSol ?? _sendDraft.amountSol;
    final TrackedAssetDefinition asset = _sendAssetDefinitionForDraft(_sendDraft);
    final int amountBaseUnits = asset.amountToBaseUnits(requestedAmount);
    if (amountBaseUnits <= 0) {
      throw const FormatException('Enter an amount greater than zero.');
    }
    final bool directOnline =
        _activeWalletEngine == WalletEngine.bitgo ||
        _sendDraft.transport == TransportKind.online;
    if (!directOnline) {
      final int feeBaseUnits = estimatedSendFeeHeadroomBaseUnits;
      return SendQuote(
        amountBaseUnits: amountBaseUnits,
        networkFeeBaseUnits: feeBaseUnits,
        totalDebitBaseUnits: asset.isNative
            ? amountBaseUnits + feeBaseUnits
            : amountBaseUnits,
        isEstimate: true,
        note: 'No slippage on direct transfers.',
      );
    }

    if (!asset.isNative) {
      if (_activeWalletEngine == WalletEngine.bitgo) {
        throw const FormatException(
          'Token transfers are not available in BitGo mode yet.',
        );
      }
      if (_activeChain == ChainKind.solana) {
        throw const FormatException(
          'Token transfers are not available on Solana yet.',
        );
      }
      if (!_hasInternet) {
        final int fallbackFee = estimatedOnlineSendFeeHeadroomBaseUnits;
        return SendQuote(
          amountBaseUnits: amountBaseUnits,
          networkFeeBaseUnits: fallbackFee,
          totalDebitBaseUnits: amountBaseUnits,
          isEstimate: true,
          note:
              'Using fallback gas until the wallet is online. Network fee is paid in ${_activeChain.assetDisplayLabel}. No slippage on direct transfers.',
        );
      }
      if (_wallet == null) {
        throw const FormatException('Source wallet is unavailable.');
      }
      final EthereumPreparedContext context = await _ethereumService
          .prepareTransferContext(_wallet!.address);
      final int effectiveGasPrice = _applyGasSpeedToWei(context.gasPriceWei);
      final int gasLimit = await _ethereumService.estimateTokenTransferGas(
        senderAddress: _wallet!.address,
        receiverAddress: _sendDraft.receiverAddress,
        contractAddress: asset.contractAddress!,
        amountBaseUnits: amountBaseUnits,
      );
      final int feeBaseUnits = effectiveGasPrice * gasLimit;
      return SendQuote(
        amountBaseUnits: amountBaseUnits,
        networkFeeBaseUnits: feeBaseUnits,
        totalDebitBaseUnits: amountBaseUnits,
        note:
            'Network fee is paid in ${_activeChain.assetDisplayLabel}. No slippage on direct transfers.',
      );
    }

    if (_activeChain == ChainKind.solana) {
      return SendQuote(
        amountBaseUnits: amountBaseUnits,
        networkFeeBaseUnits: solFeeHeadroomLamports,
        totalDebitBaseUnits: amountBaseUnits + solFeeHeadroomLamports,
        isEstimate: true,
        note: 'No slippage on direct transfers.',
      );
    }

    if (!_hasInternet) {
      final int fallbackFee = estimatedOnlineSendFeeHeadroomBaseUnits;
      return SendQuote(
        amountBaseUnits: amountBaseUnits,
        networkFeeBaseUnits: fallbackFee,
        totalDebitBaseUnits: amountBaseUnits + fallbackFee,
        isEstimate: true,
        note: 'Using fallback gas until the wallet is online. No slippage on direct transfers.',
      );
    }

    final String senderAddress = _activeWalletEngine == WalletEngine.bitgo
        ? (_bitgoWallet?.address ?? _wallet?.address ?? '')
        : _sendDraft.transport == TransportKind.online
        ? (_wallet?.address ?? '')
        : (_offlineWallet?.address ?? '');
    if (senderAddress.isEmpty) {
      throw const FormatException('Source wallet is unavailable.');
    }
    final EthereumPreparedContext context = await _ethereumService
        .prepareTransferContext(senderAddress);
    final int feeBaseUnits =
        _applyGasSpeedToWei(context.gasPriceWei) *
        EthereumService.transferGasLimit;
    return SendQuote(
      amountBaseUnits: amountBaseUnits,
      networkFeeBaseUnits: feeBaseUnits,
      totalDebitBaseUnits: amountBaseUnits + feeBaseUnits,
      note: 'No slippage on direct transfers.',
    );
  }

  String? validateSendAmount(double amountSol) {
    final TrackedAssetDefinition asset = _sendAssetDefinitionForDraft(_sendDraft);
    final int amountBaseUnits = asset.amountToBaseUnits(amountSol);
    if (amountBaseUnits <= 0) {
      return 'Enter an amount greater than zero.';
    }
    if (!asset.isNative) {
      if (_activeWalletEngine == WalletEngine.bitgo) {
        return 'Token send is not available in BitGo mode yet.';
      }
      if (_sendDraft.transport != TransportKind.online) {
        return 'Token send is available only for Online transfers.';
      }
      if (!_activeChain.isEvm) {
        return 'Token send is only available on EVM chains right now.';
      }
      final int tokenBalance = _mainTrackedAssetBalances[asset.id] ?? 0;
      if (amountBaseUnits > tokenBalance) {
        return 'Amount exceeds the available ${asset.symbol} balance.';
      }
      if (estimatedOnlineSendFeeHeadroomBaseUnits > _mainBalanceLamports) {
        return 'Not enough ${_activeChain.assetDisplayLabel} to cover network fees.';
      }
      return null;
    }
    if (_activeWalletEngine == WalletEngine.bitgo) {
      if (amountBaseUnits > _mainBalanceLamports) {
        return 'Amount exceeds the available BitGo wallet balance.';
      }
      return null;
    }
    if (_sendDraft.transport == TransportKind.online) {
      if (amountBaseUnits + estimatedOnlineSendFeeHeadroomBaseUnits >
          _mainBalanceLamports) {
        return 'Amount exceeds the available wallet balance after network fees.';
      }
      return null;
    }
    if (amountBaseUnits + estimatedSendFeeHeadroomBaseUnits >
        offlineSpendableLamports) {
      return 'Amount exceeds the available offline wallet balance after network fees.';
    }
    return null;
  }

  void clearDraft() {
    _sendDraft = SendDraft(
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: _activeWalletEngine,
      transport: _activeWalletEngine == WalletEngine.local && _hasInternet
          ? TransportKind.online
          : TransportKind.hotspot,
      assetId: _defaultSendAssetIdFor(_activeChain, _activeNetwork),
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
      await _importPendingRelayCapsules();
      await broadcastPendingTransfers();
      await refreshSubmittedTransfers();
      await _processOfflineVoucherClaimQueue();
    } else if (_wallet != null) {
      notifyListeners();
    }
  }

  Future<PendingTransfer> saveReceiptToFileverse({
    required String transferId,
    required Uint8List receiptPngBytes,
  }) async {
    final PendingTransfer? transfer = transferById(transferId);
    if (transfer == null) {
      throw const FormatException('Transfer not found.');
    }
    await _refreshConnectivityState();
    if (!_hasInternet) {
      throw const SocketException(
        'Internet is required to publish a receipt to Fileverse.',
      );
    }
    if (!_fileverseClientService.hasSession) {
      await _fileverseClientService.createSession();
    }
    final FileverseReceiptSnapshot snapshot =
        await _fileverseClientService.publishReceipt(
          transfer: transfer,
          receiptPngBase64: base64Encode(receiptPngBytes),
        );
    final PendingTransfer updated = transfer.copyWith(
      updatedAt: _clock(),
      fileverseReceiptId: snapshot.receiptId,
      fileverseReceiptUrl: snapshot.receiptUrl,
      fileverseSavedAt: snapshot.savedAt,
      fileverseStorageMode: snapshot.storageMode,
      fileverseMessage: snapshot.message,
    );
    await _persistTransfer(updated);
    return updated;
  }

  Future<PendingTransfer?> refreshReceiptArchive(String transferId) async {
    final PendingTransfer? transfer = transferById(transferId);
    if (transfer == null ||
        transfer.fileverseReceiptId == null ||
        transfer.fileverseReceiptId!.isEmpty) {
      return transfer;
    }
    await _refreshConnectivityState();
    if (!_hasInternet) {
      return transfer;
    }
    if (!_fileverseClientService.hasSession) {
      await _fileverseClientService.createSession();
    }
    final FileverseReceiptSnapshot snapshot = await _fileverseClientService
        .fetchReceipt(transfer.fileverseReceiptId!);
    final PendingTransfer updated = transfer.copyWith(
      updatedAt: _clock(),
      fileverseReceiptId: snapshot.receiptId,
      fileverseReceiptUrl: snapshot.receiptUrl,
      fileverseSavedAt: snapshot.savedAt,
      fileverseStorageMode: snapshot.storageMode,
      fileverseMessage: snapshot.message,
    );
    await _persistTransfer(updated);
    return updated;
  }

  bool _shouldUseOfflineVoucherSettlement({
    required TrackedAssetDefinition asset,
    required TransportKind transport,
    required WalletEngine walletEngine,
    required ChainKind chain,
  }) {
    return walletEngine == WalletEngine.local &&
        transport != TransportKind.online &&
        chain.isEvm &&
        asset.isNative;
  }

  Future<TransportReceiveResult> _handleIncomingTransportPayload(
    OfflineTransportPayload payload,
  ) {
    return switch (payload.kind) {
      OfflineTransportPayloadKind.legacyEnvelope =>
        _handleIncomingEnvelope(payload.envelope!),
      OfflineTransportPayloadKind.voucherBundle =>
        _handleIncomingVoucherBundle(payload.voucherBundle!),
    };
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
    if (_activeWalletEngine == WalletEngine.local && _wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (_activeWalletEngine == WalletEngine.local &&
        _sendDraft.transport != TransportKind.online &&
        _offlineWallet == null) {
      throw const FormatException('Create or restore the nearby send wallet first.');
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
    if (_activeWalletEngine == WalletEngine.local &&
        _sendDraft.transport == TransportKind.ultrasonic &&
        _sendDraft.receiverSessionToken.isEmpty) {
      throw const FormatException(
        'Scan the receiver QR code before sending.',
      );
    }
    if (_activeWalletEngine == WalletEngine.local &&
        _sendDraft.transport == TransportKind.ultrasonic &&
        _sendDraft.receiverRelayId.isEmpty) {
      throw const FormatException(
        'Receiver relay details are missing. Scan the QR code again.',
      );
    }
    if (_activeChain.isEvm &&
        !_ethereumService.isValidAddress(_sendDraft.receiverAddress) &&
        _ethereumService.isEnsName(_sendDraft.receiverLabel)) {
      _sendDraft = _sendDraft.copyWith(
        receiverAddress: await _ethereumEnsService.resolveEnsAddress(
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
    final TrackedAssetDefinition asset = _sendAssetDefinitionForDraft(_sendDraft);
    final int amountBaseUnits = asset.amountToBaseUnits(_sendDraft.amountSol);
    if (amountBaseUnits <= 0) {
      throw const FormatException('Enter an amount greater than zero.');
    }
    if (!asset.isNative) {
      if (_activeWalletEngine == WalletEngine.bitgo) {
        throw const FormatException(
          'Token transfers are not available in BitGo mode yet.',
        );
      }
      if (_sendDraft.transport != TransportKind.online) {
        throw const FormatException(
          'Token transfers are available only for Online transfers.',
        );
      }
      if (!_activeChain.isEvm) {
        throw const FormatException(
          'Token transfers are available only on EVM chains right now.',
        );
      }
    }
    await _refreshConnectivityState();
    if (_activeWalletEngine == WalletEngine.local &&
        _sendDraft.transport == TransportKind.online) {
      return _sendCurrentDraftOnline(
        amountBaseUnits: amountBaseUnits,
        asset: asset,
      );
    }
    if (_shouldUseOfflineVoucherSettlement(
      asset: asset,
      transport: _sendDraft.transport,
      walletEngine: _activeWalletEngine,
      chain: _activeChain,
    )) {
      return _sendCurrentDraftOfflineVoucher(
        amountBaseUnits: amountBaseUnits,
        asset: asset,
      );
    }
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
          'BitGo backend is not live. Switched to Local mode and retrying with the offline wallet.',
        );
      }
      await _ensureBitGoSession();
      final BitGoWalletSummary? wallet = _bitgoWallet;
      if (wallet == null) {
        throw FormatException(
          'BitGo wallet is not configured for ${_activeNetwork.labelFor(_activeChain)}.',
        );
      }
      if (amountBaseUnits > _mainBalanceLamports) {
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
          amountBaseUnits: amountBaseUnits,
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
        amountLamports: amountBaseUnits,
        senderAddress: wallet.address,
        receiverAddress: _sendDraft.receiverAddress,
        transport: _sendDraft.transport,
        createdAt: createdAt,
        updatedAt: snapshot.updatedAt ?? createdAt,
        remoteEndpoint: switch (_sendDraft.transport) {
          TransportKind.online => 'Direct on-chain',
          TransportKind.hotspot => _sendDraft.receiverEndpoint.isEmpty
              ? 'Address discovery'
              : _sendDraft.receiverEndpoint,
          TransportKind.ble => _sendDraft.receiverPeripheralName.isEmpty
              ? 'BLE discovery'
              : _sendDraft.receiverPeripheralName,
          TransportKind.ultrasonic => _sendDraft.receiverRelayId.isEmpty
              ? 'Ultrasonic session'
              : _sendDraft.receiverRelayId,
        },
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

    final (
      String transferId,
      DateTime createdAt,
      OfflineEnvelope envelope,
      ValidatedTransactionDetails details
    ) = await _prepareSignedLocalEnvelope(lamports: amountBaseUnits);

    if (_sendDraft.transport == TransportKind.hotspot) {
      final Uri endpoint = Uri.parse(_sendDraft.receiverEndpoint);
      await _hotspotTransportService.send(
        endpoint: endpoint,
        payload: OfflineTransportPayload.envelope(envelope),
      );
    } else if (_sendDraft.transport == TransportKind.ble) {
      await _bleTransportService.send(
        peripheralId: _sendDraft.receiverPeripheralId,
        payload: OfflineTransportPayload.envelope(envelope),
      );
    } else {
      await _ultrasonicTransportService.send(
        packet: _createUltrasonicPacket(envelope),
      );
    }

    final PendingTransfer transfer = PendingTransfer(
      transferId: transferId,
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.outbound,
      status: TransferStatus.sentOffline,
      amountLamports: amountBaseUnits,
      senderAddress: _offlineWallet!.address,
      receiverAddress: _sendDraft.receiverAddress,
      transport: _sendDraft.transport,
      createdAt: createdAt,
      updatedAt: createdAt,
      envelope: envelope,
      remoteEndpoint: switch (_sendDraft.transport) {
        TransportKind.online => 'Direct on-chain',
        TransportKind.hotspot => _sendDraft.receiverEndpoint,
        TransportKind.ble => _sendDraft.receiverPeripheralName,
        TransportKind.ultrasonic => 'Ultrasonic direct',
      },
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

  Future<PendingTransfer> _sendCurrentDraftOfflineVoucher({
    required int amountBaseUnits,
    required TrackedAssetDefinition asset,
  }) async {
    if (_wallet == null || _offlineWallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (_sendDraft.transport == TransportKind.ultrasonic) {
      throw const FormatException(
        'Ultrasonic direct audio is not available for escrow voucher settlement yet. Use Hotspot or Bluetooth.',
      );
    }
    if (!_activeChain.isEvm) {
      throw const FormatException(
        'Voucher settlement is only available on EVM chains right now.',
      );
    }
    if (!asset.isNative) {
      throw const FormatException(
        'Voucher settlement is currently available only for the native asset.',
      );
    }

    final OfflineVoucherEscrowSession session =
        await _ensureOfflineVoucherEscrowSession(
          amountBaseUnits: amountBaseUnits,
          asset: asset,
        );
    final EthPrivateKey signer = await _walletService.loadEvmSigningCredentials(
      chain: _activeChain,
      offline: true,
      slot: activeAccountSlot,
    );
    final DateTime createdAt = _clock().toUtc();
    final String transferId = _uuid.v4();
    final OfflineVoucherTransferBundle bundle =
        _offlineVoucherService.composeTransferBundle(
          session: session,
          transferId: transferId,
          amountBaseUnits: amountBaseUnits.toString(),
          receiverAddress: _sendDraft.receiverAddress,
          signer: signer,
          transportKind: _sendDraft.transport,
          createdAt: createdAt,
        );

    final OfflineTransportPayload payload =
        OfflineTransportPayload.voucherBundle(bundle);
    if (_sendDraft.transport == TransportKind.hotspot) {
      await _hotspotTransportService.send(
        endpoint: Uri.parse(_sendDraft.receiverEndpoint),
        payload: payload,
      );
    } else if (_sendDraft.transport == TransportKind.ble) {
      await _bleTransportService.send(
        peripheralId: _sendDraft.receiverPeripheralId,
        payload: payload,
      );
    } else {
      throw const FormatException('Unsupported voucher transport.');
    }

    final OfflineVoucherEscrowSession reservedSession = session.copyWith(
      inventory: _offlineVoucherService.reserveBundleEntries(
        session: session,
        bundle: bundle,
      ),
      availableAmountBaseUnits:
          _offlineVoucherService
              .reserveBundleEntries(session: session, bundle: bundle)
              .where((OfflineVoucherInventoryEntry item) => item.isAvailable)
              .fold<BigInt>(
                BigInt.zero,
                (
                  BigInt total,
                  OfflineVoucherInventoryEntry item,
                ) => total + BigInt.parse(item.voucher.amountBaseUnits),
              )
              .toString(),
    );
    await _upsertOfflineVoucherEscrowSession(
      _activeScopeKey,
      reservedSession,
    );

    final PendingTransfer transfer = PendingTransfer(
      transferId: transferId,
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.outbound,
      status: TransferStatus.sentOffline,
      amountLamports: amountBaseUnits,
      senderAddress: _offlineWallet!.address,
      receiverAddress: _sendDraft.receiverAddress,
      transport: _sendDraft.transport,
      createdAt: createdAt,
      updatedAt: createdAt,
      assetId: asset.id,
      assetSymbol: asset.symbol,
      assetDisplayName: asset.displayName,
      assetDecimals: asset.decimals,
      assetContractAddress: asset.contractAddress,
      isNativeAsset: asset.isNative,
      remoteEndpoint: switch (_sendDraft.transport) {
        TransportKind.online => 'Direct on-chain',
        TransportKind.hotspot => _sendDraft.receiverEndpoint,
        TransportKind.ble => _sendDraft.receiverPeripheralName,
        TransportKind.ultrasonic => 'Ultrasonic direct',
      },
    );
    await _persistTransfer(transfer);
    _lastSentTransferId = transfer.transferId;
    clearDraft();
    return transfer;
  }

  Future<OfflineVoucherEscrowSession> _ensureOfflineVoucherEscrowSession({
    required int amountBaseUnits,
    required TrackedAssetDefinition asset,
  }) async {
    final List<OfflineVoucherEscrowSession> sessions =
        offlineVoucherEscrowSessionsForActiveScope;
    for (final OfflineVoucherEscrowSession session in sessions) {
      if (session.assetContractAddress != asset.contractAddress) {
        continue;
      }
      if (session.availableBaseUnits >= BigInt.from(amountBaseUnits)) {
        return session;
      }
    }
    if (!_hasInternet) {
      throw const SocketException(
        'Connect online once to mint offline voucher inventory before sending with the offline wallet.',
      );
    }
    return _createOfflineVoucherEscrowSession(
      minimumAmountBaseUnits: amountBaseUnits,
      asset: asset,
    );
  }

  Future<OfflineVoucherEscrowSession> _createOfflineVoucherEscrowSession({
    required int minimumAmountBaseUnits,
    required TrackedAssetDefinition asset,
  }) async {
    final String settlementContractAddress =
        offlineVoucherSettlementContractAddress.trim();
    if (settlementContractAddress.isEmpty) {
      throw const FormatException(
        'Set the offline settlement contract address for this chain before using secure offline vouchers.',
      );
    }
    if (_offlineWallet == null) {
      throw const FormatException('Offline wallet is unavailable.');
    }
    final EthereumPreparedContext context = await _ethereumService
        .prepareTransferContext(_offlineWallet!.address);
    final int gasReserve = _applyGasSpeedToWei(context.gasPriceWei) *
        EthereumService.transferGasLimit *
        2;
    final int spendable = offlineSpendableLamports - gasReserve;
    if (spendable <= 0 || minimumAmountBaseUnits > spendable) {
      throw const FormatException(
        'Offline wallet balance is too low to mint voucher inventory after keeping gas reserve.',
      );
    }

    final DateTime createdAt = _clock().toUtc();
    final DateTime expiryAt = createdAt.add(const Duration(hours: 24));
    final OfflineVoucherEscrowSession draft =
        _offlineVoucherService.issueEscrowSession(
          chain: _activeChain,
          network: _activeNetwork,
          senderAddress: _offlineWallet!.address,
          settlementContractAddress: settlementContractAddress,
          assetContractAddress: asset.contractAddress,
          escrowAmountBaseUnits: spendable.toString(),
          spendableAmountBaseUnits: spendable.toString(),
          gasReserveBaseUnits: gasReserve.toString(),
          expiresAt: expiryAt,
          createdAt: createdAt,
        );
    final EthPrivateKey signer = await _walletService.loadEvmSigningCredentials(
      chain: _activeChain,
      offline: true,
      slot: activeAccountSlot,
    );
    final String txHash = await _ethereumService.createOfflineVoucherEscrowNow(
      sender: signer,
      senderAddress: _offlineWallet!.address,
      contractAddress: settlementContractAddress,
      escrowId: draft.commitment.escrowId,
      assetContractAddress: asset.contractAddress,
      amountBaseUnits: spendable,
      expiryAt: expiryAt,
      voucherRoot: draft.commitment.voucherRoot,
    );
    await _ethereumService.waitForConfirmation(txHash);

    final OfflineVoucherEscrowSession session =
        _offlineVoucherService.issueEscrowSession(
          chain: _activeChain,
          network: _activeNetwork,
          senderAddress: _offlineWallet!.address,
          settlementContractAddress: settlementContractAddress,
          assetContractAddress: asset.contractAddress,
          escrowAmountBaseUnits: spendable.toString(),
          spendableAmountBaseUnits: spendable.toString(),
          gasReserveBaseUnits: gasReserve.toString(),
          expiresAt: expiryAt,
          createdAt: createdAt,
          escrowId: draft.commitment.escrowId,
          creationTransactionHash: txHash,
        );

    await _offlineVoucherClientService.registerEscrow(session.commitment);
    for (final OfflineVoucherInventoryEntry entry in session.inventory) {
      await _offlineVoucherClientService.registerProofBundle(entry.proofBundle);
    }
    await _upsertOfflineVoucherEscrowSession(_activeScopeKey, session);
    await refreshWalletData();
    return session;
  }

  Future<PendingTransfer> _sendCurrentDraftOnline({
    required int amountBaseUnits,
    required TrackedAssetDefinition asset,
  }) async {
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (!_hasInternet) {
      throw const SocketException(
        'Internet is required for a direct wallet transfer.',
      );
    }
    final SendQuote quote = await quoteCurrentDraft(
      amountSol: _sendDraft.amountSol,
    );
    if (asset.isNative && quote.totalDebitBaseUnits > _mainBalanceLamports) {
      throw const FormatException(
        'Amount exceeds the available wallet balance after network fees.',
      );
    }
    if (!asset.isNative &&
        (_mainTrackedAssetBalances[asset.id] ?? 0) < amountBaseUnits) {
      throw FormatException(
        'Amount exceeds the available ${asset.symbol} balance.',
      );
    }
    if (quote.networkFeeBaseUnits > _mainBalanceLamports) {
      throw FormatException(
        'Not enough ${_activeChain.assetDisplayLabel} to cover network fees.',
      );
    }
    final int? gasPriceWeiOverride = _activeChain.isEvm
        ? _applyGasSpeedToWei(
            (await _ethereumService.prepareTransferContext(_wallet!.address))
                .gasPriceWei,
          )
        : null;

    final String signature;
    if (_activeChain == ChainKind.solana) {
      final Ed25519HDKeyPair sender = await _walletService.loadSigningKeyPair();
      signature = await _solanaService.sendTransferNow(
        sender: sender,
        receiverAddress: _sendDraft.receiverAddress,
        lamports: amountBaseUnits,
      );
    } else if (asset.isNative) {
      final EthPrivateKey sender = await _walletService.loadEvmSigningCredentials(
        chain: _activeChain,
      );
      signature = await _ethereumService.sendTransferNow(
        sender: sender,
        senderAddress: _wallet!.address,
        receiverAddress: _sendDraft.receiverAddress,
        amountBaseUnits: amountBaseUnits,
        gasPriceWeiOverride: gasPriceWeiOverride,
      );
    } else {
      final EthPrivateKey sender = await _walletService.loadEvmSigningCredentials(
        chain: _activeChain,
      );
      signature = await _ethereumService.sendTokenTransferNow(
        sender: sender,
        senderAddress: _wallet!.address,
        receiverAddress: _sendDraft.receiverAddress,
        contractAddress: asset.contractAddress!,
        amountBaseUnits: amountBaseUnits,
        gasPriceWeiOverride: gasPriceWeiOverride,
      );
    }

    final DateTime createdAt = _clock();
    final PendingTransfer transfer = PendingTransfer(
      transferId: _uuid.v4(),
      chain: _activeChain,
      network: _activeNetwork,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.outbound,
      status: TransferStatus.broadcastSubmitted,
      amountLamports: amountBaseUnits,
      senderAddress: _wallet!.address,
      receiverAddress: _sendDraft.receiverAddress,
      transport: TransportKind.online,
      createdAt: createdAt,
      updatedAt: createdAt,
      assetId: asset.id,
      assetSymbol: asset.symbol,
      assetDisplayName: asset.displayName,
      assetDecimals: asset.decimals,
      assetContractAddress: asset.contractAddress,
      isNativeAsset: asset.isNative,
      remoteEndpoint: 'Direct on-chain',
      transactionSignature: signature,
      explorerUrl:
          (_activeChain == ChainKind.solana
                  ? _solanaService.explorerUrlFor(signature)
                  : _ethereumService.explorerUrlFor(signature))
              .toString(),
    );

    await _persistTransfer(transfer);
    _lastSentTransferId = transfer.transferId;
    clearDraft();
    await refreshWalletData();
    if (_hasInternet) {
      unawaited(_startRealtimeSettlementSync());
      unawaited(refreshSubmittedTransfers());
    }
    return transfer;
  }

  Future<PreparedRelayCapsule> prepareRelayCapsuleForCurrentDraft() async {
    if (_activeWalletEngine != WalletEngine.local) {
      throw const FormatException(
        'Browser relay is only available in Local wallet mode.',
      );
    }
    if (_sendDraft.transport != TransportKind.ultrasonic) {
      throw const FormatException(
        'Browser relay is only available for ultrasonic sessions.',
      );
    }
    final TrackedAssetDefinition asset = _sendAssetDefinitionForDraft(_sendDraft);
    if (_shouldUseOfflineVoucherSettlement(
      asset: asset,
      transport: _sendDraft.transport,
      walletEngine: _activeWalletEngine,
      chain: _activeChain,
    )) {
      throw const FormatException(
        'Browser relay is not available for secure offline voucher settlement. Use Hotspot or Bluetooth.',
      );
    }
    if (_sendDraft.receiverAddress.isEmpty ||
        _sendDraft.receiverSessionToken.isEmpty ||
        _sendDraft.receiverRelayId.isEmpty) {
      throw const FormatException(
        'Scan the receiver QR code before creating a relay capsule.',
      );
    }
    final int lamports = _activeChain.amountToBaseUnits(_sendDraft.amountSol);
    if (lamports <= 0) {
      throw const FormatException('Enter an amount greater than zero.');
    }
    final (
      String transferId,
      DateTime createdAt,
      OfflineEnvelope envelope,
      ValidatedTransactionDetails details
    ) = await _prepareSignedLocalEnvelope(lamports: lamports);
    final UltrasonicTransferPacket packet = _createUltrasonicPacket(envelope);
    final RelayCapsule capsule = await _relayCryptoService.encryptPacket(
      packet: packet,
      relayId: _sendDraft.receiverRelayId,
      sessionToken: _sendDraft.receiverSessionToken,
    );
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
      transport: TransportKind.ultrasonic,
      createdAt: createdAt,
      updatedAt: createdAt,
      envelope: envelope,
      remoteEndpoint: 'Browser courier',
      transactionSignature: details.transactionSignature,
    );
    await _persistTransfer(transfer);
    _lastSentTransferId = transfer.transferId;
    final PreparedRelayCapsule prepared = PreparedRelayCapsule(
      transfer: transfer,
      relayCapsule: capsule,
      relayUrl: _relayClientService.relayImportUri(capsule),
    );
    clearDraft();
    return prepared;
  }

  Future<TransportReceiveResult> importRelayCapsule(
    RelayCapsule capsule,
  ) async {
    final PendingRelaySession? session = _pendingRelaySessions[capsule.relayId];
    if (session == null) {
      throw const FormatException(
        'This relay capsule does not match an active receive session on this device.',
      );
    }
    if (session.isExpired) {
      await _removePendingRelaySession(session.relayId);
      throw const FormatException(
        'This relay capsule expired. Start receive again to mint a fresh session.',
      );
    }
    final UltrasonicTransferPacket packet = await _relayCryptoService
        .decryptCapsule(
          capsule: capsule,
          sessionToken: session.sessionToken,
        );
    return _handleIncomingUltrasonicPacket(packet);
  }

  Future<(
    String transferId,
    DateTime createdAt,
    OfflineEnvelope envelope,
    ValidatedTransactionDetails details
  )> _prepareSignedLocalEnvelope({
    required int lamports,
  }) async {
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
          .loadOfflineSigningKeyPair(slot: activeAccountSlot);
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
          .loadEvmSigningCredentials(
            chain: _activeChain,
            offline: true,
            slot: activeAccountSlot,
          );
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
    return (transferId, createdAt, envelope, details);
  }

  UltrasonicTransferPacket _createUltrasonicPacket(OfflineEnvelope envelope) {
    final UltrasonicTransferPacket packet = UltrasonicTransferPacket.create(
      chain: envelope.chain,
      network: envelope.network,
      transferId: envelope.transferId,
      createdAt: envelope.createdAt,
      sessionToken: _sendDraft.receiverSessionToken,
      signedTransactionBytes: base64Decode(envelope.signedTransactionBase64),
    );
    if (packet.toBytes().length > UltrasonicTransferPacket.maximumEncodedLength) {
      throw const FormatException(
        'Signed payload is too large for ultrasonic delivery. Use browser relay or BLE.',
      );
    }
    return packet;
  }

  Future<TransportReceiveResult> _handleIncomingUltrasonicPacket(
    UltrasonicTransferPacket packet,
  ) async {
    if (!packet.isChecksumValid) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Ultrasonic packet checksum mismatch.',
      );
    }
    final PendingRelaySession? session = _relaySessionForPacket(packet);
    if (session == null) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Receiver session token does not match this ultrasonic packet.',
      );
    }
    final OfflineEnvelope envelope = _buildEnvelopeFromUltrasonicPacket(packet);
    final TransportReceiveResult result = await _handleIncomingEnvelope(envelope);
    if (result.accepted) {
      await _removePendingRelaySession(session.relayId);
      if (_activeUltrasonicSession?.relayId == session.relayId &&
          _ultrasonicListenerRunning) {
        await _createOrRotateActiveUltrasonicSession();
      }
    }
    return result;
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
    _announce(reason);
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

  Future<TransportReceiveResult> _handleIncomingVoucherBundle(
    OfflineVoucherTransferBundle bundle,
  ) async {
    if (_wallet == null) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Receiver wallet is not initialized.',
      );
    }
    if (!bundle.chain.isEvm) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Secure offline vouchers are available only on EVM chains in this build.',
      );
    }
    if (bundle.chain != _activeChain || bundle.network != _activeNetwork) {
      return TransportReceiveResult(
        accepted: false,
        message:
            'Receiver is listening on ${_activeChain.networkLabelFor(_activeNetwork)}, but this voucher bundle is for ${bundle.chain.networkLabelFor(bundle.network)}.',
      );
    }
    if (!bundle.isChecksumValid || !_offlineVoucherService.verifyTransferBundle(bundle)) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Offline voucher bundle verification failed.',
      );
    }
    if (bundle.receiverAddress.toLowerCase() != _wallet!.address.toLowerCase()) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Voucher bundle is not addressed to this wallet.',
      );
    }
    final DateTime now = _clock().toUtc();
    if (bundle.payments.isEmpty) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Offline voucher bundle is empty.',
      );
    }
    for (final OfflineVoucherPayment payment in bundle.payments) {
      if (!payment.isTxIdValid) {
        return const TransportReceiveResult(
          accepted: false,
          message: 'Offline voucher payment integrity check failed.',
        );
      }
      if (payment.voucher.expiryAt.isBefore(now)) {
        return const TransportReceiveResult(
          accepted: false,
          message: 'Offline voucher has already expired.',
        );
      }
      if (payment.proofBundle.isExpired) {
        return const TransportReceiveResult(
          accepted: false,
          message: 'Offline voucher proof bundle has expired.',
        );
      }
      final String? receiverAddress = payment.voucher.receiverAddress;
      if (receiverAddress != null &&
          receiverAddress.isNotEmpty &&
          receiverAddress.toLowerCase() != bundle.receiverAddress.toLowerCase()) {
        return const TransportReceiveResult(
          accepted: false,
          message: 'Offline voucher receiver binding does not match this wallet.',
        );
      }
      final OfflineVoucherClaimAttempt? existingClaim =
          _offlineVoucherClaimAttempts[payment.voucher.voucherId];
      if (existingClaim != null) {
        return const TransportReceiveResult(
          accepted: true,
          message: 'Already received.',
        );
      }
    }
    if (transferById(bundle.transferId) != null ||
        await _store.findByTransferId(bundle.transferId) != null) {
      return const TransportReceiveResult(
        accepted: true,
        message: 'Already received.',
      );
    }

    final TransportKind transport = () {
      final String normalized = bundle.transportHint.trim();
      for (final TransportKind kind in TransportKind.values) {
        if (kind.name == normalized) {
          return kind;
        }
      }
      return _receiveTransport;
    }();
    final TrackedAssetDefinition asset = _nativeAssetForScope(
      bundle.chain,
      bundle.network,
    );
    final PendingTransfer transfer = PendingTransfer(
      transferId: bundle.transferId,
      chain: bundle.chain,
      network: bundle.network,
      walletEngine: WalletEngine.local,
      direction: TransferDirection.inbound,
      status: TransferStatus.receivedPendingBroadcast,
      amountLamports: int.parse(bundle.totalAmountBaseUnits),
      senderAddress: bundle.senderAddress,
      receiverAddress: bundle.receiverAddress,
      transport: transport,
      createdAt: bundle.createdAt,
      updatedAt: _clock(),
      assetId: asset.id,
      assetSymbol: asset.symbol,
      assetDisplayName: asset.displayName,
      assetDecimals: asset.decimals,
      assetContractAddress: asset.contractAddress,
      isNativeAsset: asset.isNative,
      remoteEndpoint: bundle.transportHint,
    );
    await _persistTransfer(transfer);
    await queueOfflineVoucherTransferBundleForSettlement(bundle);
    _lastReceivedTransferId = transfer.transferId;
    return const TransportReceiveResult(
      accepted: true,
      message: 'Stored securely. Claim will be submitted when internet is available.',
    );
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
        'BitGo mode does not use offline receive. Switch to Local mode to listen over hotspot, BLE, or ultrasonic.',
      );
    }
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (_receiveTransport == TransportKind.ble) {
      await requestBlePermissions();
    } else if (_receiveTransport == TransportKind.ultrasonic) {
      await requestUltrasonicPermissions();
      if (!_ultrasonicPermissionsGranted) {
        throw const FormatException(
          'Microphone access is required for ultrasonic receive.',
        );
      }
    }
    await _refreshConnectivityState();
    if (_receiveTransport == TransportKind.hotspot) {
      _ultrasonicListenerRunning = false;
      await _bleTransportService.stop();
      await _ultrasonicTransportService.stop();
      await _hotspotTransportService.start(
        onPayload: _handleIncomingTransportPayload,
        onActivity: _handleReceiverTransportActivity,
      );
    } else if (_receiveTransport == TransportKind.ble) {
      _ultrasonicListenerRunning = false;
      await _hotspotTransportService.stop();
      await _ultrasonicTransportService.stop();
      await _bleTransportService.start(
        onPayload: _handleIncomingTransportPayload,
        receiverChain: _activeChain,
        receiverNetwork: _activeNetwork,
        receiverDisplayAddress: _wallet!.displayAddress,
        receiverAddress: _wallet!.address,
        onActivity: _handleReceiverTransportActivity,
      );
    } else {
      await _hotspotTransportService.stop();
      await _bleTransportService.stop();
      await _createOrRotateActiveUltrasonicSession();
      try {
        await _ultrasonicTransportService.start(
          sessionToken: _activeUltrasonicSession!.sessionToken,
          onPacket: _handleIncomingUltrasonicPacket,
          onActivity: _handleReceiverTransportActivity,
        );
      } catch (_) {
        _announce(
          'Ultrasonic receive is ready. Direct audio delivery is unavailable on this build, but the QR code can still be used for browser relay.',
        );
      }
      _ultrasonicListenerRunning = true;
    }
    notifyListeners();
  }

  Future<void> setSwapApiKey(String value) async {
    final String trimmed = value.trim();
    _swapApiKey = trimmed.isEmpty ? defaultZeroExSwapApiKey : trimmed;
    _effectiveSwapService.apiKey = _swapApiKey;
    await _store.saveSetting('swap_api_key', trimmed);
    notifyListeners();
  }

  Future<void> setSwapSlippageBps(int? value) async {
    _swapSlippageBps = _normalizeSwapSlippageBps(value);
    await _store.saveSetting('swap_slippage_bps', _swapSlippageBps);
    notifyListeners();
  }

  Future<void> stopReceiver() async {
    await _hotspotTransportService.stop();
    await _bleTransportService.stop();
    await _ultrasonicTransportService.stop();
    _ultrasonicListenerRunning = false;
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
    await _syncAllOfflineVoucherTransferStatuses();
    final List<PendingTransfer> submitted = _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.walletEngine == WalletEngine.local &&
              transfer.transactionSignature != null &&
              transfer.transactionSignature!.trim().isNotEmpty &&
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

      _ethereumService.chain = transfer.chain;
      _ethereumService.network = transfer.network;
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
                '${transfer.chain.label} rejected the signed transfer during settlement.',
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
            amountLabel: Formatters.transferAmount(transfer),
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

  List<PendingTransfer> recentActivity() => transferHistory
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
    List<TransferTimelineState> buildTimeline(
      List<_TimelineNode> steps,
      int currentIndex,
    ) {
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
      return buildTimeline(steps, currentIndex);
    }

    if (transfer.isDirectOnchainTransfer) {
      final List<_TimelineNode> steps = <_TimelineNode>[
        const _TimelineNode(
          title: 'Prepared',
          caption:
              'Transaction was prepared and signed locally from the sending wallet.',
        ),
        const _TimelineNode(
          title: 'Submitted',
          caption: 'The chain RPC accepted the transaction signature.',
        ),
        const _TimelineNode(
          title: 'Confirmed',
          caption: 'The transfer reached confirmed status on-chain.',
        ),
      ];
      final int currentIndex = switch (transfer.status) {
        TransferStatus.created => 0,
        TransferStatus.sentOffline ||
        TransferStatus.receivedPendingBroadcast ||
        TransferStatus.broadcasting ||
        TransferStatus.broadcastSubmitted => 1,
        TransferStatus.confirmed => 2,
        TransferStatus.broadcastFailed || TransferStatus.expired => 1,
      };
      return buildTimeline(steps, currentIndex);
    }

    if (transfer.usesVoucherSettlement) {
      final List<_TimelineNode> steps = <_TimelineNode>[
        _TimelineNode(
          title: transfer.isInbound ? 'Accepted offline' : 'Sent offline',
          caption: transfer.isInbound
              ? 'Receiver verified the escrow-backed voucher bundle locally.'
              : 'Escrow-backed voucher bundle was delivered over the local link.',
        ),
        const _TimelineNode(
          title: 'Claiming',
          caption:
              'Bitsend is preparing an on-chain claim against the funded escrow.',
        ),
        const _TimelineNode(
          title: 'Submitted',
          caption:
              'The claim transaction was submitted to the settlement contract.',
        ),
        const _TimelineNode(
          title: 'Confirmed',
          caption: 'The escrow claim is confirmed on-chain.',
        ),
      ];

      final int currentIndex = switch (transfer.status) {
        TransferStatus.created ||
        TransferStatus.sentOffline ||
        TransferStatus.receivedPendingBroadcast => 0,
        TransferStatus.broadcasting => 1,
        TransferStatus.broadcastSubmitted => 2,
        TransferStatus.confirmed => 3,
        TransferStatus.broadcastFailed || TransferStatus.expired => 1,
      };
      return buildTimeline(steps, currentIndex);
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

    return buildTimeline(steps, currentIndex);
  }

  Future<void> clearLocalData() async {
    await _hotspotTransportService.stop();
    await _bleTransportService.stop();
    await _ultrasonicTransportService.stop();
    await _walletService.clearAll();
    await _store.clearAll();
    _pendingRelaySessions.clear();
    _activeUltrasonicSession = null;
    _ultrasonicListenerRunning = false;
    _rpcEndpoints[_scopeKey(ChainKind.solana, ChainNetwork.testnet)] =
        defaultSolanaTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.solana, ChainNetwork.mainnet)] =
        defaultSolanaMainnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.ethereum, ChainNetwork.testnet)] =
        defaultEthereumTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.ethereum, ChainNetwork.mainnet)] =
        defaultEthereumMainnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.base, ChainNetwork.testnet)] =
        defaultBaseTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.base, ChainNetwork.mainnet)] =
        defaultBaseMainnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.bnb, ChainNetwork.testnet)] =
        defaultBnbTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.bnb, ChainNetwork.mainnet)] =
        defaultBnbMainnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.polygon, ChainNetwork.testnet)] =
        defaultPolygonTestnetRpcEndpoint;
    _rpcEndpoints[_scopeKey(ChainKind.polygon, ChainNetwork.mainnet)] =
        defaultPolygonMainnetRpcEndpoint;
    _rpcEndpoint = defaultEthereumTestnetRpcEndpoint;
    _solanaService.rpcEndpoint = defaultSolanaTestnetRpcEndpoint;
    _solanaService.network = ChainNetwork.testnet;
    _ethereumService.chain = ChainKind.ethereum;
    _ethereumService.rpcEndpoint = defaultEthereumTestnetRpcEndpoint;
    _ethereumService.network = ChainNetwork.testnet;
    _activeChain = ChainKind.ethereum;
    _activeNetwork = ChainNetwork.testnet;
    _activeWalletEngine = WalletEngine.local;
    _wallet = null;
    _offlineWallet = null;
    _bitgoWallet = null;
    _bitgoBackendMode = BitGoBackendMode.unknown;
    _wallets.clear();
    _offlineWallets.clear();
    _selectedAccountSlots.clear();
    _accountCounts.clear();
    _walletEngines.clear();
    _bitgoWallets.clear();
    _cachedBlockhash = null;
    _cachedEthereumContext = null;
    _mainBalanceLamports = 0;
    _offlineBalanceLamports = 0;
    _mainBalances.clear();
    _offlineBalances.clear();
    _mainTrackedAssetBalances.clear();
    _offlineTrackedAssetBalances.clear();
    _contacts.clear();
    _allowanceEntries.clear();
    _discoveredTrackedAssets.clear();
    _erc20DiscoveryHighWaterMarks.clear();
    _nftHoldingsByScope.clear();
    _usdPrices.clear();
    _bitgoEndpoint = defaultBitGoBackendEndpoint;
    _bitGoClientService.endpoint = defaultBitGoBackendEndpoint;
    _bitGoClientService.clearSession();
    _fileverseClientService.endpoint = defaultBitGoBackendEndpoint;
    _fileverseClientService.clearSession();
    _swapApiKey = defaultZeroExSwapApiKey;
    _swapSlippageBps = null;
    _effectiveSwapService.apiKey = _swapApiKey;
    _relayClientService.endpoint = defaultBitGoBackendEndpoint;
    _sendDraft = const SendDraft();
    _receiveTransport = TransportKind.hotspot;
    _pendingTransfers = <PendingTransfer>[];
    _bleReceivers = <ReceiverDiscoveryItem>[];
    _bleDiscovering = false;
    _ultrasonicListenerRunning = false;
    _activeUltrasonicSession = null;
    _pendingRelaySessions.clear();
    _offlineVoucherEscrowSessionsByScope.clear();
    _offlineVoucherSettlementContracts.clear();
    _offlineVoucherClaimAttempts.clear();
    _lastSentTransferId = null;
    _lastReceivedTransferId = null;
    _statusMessage = null;
    _announcementMessage = null;
    _deviceAuthAvailable = false;
    _deviceAuthHasBiometricOption = false;
    _deviceUnlocked = true;
    _pendingHomeWidgetRoute = null;
    await _syncHomeScreenWidgets();
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
    _scheduleAutoReadinessRefresh();
    notifyListeners();
  }

  Future<TransportReceiveResult> _handleIncomingEnvelope(
    OfflineEnvelope envelope,
  ) async {
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
    final ValidatedTransactionDetails details =
        envelope.chain == ChainKind.solana
        ? _solanaService.validateEnvelope(envelope)
        : _validateEvmEnvelope(
            envelope,
            chain: envelope.chain,
            network: envelope.network,
          );
    if (details.receiverAddress != _wallet!.address) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Signed transfer is not addressed to this wallet.',
      );
    }
    if (await _store.findByTransferId(envelope.transferId) != null ||
        await _store.findBySignature(details.transactionSignature) != null) {
      _announce('Already received');
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
    notifyListeners();
    if (_hasInternet) {
      unawaited(_broadcastTransferInBackground(transfer));
      unawaited(_startRealtimeSettlementSync());
    }
    return const TransportReceiveResult(
      accepted: true,
      message: 'Stored successfully.',
    );
  }

  OfflineEnvelope _buildEnvelopeFromUltrasonicPacket(
    UltrasonicTransferPacket packet,
  ) {
    final ValidatedTransactionDetails details =
        packet.chain == ChainKind.solana
        ? _validateSolanaSignedTransactionBytes(
            packet.signedTransactionBytes,
            network: packet.network,
          )
        : _validateEvmSignedTransactionBytes(
            packet.signedTransactionBytes,
            chain: packet.chain,
            network: packet.network,
          );
    return OfflineEnvelope.create(
      transferId: packet.transferId,
      createdAt: packet.createdAt,
      chain: packet.chain,
      network: packet.network,
      senderAddress: details.senderAddress,
      receiverAddress: details.receiverAddress,
      amountLamports: details.amountLamports,
      signedTransactionBase64: base64Encode(packet.signedTransactionBytes),
      transportKind: TransportKind.ultrasonic,
    );
  }

  PendingRelaySession? _relaySessionForPacket(UltrasonicTransferPacket packet) {
    for (final PendingRelaySession session in _pendingRelaySessions.values) {
      if (session.sessionToken == packet.sessionToken &&
          session.chain == packet.chain &&
          session.network == packet.network) {
        return session;
      }
    }
    return null;
  }

  Future<void> _createOrRotateActiveUltrasonicSession() async {
    if (_wallet == null) {
      return;
    }
    final PendingRelaySession session = PendingRelaySession(
      relayId: _uuid.v4(),
      sessionToken: _randomSessionToken(),
      chain: _activeChain,
      network: _activeNetwork,
      receiverAddress: _wallet!.address,
      createdAt: _clock(),
    );
    _activeUltrasonicSession = session;
    _pendingRelaySessions[session.relayId] = session;
    await _savePendingRelaySessions();
  }

  Future<void> _loadPendingRelaySessions() async {
    _pendingRelaySessions.clear();
    final List<dynamic>? rawSessions = await _store.loadSetting<List<dynamic>>(
      _relaySessionsKey,
    );
    if (rawSessions == null) {
      return;
    }
    for (final dynamic item in rawSessions) {
      if (item is! Map) {
        continue;
      }
      final PendingRelaySession session = PendingRelaySession.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (session.isExpired) {
        continue;
      }
      _pendingRelaySessions[session.relayId] = session;
    }
    _syncActiveUltrasonicSessionForScope();
  }

  Future<void> _loadOfflineVoucherClaimAttempts() async {
    _offlineVoucherClaimAttempts.clear();
    final List<dynamic>? rawClaims = await _store.loadSetting<List<dynamic>>(
      _offlineVoucherClaimsKey,
    );
    if (rawClaims == null) {
      return;
    }
    for (final dynamic item in rawClaims) {
      if (item is! Map) {
        continue;
      }
      try {
        final OfflineVoucherClaimAttempt claim =
            OfflineVoucherClaimAttempt.fromJson(
              Map<String, dynamic>.from(item),
            );
        _offlineVoucherClaimAttempts[claim.voucherId] = claim;
      } catch (_) {
        // Ignore corrupted persisted queue entries so the app can recover.
      }
    }
    await _syncAllOfflineVoucherTransferStatuses();
  }

  Future<void> _saveOfflineVoucherClaimAttempts() {
    return _store.saveSetting(
      _offlineVoucherClaimsKey,
      _offlineVoucherClaimAttempts.values
          .map((OfflineVoucherClaimAttempt claim) => claim.toJson())
          .toList(growable: false),
    );
  }

  Future<void> _loadOfflineVoucherEscrowSessions() async {
    _offlineVoucherEscrowSessionsByScope.clear();
    final Map<String, dynamic>? raw = await _store.loadSetting<Map<String, dynamic>>(
      _offlineVoucherEscrowSessionsKey,
    );
    if (raw == null) {
      return;
    }
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      if (entry.value is! List) {
        continue;
      }
      final List<OfflineVoucherEscrowSession> sessions =
          <OfflineVoucherEscrowSession>[];
      for (final dynamic item in entry.value as List<dynamic>) {
        if (item is! Map) {
          continue;
        }
        try {
          sessions.add(
            OfflineVoucherEscrowSession.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {
          // Ignore corrupted cached sessions.
        }
      }
      _offlineVoucherEscrowSessionsByScope[entry.key] = sessions;
    }
  }

  Future<void> _saveOfflineVoucherEscrowSessions() {
    final Map<String, Object?> payload = <String, Object?>{
      for (final MapEntry<String, List<OfflineVoucherEscrowSession>> entry
          in _offlineVoucherEscrowSessionsByScope.entries)
        entry.key: entry.value
            .map((OfflineVoucherEscrowSession session) => session.toJson())
            .toList(growable: false),
    };
    return _store.saveSetting(_offlineVoucherEscrowSessionsKey, payload);
  }

  Future<void> _loadOfflineVoucherSettlementContracts() async {
    _offlineVoucherSettlementContracts.clear();
    final Map<String, dynamic>? raw = await _store.loadSetting<Map<String, dynamic>>(
      _offlineVoucherSettlementContractsKey,
    );
    if (raw == null) {
      return;
    }
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final String value = '${entry.value ?? ''}'.trim();
      if (value.isEmpty) {
        continue;
      }
      _offlineVoucherSettlementContracts[entry.key] = value;
    }
  }

  Future<void> _saveOfflineVoucherSettlementContracts() {
    return _store.saveSetting(
      _offlineVoucherSettlementContractsKey,
      _offlineVoucherSettlementContracts,
    );
  }

  Future<void> _upsertOfflineVoucherEscrowSession(
    String scopeKey,
    OfflineVoucherEscrowSession session,
  ) async {
    final List<OfflineVoucherEscrowSession> sessions =
        List<OfflineVoucherEscrowSession>.from(
      _offlineVoucherEscrowSessionsByScope[scopeKey] ??
          const <OfflineVoucherEscrowSession>[],
    );
    final int index = sessions.indexWhere(
      (OfflineVoucherEscrowSession item) =>
          item.commitment.escrowId == session.commitment.escrowId,
    );
    if (index == -1) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
    _offlineVoucherEscrowSessionsByScope[scopeKey] = sessions;
    await _saveOfflineVoucherEscrowSessions();
    notifyListeners();
  }

  Future<void> queueOfflineVoucherTransferBundleForSettlement(
    OfflineVoucherTransferBundle bundle,
  ) async {
    final int slot = _selectedAccountSlots[bundle.chain] ?? 0;
    final DateTime now = _clock().toUtc();
    for (final OfflineVoucherPayment payment in bundle.payments) {
        _offlineVoucherClaimAttempts[payment.voucher.voucherId] =
          OfflineVoucherClaimAttempt(
            version: OfflineVoucherClaimAttempt.currentVersion,
            transferId: bundle.transferId,
            voucherId: payment.voucher.voucherId,
            txId: payment.txId,
            escrowId: payment.voucher.escrowId,
            chain: bundle.chain,
            network: bundle.network,
            accountSlot: slot,
            claimerAddress: bundle.receiverAddress,
            settlementContractAddress: bundle.settlementContractAddress,
            voucher: payment.voucher,
            assignmentSignatureHex: payment.senderSignature,
            voucherProof: payment.proofBundle.voucherProof,
            status: OfflineVoucherClaimStatus.accepted,
            queuedAt: now,
            nextAttemptAt: now,
          );
    }
    await _saveOfflineVoucherClaimAttempts();
    await _syncOfflineVoucherTransferStatus(bundle.transferId);
    notifyListeners();
    if (_hasInternet) {
      unawaited(_processOfflineVoucherClaimQueue());
    }
  }

  Future<OfflineVoucherRefundEligibility?> fetchOfflineVoucherRefundEligibility(
    String escrowId,
  ) {
    return _offlineVoucherClientService.fetchRefundEligibility(escrowId);
  }

  Future<void> _loadDiscoveredTrackedAssets() async {
    _discoveredTrackedAssets.clear();
    final Map<String, dynamic>? raw = await _store.loadSetting<Map<String, dynamic>>(
      _discoveredTrackedAssetsKey,
    );
    if (raw == null) {
      return;
    }
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      if (entry.value is! List) {
        continue;
      }
      final Map<String, TrackedAssetDefinition> assetsForScope =
          <String, TrackedAssetDefinition>{};
      for (final dynamic item in entry.value as List<dynamic>) {
        if (item is! Map) {
          continue;
        }
        try {
          final TrackedAssetDefinition asset = TrackedAssetDefinition.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (asset.isNative) {
            continue;
          }
          assetsForScope[trackedAssetLookupKey(asset)] = asset;
        } catch (_) {
          // Ignore malformed cached asset metadata.
        }
      }
      if (assetsForScope.isNotEmpty) {
        _discoveredTrackedAssets[entry.key] = assetsForScope;
      }
    }
  }

  Future<void> _saveDiscoveredTrackedAssets() async {
    final Map<String, Object?> payload = <String, Object?>{};
    for (final MapEntry<String, Map<String, TrackedAssetDefinition>> entry
        in _discoveredTrackedAssets.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      payload[entry.key] = entry.value.values
          .map((TrackedAssetDefinition asset) => asset.toJson())
          .toList(growable: false);
    }
    await _store.saveSetting(_discoveredTrackedAssetsKey, payload);
  }

  Future<void> _loadErc20DiscoveryHighWaterMarks() async {
    _erc20DiscoveryHighWaterMarks.clear();
    final Map<String, dynamic>? raw = await _store.loadSetting<Map<String, dynamic>>(
      _erc20DiscoveryHighWaterMarksKey,
    );
    if (raw == null) {
      return;
    }
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final Object? value = entry.value;
      if (value is int) {
        _erc20DiscoveryHighWaterMarks[entry.key] = value;
      } else if (value is num) {
        _erc20DiscoveryHighWaterMarks[entry.key] = value.toInt();
      }
    }
  }

  Future<void> _saveErc20DiscoveryHighWaterMarks() async {
    await _store.saveSetting(
      _erc20DiscoveryHighWaterMarksKey,
      _erc20DiscoveryHighWaterMarks,
    );
  }

  Future<void> _savePendingRelaySessions() async {
    await _store.saveSetting(
      _relaySessionsKey,
      _pendingRelaySessions.values
          .map((PendingRelaySession session) => session.toJson())
          .toList(growable: false),
    );
  }

  Future<void> _removePendingRelaySession(String relayId) async {
    _pendingRelaySessions.remove(relayId);
    _syncActiveUltrasonicSessionForScope();
    await _savePendingRelaySessions();
  }

  void _syncActiveUltrasonicSessionForScope() {
    if (_activeWalletEngine != WalletEngine.local || _wallet == null) {
      _activeUltrasonicSession = null;
      return;
    }
    _activeUltrasonicSession = _pendingRelaySessions.values
        .where((PendingRelaySession session) {
          return session.chain == _activeChain &&
              session.network == _activeNetwork &&
              session.receiverAddress == _wallet!.address;
        })
        .fold<PendingRelaySession?>(
          null,
          (PendingRelaySession? latest, PendingRelaySession session) {
            if (latest == null || session.createdAt.isAfter(latest.createdAt)) {
              return session;
            }
            return latest;
          },
        );
  }

  Future<void> _loadContacts() async {
    _contacts.clear();
    final List<dynamic>? raw = await _store.loadSetting<List<dynamic>>(
      _contactsKey,
    );
    if (raw == null) {
      return;
    }
    for (final dynamic item in raw) {
      if (item is! Map) {
        continue;
      }
      try {
        _contacts.add(SendContact.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Ignore malformed cached contacts.
      }
    }
    _contacts.sort((SendContact a, SendContact b) => a.name.compareTo(b.name));
  }

  Future<void> _saveContacts() async {
    await _store.saveSetting(
      _contactsKey,
      _contacts
          .map((SendContact contact) => contact.toJson())
          .toList(growable: false),
    );
  }

  Future<void> _loadAllowanceEntries() async {
    _allowanceEntries.clear();
    final List<dynamic>? raw = await _store.loadSetting<List<dynamic>>(
      _allowanceEntriesKey,
    );
    if (raw == null) {
      return;
    }
    for (final dynamic item in raw) {
      if (item is! Map) {
        continue;
      }
      try {
        _allowanceEntries.add(
          TokenAllowanceEntry.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        // Ignore malformed cached allowance entries.
      }
    }
    _allowanceEntries.sort(
      (TokenAllowanceEntry a, TokenAllowanceEntry b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );
  }

  Future<void> _saveAllowanceEntries() async {
    await _store.saveSetting(
      _allowanceEntriesKey,
      _allowanceEntries
          .map((TokenAllowanceEntry entry) => entry.toJson())
          .toList(growable: false),
    );
  }

  Future<void> _upsertAllowanceEntry(TokenAllowanceEntry entry) async {
    _allowanceEntries.removeWhere(
      (TokenAllowanceEntry existing) => existing.id == entry.id,
    );
    _allowanceEntries.add(entry);
    _allowanceEntries.sort(
      (TokenAllowanceEntry a, TokenAllowanceEntry b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );
    await _saveAllowanceEntries();
    notifyListeners();
  }

  Future<void> _importPendingRelayCapsules() async {
    if (!_hasInternet || _wallet == null || _pendingRelaySessions.isEmpty) {
      return;
    }
    final List<PendingRelaySession> sessions = _pendingRelaySessions.values
        .where((PendingRelaySession session) {
          return session.chain == _activeChain &&
              session.network == _activeNetwork &&
              session.receiverAddress == _wallet!.address;
        })
        .toList(growable: false);
    bool updated = false;
    for (final PendingRelaySession session in sessions) {
      if (session.isExpired) {
        _pendingRelaySessions.remove(session.relayId);
        updated = true;
        continue;
      }
      final RelayCapsule? capsule = await _relayClientService.fetchCapsule(
        session.relayId,
      );
      if (capsule == null) {
        continue;
      }
      try {
        final UltrasonicTransferPacket packet = await _relayCryptoService
            .decryptCapsule(
              capsule: capsule,
              sessionToken: session.sessionToken,
            );
        final TransportReceiveResult result = await _handleIncomingUltrasonicPacket(
          packet,
        );
        if (result.accepted) {
          updated = true;
        }
      } catch (error) {
        _announce(_cleanErrorMessage(error));
        _pendingRelaySessions.remove(session.relayId);
        updated = true;
      }
    }
    if (updated) {
      _syncActiveUltrasonicSessionForScope();
      await _savePendingRelaySessions();
      notifyListeners();
    }
  }

  String _randomSessionToken() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      UltrasonicTransferPacket.sessionTokenLength,
      (_) => random.nextInt(256),
    );
    final StringBuffer buffer = StringBuffer();
    for (final int value in bytes) {
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  void _handleReceiverTransportActivity(TransportActivityNotice notice) {
    _announce(notice.message);
    notifyListeners();
  }

  void _announce(String message) {
    _announcementMessage = message;
    _announcementSerial += 1;
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
      if (transfer.chain.isEvm) {
        _ethereumService.chain = transfer.chain;
        _ethereumService.network = transfer.network;
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
      if (_isAlreadySubmittedBroadcastMessage(message)) {
        final String? signature = transfer.transactionSignature;
        await _persistTransfer(
          transfer.copyWith(
            status: TransferStatus.broadcastSubmitted,
            updatedAt: _clock(),
            transactionSignature: signature,
            explorerUrl: signature == null
                ? transfer.explorerUrl
                : (transfer.chain == ChainKind.solana
                          ? _solanaService.explorerUrlFor(signature)
                          : _ethereumService.explorerUrlFor(signature))
                      .toString(),
            clearLastError: true,
          ),
        );
        unawaited(_startRealtimeSettlementSync());
        return;
      }
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
    _scheduleAutoReadinessRefresh();
    notifyListeners();
  }

  Future<void> _refreshLocalPermissions() async {
    final PermissionStatus bluetoothScan =
        await Permission.bluetoothScan.status;
    final PermissionStatus bluetoothConnect =
        await Permission.bluetoothConnect.status;
    final PermissionStatus bluetoothAdvertise =
        await Permission.bluetoothAdvertise.status;
    final PermissionStatus microphone = await Permission.microphone.status;
    _localPermissionsGranted =
        <PermissionStatus>[
          bluetoothScan,
          bluetoothConnect,
          bluetoothAdvertise,
        ].every((PermissionStatus status) {
          return status == PermissionStatus.granted ||
              status == PermissionStatus.limited;
        });
    _ultrasonicPermissionsGranted =
        microphone == PermissionStatus.granted ||
        microphone == PermissionStatus.limited;
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
          'Connect online so Bitsend can refresh offline send readiness before sending from the offline wallet.',
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
          'Connect online so Bitsend can refresh offline send readiness before sending from the offline wallet.',
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
          _cachedBlockhashKey(_activeReadinessScopeKey),
        );
    if (cachedBlockhashJson != null) {
      _cachedBlockhash = CachedBlockhash.fromJson(cachedBlockhashJson);
    }
    final Map<String, dynamic>? cachedEthereumContextJson = await _store
        .loadSetting<Map<String, dynamic>>(
          _cachedEthereumContextKey(_activeReadinessScopeKey),
        );
    if (cachedEthereumContextJson != null) {
      _cachedEthereumContext = EthereumPreparedContext.fromJson(
        cachedEthereumContextJson,
      );
    }
    _scheduleAutoReadinessRefresh();
  }

  Future<void> _updateCachedBlockhash(CachedBlockhash blockhash) async {
    _cachedBlockhash = blockhash;
    await _store.saveSetting(
      _cachedBlockhashKey(_activeReadinessScopeKey),
      blockhash.toJson(),
    );
    _scheduleAutoReadinessRefresh();
  }

  Future<void> _clearCachedBlockhash() async {
    _cachedBlockhash = null;
    await _store.saveSetting(
      _cachedBlockhashKey(_activeReadinessScopeKey),
      null,
    );
    _scheduleAutoReadinessRefresh();
  }

  Future<void> _updateCachedEthereumContext(
    EthereumPreparedContext context,
  ) async {
    _cachedEthereumContext = context;
    await _store.saveSetting(
      _cachedEthereumContextKey(_activeReadinessScopeKey),
      context.toJson(),
    );
    _scheduleAutoReadinessRefresh();
  }

  bool get _shouldAutoRefreshReadiness {
    return _initialized &&
        _activeWalletEngine == WalletEngine.local &&
        _offlineWallet != null &&
        hasOfflineFunds &&
        _hasInternet;
  }

  bool get _readinessNeedsAutoRefresh {
    if (!_shouldAutoRefreshReadiness) {
      return false;
    }
    if (_activeChain == ChainKind.solana) {
      if (_cachedBlockhash == null) {
        return true;
      }
      final Duration age = _clock().difference(_cachedBlockhash!.fetchedAt);
      return age >=
          blockhashFreshnessWindow - solanaReadinessAutoRefreshLead;
    }
    if (_cachedEthereumContext == null) {
      return true;
    }
    final Duration age = _clock().difference(_cachedEthereumContext!.fetchedAt);
    return age >=
        ethereumContextFreshnessWindow - evmReadinessAutoRefreshLead;
  }

  Duration _nextAutoReadinessRefreshDelay() {
    if (!_shouldAutoRefreshReadiness) {
      return Duration.zero;
    }
    if (_activeChain == ChainKind.solana) {
      if (_cachedBlockhash == null) {
        return Duration.zero;
      }
      final Duration remaining =
          blockhashFreshnessWindow -
          _clock().difference(_cachedBlockhash!.fetchedAt) -
          solanaReadinessAutoRefreshLead;
      return remaining.isNegative ? Duration.zero : remaining;
    }
    if (_cachedEthereumContext == null) {
      return Duration.zero;
    }
    final Duration remaining =
        ethereumContextFreshnessWindow -
        _clock().difference(_cachedEthereumContext!.fetchedAt) -
        evmReadinessAutoRefreshLead;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _scheduleAutoReadinessRefresh({Duration? retryDelay}) {
    _autoReadinessRefreshTimer?.cancel();
    _autoReadinessRefreshTimer = null;
    if (!_shouldAutoRefreshReadiness) {
      return;
    }
    final Duration delay = retryDelay ?? _nextAutoReadinessRefreshDelay();
    _autoReadinessRefreshTimer = Timer(delay, () {
      unawaited(_autoRefreshReadinessIfNeeded());
    });
  }

  Future<void> _autoRefreshReadinessIfNeeded() async {
    _autoReadinessRefreshTimer?.cancel();
    _autoReadinessRefreshTimer = null;
    if (!_shouldAutoRefreshReadiness) {
      return;
    }
    if (_autoRefreshingReadiness) {
      return;
    }
    if (_working) {
      _scheduleAutoReadinessRefresh(
        retryDelay: const Duration(seconds: 5),
      );
      return;
    }
    if (!_readinessNeedsAutoRefresh) {
      _scheduleAutoReadinessRefresh();
      return;
    }

    _autoRefreshingReadiness = true;
    notifyListeners();
    final String scopeKey = _activeScopeKey;
    final ChainKind chain = _activeChain;
    final ChainNetwork network = _activeNetwork;
    final String? offlineAddress = _offlineWallet?.address;
    bool refreshed = false;
    try {
      if (offlineAddress == null) {
        return;
      }
      if (chain == ChainKind.solana) {
        final CachedBlockhash blockhash = await _solanaService
            .getFreshBlockhash();
        if (_activeScopeKey == scopeKey &&
            _activeChain == chain &&
            _activeNetwork == network &&
            _activeWalletEngine == WalletEngine.local &&
            _offlineWallet?.address == offlineAddress) {
          await _updateCachedBlockhash(blockhash);
          refreshed = true;
        }
      } else {
        final EthereumPreparedContext context = await _ethereumService
            .prepareTransferContext(offlineAddress);
        if (_activeScopeKey == scopeKey &&
            _activeChain == chain &&
            _activeNetwork == network &&
            _activeWalletEngine == WalletEngine.local &&
            _offlineWallet?.address == offlineAddress) {
          await _updateCachedEthereumContext(context);
          refreshed = true;
        }
      }
    } catch (_) {
      _scheduleAutoReadinessRefresh(retryDelay: readinessAutoRetryDelay);
    } finally {
      _autoRefreshingReadiness = false;
      if (!refreshed) {
        _scheduleAutoReadinessRefresh(
          retryDelay: _shouldAutoRefreshReadiness
              ? readinessAutoRetryDelay
              : null,
        );
      } else {
        _scheduleAutoReadinessRefresh();
      }
      notifyListeners();
    }
  }

  Future<void> _startRealtimeSettlementSync() async {
    if (_realtimeSettlementSyncRunning || !_hasInternet || _wallet == null) {
      return;
    }
    _realtimeSettlementSyncRunning = true;
    try {
      for (
        int attempt = 0;
        attempt < realtimeSettlementPollAttempts;
        attempt++
      ) {
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

  Future<void> _processOfflineVoucherClaimQueue() async {
    if (_offlineVoucherClaimSyncRunning ||
        !_hasInternet ||
        _offlineVoucherClaimAttempts.isEmpty) {
      return;
    }
    _offlineVoucherClaimSyncRunning = true;
    try {
      final DateTime now = _clock().toUtc();
      final List<OfflineVoucherClaimAttempt> dueClaims =
          _offlineVoucherClaimAttempts.values
              .where(
                (OfflineVoucherClaimAttempt claim) =>
                    !claim.isTerminal &&
                    !claim.nextAttemptAt.isAfter(now),
              )
              .toList(growable: false)
            ..sort(
              (
                OfflineVoucherClaimAttempt a,
                OfflineVoucherClaimAttempt b,
              ) => a.nextAttemptAt.compareTo(b.nextAttemptAt),
            );
      for (final OfflineVoucherClaimAttempt claim in dueClaims) {
        await _processSingleOfflineVoucherClaim(claim);
      }
    } finally {
      _offlineVoucherClaimSyncRunning = false;
      _applyActiveChainSnapshot();
    }
  }

  Future<void> _processSingleOfflineVoucherClaim(
    OfflineVoucherClaimAttempt claim,
  ) async {
    final DateTime now = _clock().toUtc();
    if (!claim.chain.isEvm) {
      await _persistOfflineVoucherClaimAttempt(
        claim.copyWith(
          status: OfflineVoucherClaimStatus.invalidRejected,
          lastAttemptedAt: now,
          lastError:
              'Offline voucher settlement is EVM-only in this build.',
        ),
      );
      return;
    }

    final OfflineVoucherClaimSubmission submission =
        OfflineVoucherClaimSubmission(
          version: OfflineVoucherClaimSubmission.currentVersion,
          voucherId: claim.voucherId,
          txId: claim.txId,
          escrowId: claim.escrowId,
          claimerAddress: claim.claimerAddress,
          createdAt: now,
        );

    try {
      final OfflineVoucherClaimRecord backendClaim =
          await _offlineVoucherClientService.submitClaim(submission);
      if (backendClaim.status == OfflineVoucherClaimStatus.expiredRejected ||
          backendClaim.status == OfflineVoucherClaimStatus.invalidRejected ||
          backendClaim.status == OfflineVoucherClaimStatus.duplicateRejected) {
        await _persistOfflineVoucherClaimAttempt(
          claim.copyWith(
            status: backendClaim.status,
            submissionMode: backendClaim.submissionMode,
            lastAttemptedAt: now,
            lastError: backendClaim.lastError ?? backendClaim.status.name,
          ),
        );
        return;
      }
    } on FormatException catch (error) {
      await _scheduleOfflineVoucherClaimRetry(
        claim,
        error.message,
        attemptedAt: now,
      );
      return;
    }

    _ethereumService
      ..chain = claim.chain
      ..network = claim.network
      ..rpcEndpoint =
          _rpcEndpoints[_scopeKey(claim.chain, claim.network)] ??
          _defaultRpcEndpointFor(claim.chain, claim.network);

    try {
      final bool alreadyClaimed = await _ethereumService.isOfflineVoucherClaimed(
        contractAddress: claim.settlementContractAddress,
        voucherId: claim.voucherId,
      );
      if (alreadyClaimed) {
        await _offlineVoucherClientService.updateClaimSettlement(
          OfflineVoucherClaimSettlementUpdate(
            version: OfflineVoucherClaimSettlementUpdate.currentVersion,
            voucherId: claim.voucherId,
            txId: claim.txId,
            escrowId: claim.escrowId,
            status: OfflineVoucherClaimStatus.confirmedOnchain,
            updatedAt: now,
          ),
        );
        await _persistOfflineVoucherClaimAttempt(
          claim.copyWith(
            status: OfflineVoucherClaimStatus.confirmedOnchain,
            lastAttemptedAt: now,
            confirmedAt: now,
            clearLastError: true,
          ),
        );
        return;
      }

      if (claim.submittedTransactionHash != null &&
          claim.submittedTransactionHash!.isNotEmpty) {
        final TransactionReceipt? receipt = await _ethereumService
            .getTransactionReceipt(claim.submittedTransactionHash!);
        if (receipt == null) {
          await _persistOfflineVoucherClaimAttempt(
            claim.copyWith(
              status: OfflineVoucherClaimStatus.submittedOnchain,
              lastAttemptedAt: now,
              nextAttemptAt: now.add(offlineVoucherClaimReceiptPollDelay),
            ),
          );
          return;
        }
        if (receipt.status == true) {
          await _offlineVoucherClientService.updateClaimSettlement(
            OfflineVoucherClaimSettlementUpdate(
              version: OfflineVoucherClaimSettlementUpdate.currentVersion,
              voucherId: claim.voucherId,
              txId: claim.txId,
              escrowId: claim.escrowId,
              status: OfflineVoucherClaimStatus.confirmedOnchain,
              updatedAt: now,
              settlementTransactionHash: claim.submittedTransactionHash,
            ),
          );
          await _persistOfflineVoucherClaimAttempt(
            claim.copyWith(
              status: OfflineVoucherClaimStatus.confirmedOnchain,
              lastAttemptedAt: now,
              confirmedAt: now,
              clearLastError: true,
            ),
          );
          return;
        }
        await _scheduleOfflineVoucherClaimRetry(
          claim.copyWith(submittedTransactionHash: ''),
          '${claim.chain.label} rejected the offline voucher claim transaction.',
          attemptedAt: now,
        );
        return;
      }

      final EthPrivateKey signer = await _walletService.loadEvmSigningCredentials(
        chain: claim.chain,
        account: claim.accountSlot,
      );
      final String signerAddress = (await signer.extractAddress()).hexEip55;
      if (signerAddress.toLowerCase() != claim.claimerAddress.toLowerCase()) {
        await _persistOfflineVoucherClaimAttempt(
          claim.copyWith(
            status: OfflineVoucherClaimStatus.invalidRejected,
            lastAttemptedAt: now,
            lastError:
                'The queued receiver account is no longer available on this device.',
          ),
        );
        return;
      }

      final String transactionHash = await _ethereumService.claimOfflineVoucherNow(
        sender: signer,
        senderAddress: signerAddress,
        contractAddress: claim.settlementContractAddress,
        voucher: claim.voucher,
        receiverAddress: claim.claimerAddress,
        assignmentSignatureHex: claim.assignmentSignatureHex,
        voucherProof: claim.voucherProof,
      );

      final OfflineVoucherClaimRecord settled =
          await _offlineVoucherClientService.updateClaimSettlement(
            OfflineVoucherClaimSettlementUpdate(
              version: OfflineVoucherClaimSettlementUpdate.currentVersion,
              voucherId: claim.voucherId,
              txId: claim.txId,
              escrowId: claim.escrowId,
              status: OfflineVoucherClaimStatus.submittedOnchain,
              updatedAt: now,
              settlementTransactionHash: transactionHash,
            ),
          );
      await _persistOfflineVoucherClaimAttempt(
        claim.copyWith(
          status: OfflineVoucherClaimStatus.submittedOnchain,
          submissionMode: settled.submissionMode,
          attemptCount: claim.attemptCount + 1,
          lastAttemptedAt: now,
          submittedTransactionHash: transactionHash,
          nextAttemptAt: now.add(offlineVoucherClaimReceiptPollDelay),
          clearLastError: true,
        ),
      );
    } catch (error) {
      await _scheduleOfflineVoucherClaimRetry(
        claim,
        error.toString(),
        attemptedAt: now,
      );
    }
  }

  Future<void> _scheduleOfflineVoucherClaimRetry(
    OfflineVoucherClaimAttempt claim,
    String message, {
    required DateTime attemptedAt,
  }) async {
    final int nextAttemptCount = claim.attemptCount + 1;
    bool sponsoredFallbackRequested = claim.sponsoredFallbackRequested;
    OfflineVoucherClaimSubmissionMode? submissionMode = claim.submissionMode;
    if (!sponsoredFallbackRequested &&
        nextAttemptCount >= offlineVoucherClaimSponsorThreshold) {
      try {
        final OfflineVoucherClaimRecord sponsored =
            await _offlineVoucherClientService.requestSponsoredClaim(
              OfflineVoucherClaimSubmission(
                version: OfflineVoucherClaimSubmission.currentVersion,
                voucherId: claim.voucherId,
                txId: claim.txId,
                escrowId: claim.escrowId,
                claimerAddress: claim.claimerAddress,
                createdAt: attemptedAt,
              ),
            );
        sponsoredFallbackRequested = true;
        submissionMode = sponsored.submissionMode;
      } catch (_) {
        // Keep local retries active even if the sponsored queue could not be registered.
      }
    }

    await _persistOfflineVoucherClaimAttempt(
      claim.copyWith(
        status: claim.submittedTransactionHash != null &&
                claim.submittedTransactionHash!.isNotEmpty
            ? OfflineVoucherClaimStatus.submittedOnchain
            : OfflineVoucherClaimStatus.accepted,
        submissionMode: submissionMode,
        attemptCount: nextAttemptCount,
        lastAttemptedAt: attemptedAt,
        nextAttemptAt: attemptedAt.add(
          _offlineVoucherClaimRetryDelay(nextAttemptCount),
        ),
        sponsoredFallbackRequested: sponsoredFallbackRequested,
        lastError: message,
      ),
    );
  }

  Duration _offlineVoucherClaimRetryDelay(int attemptCount) {
    if (attemptCount <= 1) {
      return offlineVoucherClaimRetryBaseDelay;
    }
    final int multiplier = 1 << (attemptCount - 1);
    final int delayMs =
        offlineVoucherClaimRetryBaseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: min(
        delayMs,
        offlineVoucherClaimRetryMaxDelay.inMilliseconds,
      ),
    );
  }

  Future<void> _persistOfflineVoucherClaimAttempt(
    OfflineVoucherClaimAttempt claim,
  ) async {
    _offlineVoucherClaimAttempts[claim.voucherId] = claim;
    await _saveOfflineVoucherClaimAttempts();
    await _syncOfflineVoucherTransferStatus(claim.transferId);
    notifyListeners();
  }

  Future<void> _syncAllOfflineVoucherTransferStatuses() async {
    final Set<String> transferIds = _offlineVoucherClaimAttempts.values
        .map((OfflineVoucherClaimAttempt claim) => claim.transferId)
        .where((String transferId) => transferId.isNotEmpty)
        .toSet();
    for (final String transferId in transferIds) {
      await _syncOfflineVoucherTransferStatus(transferId);
    }
  }

  Future<void> _syncOfflineVoucherTransferStatus(String transferId) async {
    if (transferId.isEmpty) {
      return;
    }
    final PendingTransfer? transfer = transferById(transferId);
    if (transfer == null || !transfer.usesVoucherSettlement) {
      return;
    }
    final List<OfflineVoucherClaimAttempt> claims =
        _offlineVoucherClaimAttempts.values
            .where((OfflineVoucherClaimAttempt claim) => claim.transferId == transferId)
            .toList(growable: false);
    if (claims.isEmpty) {
      return;
    }

    final bool allConfirmed = claims.every(
      (OfflineVoucherClaimAttempt claim) =>
          claim.status == OfflineVoucherClaimStatus.confirmedOnchain,
    );
    final bool anyRejected = claims.any(
      (OfflineVoucherClaimAttempt claim) =>
          claim.status == OfflineVoucherClaimStatus.invalidRejected ||
          claim.status == OfflineVoucherClaimStatus.duplicateRejected,
    );
    final bool anyExpired = claims.any(
      (OfflineVoucherClaimAttempt claim) =>
          claim.status == OfflineVoucherClaimStatus.expiredRejected,
    );
    final bool anySubmitted = claims.any(
      (OfflineVoucherClaimAttempt claim) =>
          claim.status == OfflineVoucherClaimStatus.submittedOnchain ||
          claim.status == OfflineVoucherClaimStatus.confirmedOnchain,
    );
    final bool anyAttempted = claims.any(
      (OfflineVoucherClaimAttempt claim) =>
          claim.attemptCount > 0 || claim.lastAttemptedAt != null,
    );
    final String? settlementHash = claims
        .map((OfflineVoucherClaimAttempt claim) => claim.submittedTransactionHash)
        .whereType<String>()
        .firstWhere(
          (String value) => value.trim().isNotEmpty,
          orElse: () => '',
        )
        .trim()
        .isEmpty
        ? null
        : claims
            .map((OfflineVoucherClaimAttempt claim) => claim.submittedTransactionHash)
            .whereType<String>()
            .firstWhere((String value) => value.trim().isNotEmpty);
    final List<String> errors = claims
        .map((OfflineVoucherClaimAttempt claim) => claim.lastError?.trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final DateTime? confirmedAt = claims
        .map((OfflineVoucherClaimAttempt claim) => claim.confirmedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (DateTime? latest, DateTime current) {
          if (latest == null || current.isAfter(latest)) {
            return current;
          }
          return latest;
        });

    final TransferStatus nextStatus = allConfirmed
        ? TransferStatus.confirmed
        : anyRejected
        ? TransferStatus.broadcastFailed
        : anyExpired
        ? TransferStatus.expired
        : anySubmitted
        ? TransferStatus.broadcastSubmitted
        : anyAttempted
        ? TransferStatus.broadcasting
        : TransferStatus.receivedPendingBroadcast;
    final String? nextError = switch (nextStatus) {
      TransferStatus.broadcastFailed || TransferStatus.expired => errors.isEmpty
          ? null
          : errors.join(' '),
      _ => null,
    };
    if (transfer.status == nextStatus &&
        transfer.transactionSignature == settlementHash &&
        transfer.confirmedAt == confirmedAt &&
        transfer.lastError == nextError) {
      return;
    }
    await _persistTransfer(
      transfer.copyWith(
        status: nextStatus,
        updatedAt: _clock(),
        transactionSignature: settlementHash,
        explorerUrl: settlementHash == null || !transfer.chain.isEvm
            ? transfer.explorerUrl
            : _ethereumService
                .explorerUrlFor(settlementHash)
                .toString(),
        confirmedAt: confirmedAt,
        lastError: nextError,
        clearLastError: nextError == null,
      ),
    );
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

    if (transfer.chain.isEvm) {
      _ethereumService.chain = transfer.chain;
      _ethereumService.network = transfer.network;
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
                '${transfer.chain.label} rejected the signed transfer during settlement.',
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

  bool _isAlreadySubmittedBroadcastMessage(String message) {
    final String normalized = message.toLowerCase();
    return normalized.contains('already known') ||
        normalized.contains('already imported') ||
        normalized.contains('known transaction') ||
        normalized.contains('already been processed') ||
        normalized.contains('already processed') ||
        normalized.contains('transaction already exists') ||
        (normalized.contains('duplicate') &&
            (normalized.contains('transaction') ||
                normalized.contains('signature')));
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
          'BitGo wallet is not configured for ${_activeNetwork.labelFor(_activeChain)}.',
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
    final BitGoDemoSession session = await _bitGoClientService.createSession();
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

  Future<void> _runStartupNetworkSync() async {
    try {
      await _refreshConnectivityState();
      if (_wallet == null || !_hasInternet) {
        notifyListeners();
        return;
      }
      if (_activeWalletEngine == WalletEngine.bitgo) {
        await _refreshBitGoBackendHealth(allowFailure: true);
      }
      await refreshWalletData();
      await broadcastPendingTransfers();
      await refreshSubmittedTransfers();
      await _processOfflineVoucherClaimQueue();
    } catch (_) {
      notifyListeners();
    }
  }

  bool _hasRealtimeSettlementPendingForActiveScope() {
    return _pendingTransfers.any((PendingTransfer transfer) {
      if (transfer.chain != _activeChain ||
          transfer.network != _activeNetwork) {
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
    return _ethereumEnsService.resolveEnsAddress(value);
  }

  Future<EnsPaymentPreference> readEthereumEnsPaymentPreference(String value) {
    return _ethereumEnsService.readEnsPaymentPreference(value);
  }

  Future<List<String>> saveEthereumEnsPaymentPreference({
    required String ensName,
    required String preferredChain,
    required String preferredToken,
  }) async {
    final WalletProfile? wallet = _wallets[ChainKind.ethereum] ?? _wallet;
    if (wallet == null) {
      throw const FormatException(
        'Create or restore an Ethereum wallet first.',
      );
    }
    await _refreshConnectivityState();
    if (!_hasInternet) {
      throw const SocketException(
        'Internet is required to read or write ENS text records.',
      );
    }
    return _runTaskWithResult<List<String>>(
      'Saving ENS payment preference...',
      () async {
        final EthPrivateKey signer = await _walletService
            .loadEthereumSigningCredentials();
        return _ethereumEnsService.writeEnsPaymentPreference(
          signer: signer,
          name: ensName,
          preferredChain: preferredChain,
          preferredToken: preferredToken,
        );
      },
    );
  }

  int _estimatedEthereumFeeHeadroom() {
    final EthereumPreparedContext? context = _cachedEthereumContext;
    if (context == null) {
      return _activeChain.fallbackFeeHeadroomBaseUnits;
    }
    return context.gasPriceWei * EthereumService.transferGasLimit;
  }

  static const String _relaySessionsKey = 'pending_relay_sessions';
  static const String _offlineVoucherEscrowSessionsKey =
      'offline_voucher_escrow_sessions';
  static const String _offlineVoucherSettlementContractsKey =
      'offline_voucher_settlement_contracts';
  static const String _offlineVoucherClaimsKey = 'offline_voucher_claims';
  static const String _contactsKey = 'send_contacts';
  static const String _allowanceEntriesKey = 'token_allowance_entries';
  static const String _selectedAccountSlotsKey = 'selected_account_slots';
  static const String _accountCountsKey = 'account_counts';
  static const String _discoveredTrackedAssetsKey = 'discovered_tracked_assets';
  static const String _erc20DiscoveryHighWaterMarksKey =
      'erc20_discovery_high_water_marks';

  String _cachedBlockhashKey(String scopeKey) => 'cached_blockhash_$scopeKey';

  String _cachedEthereumContextKey(String scopeKey) =>
      'cached_eth_context_$scopeKey';

  String _walletEngineKey(String scopeKey) => 'wallet_engine_$scopeKey';

  String _erc20DiscoveryCursorKey(String scopeKey, String address) =>
      '$scopeKey:${address.trim().toLowerCase()}';

  int _initialErc20DiscoveryStartBlock(int latestBlock) {
    final int startBlock =
        latestBlock - erc20InitialDiscoveryLookbackBlocks + 1;
    return startBlock < 0 ? 0 : startBlock;
  }

  int _applyGasSpeedToWei(int gasPriceWei) {
    return (gasPriceWei * _sendDraft.gasSpeed.multiplier).round();
  }

  Uint8List _decodeDappPayloadBytes(DappSignRequest request) {
    final String payloadHex = (request.payloadHex ?? '').trim();
    if (payloadHex.startsWith('0x') &&
        payloadHex.length > 2 &&
        payloadHex.length.isEven) {
      try {
        final List<int> bytes = <int>[];
        for (int index = 2; index < payloadHex.length; index += 2) {
          bytes.add(
            int.parse(payloadHex.substring(index, index + 2), radix: 16),
          );
        }
        return Uint8List.fromList(bytes);
      } catch (_) {
        // Fall back to utf8 bytes.
      }
    }
    final String text = request.message ?? payloadHex;
    return Uint8List.fromList(utf8.encode(text));
  }

  TrackedAssetDefinition _nativeAssetForScope(
    ChainKind chain,
    ChainNetwork network,
  ) {
    return _trackedAssetsForScope(
      chain,
      network,
    ).firstWhere((TrackedAssetDefinition asset) => asset.isNative);
  }

  String _defaultSendAssetIdFor(ChainKind chain, ChainNetwork network) =>
      _nativeAssetForScope(chain, network).id;

  TrackedAssetDefinition _sendAssetDefinitionForDraft(SendDraft draft) {
    return _sendAssetDefinitionFor(
      chain: draft.chain,
      network: draft.network,
      assetId: draft.assetId,
    );
  }

  TrackedAssetDefinition _sendAssetDefinitionFor({
    required ChainKind chain,
    required ChainNetwork network,
    required String assetId,
  }) {
    final List<TrackedAssetDefinition> assets = _trackedAssetsForScope(
      chain,
      network,
    );
    if (assetId.isNotEmpty) {
      for (final TrackedAssetDefinition asset in assets) {
        if (asset.id == assetId) {
          return asset;
        }
      }
    }
    return assets.firstWhere((TrackedAssetDefinition asset) => asset.isNative);
  }

  AssetPortfolioHolding _holdingForTrackedAsset(TrackedAssetDefinition asset) {
    for (final AssetPortfolioHolding holding in portfolioHoldings) {
      if (holding.chain == asset.chain &&
          holding.network == asset.network &&
          holding.resolvedAssetId == asset.id) {
        return holding;
      }
    }
    return AssetPortfolioHolding(
      chain: asset.chain,
      network: asset.network,
      totalBalance: 0,
      mainBalance: 0,
      protectedBalance: 0,
      spendableBalance: 0,
      reservedBalance: 0,
      assetId: asset.id,
      symbol: asset.symbol,
      displayName: asset.displayName,
      assetDecimals: asset.decimals,
      contractAddress: asset.contractAddress,
      isNative: asset.isNative,
      mainAddress: _wallets[asset.chain]?.address,
      protectedAddress: _offlineWallets[asset.chain]?.address,
    );
  }

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

  EthereumService get _ethereumEnsService {
    final EthereumService service = EthereumService(
      rpcEndpoint:
          _rpcEndpoints[_scopeKey(ChainKind.ethereum, ChainNetwork.mainnet)] ??
          defaultEthereumMainnetRpcEndpoint,
    );
    service.chain = ChainKind.ethereum;
    service.network = ChainNetwork.mainnet;
    return service;
  }

  ValidatedTransactionDetails _validateEvmEnvelope(
    OfflineEnvelope envelope, {
    required ChainKind chain,
    required ChainNetwork network,
  }) {
    _ethereumService.chain = chain;
    _ethereumService.network = network;
    return _ethereumService.validateEnvelope(envelope);
  }

  ValidatedTransactionDetails _validateEvmSignedTransactionBytes(
    Uint8List bytes, {
    required ChainKind chain,
    required ChainNetwork network,
  }) {
    _ethereumService.chain = chain;
    _ethereumService.network = network;
    return _ethereumService.validateSignedTransactionBytes(bytes);
  }

  ValidatedTransactionDetails _validateSolanaSignedTransactionBytes(
    Uint8List bytes, {
    required ChainNetwork network,
  }) {
    _solanaService.network = network;
    return _solanaService.validateSignedTransactionBytes(bytes);
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
    _homeWidgetLaunchRouteSubscription?.cancel();
    _autoReadinessRefreshTimer?.cancel();
    unawaited(_hotspotTransportService.stop());
    unawaited(_bleTransportService.dispose());
    unawaited(_ultrasonicTransportService.stop());
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

  int _parseFlexibleInt(Object? value) {
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
}

class _TimelineNode {
  const _TimelineNode({required this.title, required this.caption});

  final String title;
  final String caption;
}
