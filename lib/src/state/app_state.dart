import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solana/dto.dart' show ConfirmationStatus, SignatureStatus;
import 'package:solana/solana.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../services/ble_transport_service.dart';
import '../services/hotspot_transport_service.dart';
import '../services/local_store.dart';
import '../services/solana_service.dart';
import '../services/transport_contract.dart';
import '../services/wallet_service.dart';

const double minimumFundingSol = 0.05;
const int solFeeHeadroomLamports = 10000;
const Duration blockhashFreshnessWindow = Duration(seconds: 75);
const String defaultRpcEndpoint = 'https://api.devnet.solana.com';

class BitsendAppState extends ChangeNotifier {
  BitsendAppState({
    LocalStore? store,
    WalletService? walletService,
    HotspotTransportService? transportService,
    BleTransportService? bleTransportService,
    Connectivity? connectivity,
    NetworkInfo? networkInfo,
    SolanaService? solanaService,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _store = store ?? LocalStore(),
       _walletService = walletService ?? WalletService(),
       _hotspotTransportService = transportService ?? HotspotTransportService(),
       _bleTransportService = bleTransportService ?? BleTransportService(),
       _connectivity = connectivity ?? Connectivity(),
       _networkInfo = networkInfo ?? NetworkInfo(),
       _solanaService = solanaService ?? SolanaService(rpcEndpoint: defaultRpcEndpoint),
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final WalletService _walletService;
  final HotspotTransportService _hotspotTransportService;
  final BleTransportService _bleTransportService;
  final Connectivity _connectivity;
  final NetworkInfo _networkInfo;
  final SolanaService _solanaService;
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
  WalletProfile? _wallet;
  WalletProfile? _offlineWallet;
  CachedBlockhash? _cachedBlockhash;
  int _mainBalanceLamports = 0;
  int _offlineBalanceLamports = 0;
  String _rpcEndpoint = defaultRpcEndpoint;
  SendDraft _sendDraft = const SendDraft();
  TransportKind _receiveTransport = TransportKind.hotspot;
  String? _lastSentTransferId;
  String? _lastReceivedTransferId;
  List<PendingTransfer> _pendingTransfers = <PendingTransfer>[];
  List<ReceiverDiscoveryItem> _bleReceivers = <ReceiverDiscoveryItem>[];
  bool _bleDiscovering = false;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get working => _working;
  String? get statusMessage => _statusMessage;
  WalletProfile? get wallet => _wallet;
  WalletProfile? get offlineWallet => _offlineWallet;
  bool get hasWallet => _wallet != null;
  bool get hasOfflineWallet => _offlineWallet != null;
  bool get hasInternet => _hasInternet;
  bool get hasLocalLink => _hasLocalLink;
  bool get hasDevnet => _hasDevnet;
  bool get localPermissionsGranted => _localPermissionsGranted;
  bool get hasOfflineReadyBlockhash =>
      _cachedBlockhash != null && !_isCachedBlockhashExpired;
  bool get hasEnoughFunding => mainBalanceSol >= minimumFundingSol;
  bool get hasOfflineFunds => offlineSpendableLamports > 0;
  double get mainBalanceSol => _mainBalanceLamports / lamportsPerSol;
  double get offlineBalanceSol => _offlineBalanceLamports / lamportsPerSol;
  double get offlineSpendableBalanceSol =>
      offlineSpendableLamports / lamportsPerSol;
  String get rpcEndpoint => _rpcEndpoint;
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
  );

  int get reservedOfflineLamports => _pendingTransfers
      .where((PendingTransfer transfer) {
        return transfer.direction == TransferDirection.outbound &&
            transfer.senderAddress == _offlineWallet?.address &&
            transfer.status == TransferStatus.sentOffline;
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
    balanceSol: mainBalanceSol,
    offlineBalanceSol: offlineBalanceSol,
    offlineAvailableSol: offlineSpendableBalanceSol,
    offlineWalletAddress: _offlineWallet?.address,
    readyForOffline: hasOfflineReadyBlockhash,
    blockhashAge: _cachedBlockhash == null
        ? null
        : _clock().difference(_cachedBlockhash!.fetchedAt),
    localEndpoint: localEndpoint,
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

  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    notifyListeners();

    try {
      _rpcEndpoint =
          await _walletService.loadRpcEndpoint() ?? defaultRpcEndpoint;
      _solanaService.rpcEndpoint = _rpcEndpoint;
      _wallet = await _walletService.loadWallet();
      _offlineWallet = await _walletService.loadOfflineWallet();

      final Map<String, dynamic>? cachedBlockhashJson = await _store
          .loadSetting<Map<String, dynamic>>('cached_blockhash');
      if (cachedBlockhashJson != null) {
        _cachedBlockhash = CachedBlockhash.fromJson(cachedBlockhashJson);
      }

      _pendingTransfers = await _store.loadTransfers();
      await _refreshLocalPermissions();
      await _refreshConnectivityState();
      if (_wallet != null) {
        await refreshWalletData();
        if (_hasInternet) {
          await broadcastPendingInboundTransfers();
          await refreshSubmittedTransfers();
        }
      }

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        _,
      ) async {
        await _refreshConnectivityState();
        if (_hasInternet) {
          await refreshWalletData();
          await broadcastPendingInboundTransfers();
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
    _wallet = await _walletService.createWallet();
    _offlineWallet = await _walletService.loadOfflineWallet();
    notifyListeners();
  }

  Future<void> restoreWallet(String seedPhrase) async {
    _wallet = await _walletService.restoreWallet(seedPhrase);
    _offlineWallet = await _walletService.loadOfflineWallet();
    notifyListeners();
  }

  Future<void> refreshWalletData() async {
    if (_wallet == null) {
      return;
    }

    try {
      _mainBalanceLamports = await _solanaService.getBalanceLamports(
        _wallet!.address,
      );
      _offlineBalanceLamports = _offlineWallet == null
          ? 0
          : await _solanaService.getBalanceLamports(_offlineWallet!.address);
      _hasDevnet = true;
      _hasInternet = true;
      _statusMessage = null;
      try {
        await _syncCachedBlockhashValidity();
      } catch (_) {
        await _clearCachedBlockhash();
      }
    } catch (error) {
      _hasDevnet = false;
      _hasInternet = false;
      _statusMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> requestAirdrop({bool toOfflineWallet = false}) async {
    final WalletProfile? targetWallet = toOfflineWallet
        ? _offlineWallet
        : _wallet;
    if (targetWallet == null) {
      return;
    }
    await _runTask(
      toOfflineWallet
          ? 'Requesting offline wallet devnet airdrop...'
          : 'Requesting devnet airdrop...',
      () async {
        await _refreshConnectivityState();
        if (!_hasDevnet) {
          throw const SocketException(
            'Solana devnet RPC is unavailable right now.',
          );
        }
        await _solanaService.requestAirdrop(targetWallet.address, sol: 1);
        await refreshWalletData();
      },
    );
  }

  Future<void> prepareForOffline() async {
    await _runTask('Refreshing offline transaction readiness...', () async {
      if (_offlineWallet == null) {
        throw const FormatException('Create or restore a wallet first.');
      }
      await requestLocalPermissions();
      await _refreshConnectivityState();
      if (!_hasInternet) {
        throw const SocketException(
          'Internet is required to fetch a fresh blockhash.',
        );
      }
      await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
      await refreshWalletData();
    });
  }

  Future<void> topUpOfflineWallet(double amountSol) async {
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

      final int lamports = (amountSol * lamportsPerSol).round();
      if (lamports <= 0) {
        throw const FormatException('Enter an amount greater than zero.');
      }
      if (lamports + solFeeHeadroomLamports > _mainBalanceLamports) {
        throw const FormatException(
          'Main wallet balance is too low for that top up amount plus network fees.',
        );
      }

      final Ed25519HDKeyPair sender = await _walletService.loadSigningKeyPair();
      final String signature = await _solanaService.sendTransferNow(
        sender: sender,
        receiverAddress: _offlineWallet!.address,
        lamports: lamports,
      );
      await _solanaService.waitForConfirmation(signature);
      await _updateCachedBlockhash(await _solanaService.getFreshBlockhash());
      await refreshWalletData();
    });
  }

  Future<void> requestLocalPermissions() async {
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

  Future<void> setRpcEndpoint(String value) async {
    final String endpoint = value.trim();
    if (endpoint.isEmpty) {
      return;
    }

    _rpcEndpoint = endpoint;
    _solanaService.rpcEndpoint = endpoint;
    await _walletService.saveRpcEndpoint(endpoint);
    await refreshWalletData();
    notifyListeners();
  }

  void updateReceiver({
    required String receiverAddress,
    String receiverEndpoint = '',
    String receiverPeripheralId = '',
    String receiverPeripheralName = '',
  }) {
    _sendDraft = _sendDraft.copyWith(
      receiverAddress: receiverAddress.trim(),
      receiverEndpoint: _normalizeEndpoint(receiverEndpoint),
      receiverPeripheralId: receiverPeripheralId.trim(),
      receiverPeripheralName: receiverPeripheralName.trim(),
    );
    notifyListeners();
  }

  void setSendTransport(TransportKind kind) {
    _sendDraft = _sendDraft.copyWith(transport: kind, clearReceiver: true);
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
    _sendDraft = const SendDraft();
    notifyListeners();
  }

  void clearAnnouncement() {
    _announcementMessage = null;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    await _refreshConnectivityState();
    if (_wallet != null && _hasInternet) {
      await refreshWalletData();
      await broadcastPendingInboundTransfers();
      await refreshSubmittedTransfers();
    } else if (_wallet != null) {
      notifyListeners();
    }
  }

  Future<void> scanBleReceivers() async {
    await requestLocalPermissions();
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
    if (_wallet == null || _offlineWallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    if (_sendDraft.receiverAddress.isEmpty) {
      throw const FormatException('Receiver address is required.');
    }
    if (_sendDraft.transport == TransportKind.hotspot &&
        _sendDraft.receiverEndpoint.isEmpty) {
      throw const FormatException(
        'Receiver endpoint is required for hotspot transfer.',
      );
    }
    if (_sendDraft.transport == TransportKind.ble &&
        _sendDraft.receiverPeripheralId.isEmpty) {
      throw const FormatException('Select a BLE receiver before sending.');
    }
    if (!isValidAddress(_sendDraft.receiverAddress)) {
      throw const FormatException(
        'Receiver address is not a valid Solana address.',
      );
    }
    final int lamports = (_sendDraft.amountSol * 1000000000).round();
    if (lamports <= 0) {
      throw const FormatException('Enter an amount greater than zero.');
    }
    if (lamports > offlineSpendableLamports) {
      throw const FormatException(
        'Amount exceeds the available offline wallet balance.',
      );
    }

    final Ed25519HDKeyPair sender = await _walletService
        .loadOfflineSigningKeyPair();
    await _ensureFreshCachedBlockhash();

    final String transferId = _uuid.v4();
    final DateTime createdAt = _clock();
    final OfflineEnvelope envelope = await _solanaService.createSignedEnvelope(
      sender: sender,
      receiverAddress: _sendDraft.receiverAddress,
      lamports: lamports,
      cachedBlockhash: _cachedBlockhash!,
      transferId: transferId,
      createdAt: createdAt,
      transportKind: _sendDraft.transport,
    );
    final ValidatedTransactionDetails details = _solanaService.validateEnvelope(
      envelope,
    );

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
    clearDraft();
    return transfer;
  }

  Future<void> startReceiver() async {
    if (_wallet == null) {
      throw const FormatException('Create or restore a wallet first.');
    }
    await requestLocalPermissions();
    await _refreshConnectivityState();
    if (_receiveTransport == TransportKind.hotspot) {
      await _bleTransportService.stop();
      await _hotspotTransportService.start(onEnvelope: _handleIncomingEnvelope);
    } else {
      await _hotspotTransportService.stop();
      await _bleTransportService.start(
        onEnvelope: _handleIncomingEnvelope,
        receiverDisplayAddress: _wallet!.displayAddress,
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
    if (transfer == null) {
      return;
    }
    await _broadcastTransfer(transfer);
  }

  Future<void> broadcastPendingInboundTransfers() async {
    final List<PendingTransfer> pending = _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.direction == TransferDirection.inbound &&
              (transfer.status == TransferStatus.receivedPendingBroadcast ||
                  transfer.status == TransferStatus.broadcastFailed);
        })
        .toList(growable: false);

    for (final PendingTransfer transfer in pending) {
      await _broadcastTransfer(transfer);
    }
  }

  Future<void> refreshSubmittedTransfers() async {
    final List<PendingTransfer> submitted = _pendingTransfers
        .where((PendingTransfer transfer) {
          return transfer.transactionSignature != null &&
              (transfer.status == TransferStatus.sentOffline ||
                  transfer.status == TransferStatus.broadcastSubmitted ||
                  transfer.status == TransferStatus.broadcasting);
        })
        .toList(growable: false);

    for (final PendingTransfer transfer in submitted) {
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
    }
  }

  List<PendingTransfer> transfersFor(TransferDirection direction) {
    return pendingTransfers
        .where((PendingTransfer transfer) => transfer.direction == direction)
        .toList(growable: false);
  }

  List<PendingTransferListItem> listItemsFor(TransferDirection direction) {
    final DateTime now = _clock();
    return transfersFor(direction)
        .map(
          (PendingTransfer transfer) => PendingTransferListItem(
            transferId: transfer.transferId,
            amountLabel: Formatters.sol(transfer.amountSol),
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

  List<PendingTransfer> recentActivity() =>
      pendingTransfers.take(3).toList(growable: false);

  PendingTransfer? transferById(String transferId) {
    for (final PendingTransfer transfer in _pendingTransfers) {
      if (transfer.transferId == transferId) {
        return transfer;
      }
    }
    return null;
  }

  List<TransferTimelineState> timelineFor(PendingTransfer transfer) {
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
            'An online device is submitting the signed transaction to Solana devnet.',
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
    _rpcEndpoint = defaultRpcEndpoint;
    _solanaService.rpcEndpoint = defaultRpcEndpoint;
    _wallet = null;
    _offlineWallet = null;
    _cachedBlockhash = null;
    _mainBalanceLamports = 0;
    _offlineBalanceLamports = 0;
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
    final ValidatedTransactionDetails details = _solanaService.validateEnvelope(
      envelope,
    );

    if (_wallet == null) {
      return const TransportReceiveResult(
        accepted: false,
        message: 'Receiver wallet is not initialized.',
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
      await _broadcastTransfer(transfer);
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
      final String signature = await _solanaService.broadcastSignedTransaction(
        transfer.envelope.signedTransactionBase64,
      );
      await _persistTransfer(
        transfer.copyWith(
          status: TransferStatus.broadcastSubmitted,
          updatedAt: _clock(),
          transactionSignature: signature,
          explorerUrl: _solanaService.explorerUrlFor(signature).toString(),
        ),
      );
      await refreshSubmittedTransfers();
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
      final String message = error.toString();
      final TransferStatus status = message.toLowerCase().contains('blockhash')
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
        _hasDevnet = await _solanaService.isDevnetReachable();
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

  Future<void> _ensureFreshCachedBlockhash() async {
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

  Future<void> _updateCachedBlockhash(CachedBlockhash blockhash) async {
    _cachedBlockhash = blockhash;
    await _store.saveSetting('cached_blockhash', blockhash.toJson());
  }

  Future<void> _clearCachedBlockhash() async {
    _cachedBlockhash = null;
    await _store.saveSetting('cached_blockhash', null);
  }

  TransferStatus? _nextStatusForSignature(SignatureStatus status) {
    return switch (status.confirmationStatus) {
      ConfirmationStatus.processed => TransferStatus.broadcastSubmitted,
      ConfirmationStatus.confirmed || ConfirmationStatus.finalized =>
        TransferStatus.confirmed,
    };
  }

  Future<bool> _reconcileBroadcastAfterError(PendingTransfer transfer) async {
    final String? signature = transfer.transactionSignature;
    if (signature == null) {
      return false;
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
        confirmedAt:
            nextStatus == TransferStatus.confirmed ? _clock() : null,
        clearLastError: true,
      ),
    );
    return true;
  }

  Future<void> _runTask(
    String status,
    Future<void> Function() operation,
  ) async {
    _working = true;
    _statusMessage = status;
    notifyListeners();
    try {
      await operation();
      _statusMessage = null;
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
