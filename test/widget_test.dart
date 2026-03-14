import 'package:bitsend/src/app/app.dart';
import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/screens/screens.dart';
import 'package:bitsend/src/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWithState(
    WidgetTester tester, {
    required BitsendAppState state,
    required Widget child,
  }) async {
    await tester.pumpWidget(
      BitsendStateScope(
        notifier: state,
        child: MaterialApp(
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('boot routes a new user into onboarding', (WidgetTester tester) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      bootRouteValue: AppRoutes.onboardingWelcome,
    );

    await tester.pumpWidget(BitsendApp(appState: state));
    await tester.pumpAndSettle();

    expect(find.text('Set up wallet'), findsOneWidget);
    expect(find.text('Send now. Settle later.'), findsOneWidget);
  });

  testWidgets('home shows send prep card when not prepared', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: true,
      hasOfflineFundsValue: false,
      hasOfflineReadyBlockhashValue: false,
      walletSummaryValue: const WalletSummary(
        balanceSol: 1.2,
        offlineBalanceSol: 0,
        offlineAvailableSol: 0,
        offlineWalletAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        readyForOffline: false,
        blockhashAge: null,
        localEndpoint: null,
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const HomeDashboardScreen(),
    );

    expect(find.text('Fund'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Offline Wallet'), findsAtLeastNWidgets(1));
  });

  testWidgets('wallet setup shows backup actions after a wallet exists', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
    );

    await pumpWithState(
      tester,
      state: state,
      child: const WalletSetupScreen(),
    );

    expect(find.text('Secure your wallet'), findsOneWidget);
    expect(find.text('Download backup'), findsOneWidget);
    expect(find.text('Continue to funding'), findsOneWidget);
  });

  testWidgets('fund screen allows skipping when wallet is not funded', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: false,
    );

    await pumpWithState(
      tester,
      state: state,
      child: const FundWalletScreen(),
    );

    expect(find.text('Airdrop 1 SOL'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('receive screen shows the integrated receive panel', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      receiveTransportValue: TransportKind.hotspot,
      localEndpointValue: 'http://192.168.82.8:8787',
      hotspotListenerRunningValue: true,
    );

    await pumpWithState(
      tester,
      state: state,
      child: const ReceiveListenScreen(),
    );

    expect(find.text('Ready to catch a handoff'), findsOneWidget);
    expect(find.text('Share QR'), findsOneWidget);
    expect(find.text('Stop listener'), findsOneWidget);
  });

  testWidgets('receive result screen shows the stored transfer details', (
    WidgetTester tester,
  ) async {
    final PendingTransfer inbound = _transfer(
      transferId: 'incoming-live',
      direction: TransferDirection.inbound,
      status: TransferStatus.receivedPendingBroadcast,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: _wallet.address,
      amountLamports: 250000000,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      transferMap: <String, PendingTransfer>{inbound.transferId: inbound},
      lastReceivedTransferIdValue: inbound.transferId,
    );

    await pumpWithState(
      tester,
      state: state,
      child: ReceiveResultScreen(transferId: inbound.transferId),
    );

    expect(find.text('Signed handoff stored'), findsOneWidget);
    expect(find.text('Open timeline'), findsOneWidget);
    expect(find.text(inbound.transferId), findsOneWidget);
  });

  testWidgets('receive screen hides hotspot QR until listener is live', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      receiveTransportValue: TransportKind.hotspot,
      localEndpointValue: 'http://192.168.82.8:8787',
      hotspotListenerRunningValue: false,
    );

    await pumpWithState(
      tester,
      state: state,
      child: const ReceiveListenScreen(),
    );

    expect(find.text('Start hotspot receive to show the live QR.'), findsOneWidget);
    expect(find.text('Copy QR'), findsNothing);
  });

  testWidgets('pending screen switches between inbound and outbound transfers', (
    WidgetTester tester,
  ) async {
    final PendingTransfer inbound = _transfer(
      transferId: 'inbound-1',
      direction: TransferDirection.inbound,
      status: TransferStatus.receivedPendingBroadcast,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: 'Receiver11111111111111111111111111111111',
      amountLamports: 250000000,
    );
    final PendingTransfer outbound = _transfer(
      transferId: 'outbound-1',
      direction: TransferDirection.outbound,
      status: TransferStatus.sentOffline,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: 'Receiver22222222222222222222222222222222',
      amountLamports: 500000000,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      inboundTransfers: <PendingTransfer>[inbound],
      outboundTransfers: <PendingTransfer>[outbound],
    );

    await pumpWithState(
      tester,
      state: state,
      child: const PendingScreen(),
    );

    expect(find.text('Inbound transfer'), findsOneWidget);
    expect(find.text('Outbound transfer'), findsNothing);

    await tester.tap(find.text('Outbound'));
    await tester.pumpAndSettle();

    expect(find.text('Outbound transfer'), findsOneWidget);
  });

  testWidgets('transfer detail renders timeline and status', (WidgetTester tester) async {
    final PendingTransfer transfer = _transfer(
      transferId: 'tx-1',
      direction: TransferDirection.inbound,
      status: TransferStatus.broadcastSubmitted,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: 'Receiver11111111111111111111111111111111',
      amountLamports: 750000000,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      transferMap: <String, PendingTransfer>{transfer.transferId: transfer},
      timelineValue: <TransferTimelineState>[
        const TransferTimelineState(
          title: 'Signed',
          caption: 'Transaction was signed locally.',
          isComplete: true,
          isCurrent: false,
        ),
        const TransferTimelineState(
          title: 'Received offline',
          caption: 'Receiver stored the signed transfer.',
          isComplete: true,
          isCurrent: false,
        ),
        const TransferTimelineState(
          title: 'Broadcasting',
          caption: 'RPC submission is in flight.',
          isComplete: true,
          isCurrent: false,
        ),
        const TransferTimelineState(
          title: 'Submitted',
          caption: 'RPC accepted the signature.',
          isComplete: false,
          isCurrent: true,
        ),
      ],
    );

    await pumpWithState(
      tester,
      state: state,
      child: const TransferDetailScreen(transferId: 'tx-1'),
    );

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('RPC accepted the signature.'), findsOneWidget);
    expect(find.text('Inbound transfer'), findsOneWidget);
  });

  testWidgets('outbound transfer detail offers broadcast fallback', (
    WidgetTester tester,
  ) async {
    final PendingTransfer transfer = _transfer(
      transferId: 'tx-outbound',
      direction: TransferDirection.outbound,
      status: TransferStatus.sentOffline,
      senderAddress: _offlineWallet.address,
      receiverAddress: _wallet.address,
      amountLamports: 300000000,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      transferMap: <String, PendingTransfer>{transfer.transferId: transfer},
    );

    await pumpWithState(
      tester,
      state: state,
      child: const TransferDetailScreen(transferId: 'tx-outbound'),
    );

    expect(find.text('Broadcast now'), findsOneWidget);
  });

  testWidgets('BLE receiver selection fills the receiver address', (
    WidgetTester tester,
  ) async {
    const String receiverAddress =
        '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z';
    final _TestBitsendAppState state = _TestBitsendAppState(
      sendDraftValue: const SendDraft(transport: TransportKind.ble),
      bleReceiversValue: const <ReceiverDiscoveryItem>[
        ReceiverDiscoveryItem(
          id: 'ble-1',
          label: '5g7h...Qk1Z',
          subtitle: '5g7h...Qk1Z',
          transport: TransportKind.ble,
          address: receiverAddress,
          metadataVerified: true,
          rssi: -52,
        ),
      ],
    );

    await pumpWithState(
      tester,
      state: state,
      child: const SendTransportScreen(),
    );

    await tester.tap(find.text('5g7h...Qk1Z'));
    await tester.pumpAndSettle();

    final TextField addressField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(addressField.controller?.text, receiverAddress);
  });
}

const WalletProfile _wallet = WalletProfile(
  address: '6g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1R',
  displayAddress: '6g7h...Qk1R',
  seedPhrase: 'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
  mode: WalletSetupMode.created,
);

const WalletProfile _offlineWallet = WalletProfile(
  address: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
  displayAddress: '5g7h...Qk1Z',
  seedPhrase: 'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
  mode: WalletSetupMode.created,
);

PendingTransfer _transfer({
  required String transferId,
  required TransferDirection direction,
  required TransferStatus status,
  required String senderAddress,
  required String receiverAddress,
  required int amountLamports,
}) {
  final DateTime now = DateTime(2026, 3, 13, 12);
  final OfflineEnvelope envelope = OfflineEnvelope.create(
    transferId: transferId,
    createdAt: now,
    senderAddress: senderAddress,
    receiverAddress: receiverAddress,
    amountLamports: amountLamports,
    signedTransactionBase64: 'ZW5jb2RlZA==',
    transportKind: TransportKind.hotspot,
  );
  return PendingTransfer(
    transferId: transferId,
    direction: direction,
    status: status,
    amountLamports: amountLamports,
    senderAddress: senderAddress,
    receiverAddress: receiverAddress,
    transport: TransportKind.hotspot,
    createdAt: now,
    updatedAt: now,
    envelope: envelope,
    transactionSignature: '5vzWQyrGExdHJ9pQxV7j1U8QGSoK8Vw1w2h4bB2ZvFQq1n3R9Y7',
  );
}

class _TestBitsendAppState extends BitsendAppState {
  _TestBitsendAppState({
    this.bootRouteValue = AppRoutes.home,
    this.walletValue,
    this.offlineWalletValue,
    this.hasEnoughFundingValue = false,
    this.hasOfflineFundsValue = false,
    this.hasOfflineReadyBlockhashValue = false,
    this.walletSummaryValue = const WalletSummary(
      balanceSol: 0,
      offlineBalanceSol: 0,
      offlineAvailableSol: 0,
      offlineWalletAddress: null,
      readyForOffline: false,
      blockhashAge: null,
      localEndpoint: null,
    ),
    this.inboundTransfers = const <PendingTransfer>[],
    this.outboundTransfers = const <PendingTransfer>[],
    this.transferMap = const <String, PendingTransfer>{},
    this.timelineValue = const <TransferTimelineState>[],
    this.sendDraftValue = const SendDraft(),
    this.bleReceiversValue = const <ReceiverDiscoveryItem>[],
    this.bleDiscoveringValue = false,
    this.receiveTransportValue = TransportKind.hotspot,
    this.localEndpointValue,
    this.hotspotListenerRunningValue = false,
    this.bleListenerRunningValue = false,
    this.lastReceivedTransferIdValue,
  }) : super(clock: () => DateTime(2026, 3, 13, 12));

  final String bootRouteValue;
  final WalletProfile? walletValue;
  final WalletProfile? offlineWalletValue;
  final bool hasEnoughFundingValue;
  final bool hasOfflineFundsValue;
  final bool hasOfflineReadyBlockhashValue;
  final WalletSummary walletSummaryValue;
  final List<PendingTransfer> inboundTransfers;
  final List<PendingTransfer> outboundTransfers;
  final Map<String, PendingTransfer> transferMap;
  final List<TransferTimelineState> timelineValue;
  final SendDraft sendDraftValue;
  final List<ReceiverDiscoveryItem> bleReceiversValue;
  final bool bleDiscoveringValue;
  final TransportKind receiveTransportValue;
  final String? localEndpointValue;
  final bool hotspotListenerRunningValue;
  final bool bleListenerRunningValue;
  final String? lastReceivedTransferIdValue;

  @override
  Future<void> initialize() async {}

  @override
  String get bootRoute => bootRouteValue;

  @override
  WalletProfile? get wallet => walletValue;

  @override
  WalletProfile? get offlineWallet => offlineWalletValue;

  @override
  bool get hasWallet => walletValue != null;

  @override
  bool get hasEnoughFunding => hasEnoughFundingValue;

  @override
  bool get hasOfflineFunds => hasOfflineFundsValue;

  @override
  bool get hasOfflineReadyBlockhash => hasOfflineReadyBlockhashValue;

  @override
  WalletSummary get walletSummary => walletSummaryValue;

  @override
  HomeStatus get homeStatus => const HomeStatus(
        hasInternet: false,
        hasLocalLink: false,
        hasDevnet: false,
      );

  @override
  SendDraft get sendDraft => sendDraftValue;

  @override
  List<ReceiverDiscoveryItem> get bleReceivers => bleReceiversValue;

  @override
  bool get bleDiscovering => bleDiscoveringValue;

  @override
  TransportKind get receiveTransport => receiveTransportValue;

  @override
  String? get localEndpoint => localEndpointValue;

  @override
  bool get listenerRunning =>
      hotspotListenerRunningValue || bleListenerRunningValue;

  @override
  bool get hotspotListenerRunning => hotspotListenerRunningValue;

  @override
  bool get bleListenerRunning => bleListenerRunningValue;

  @override
  String? get lastReceivedTransferId => lastReceivedTransferIdValue;

  @override
  Future<void> startReceiver() async {}

  @override
  Future<void> stopReceiver() async {}

  @override
  List<PendingTransfer> recentActivity() => <PendingTransfer>[
        ...inboundTransfers,
        ...outboundTransfers,
      ];

  @override
  List<PendingTransfer> transfersFor(TransferDirection direction) {
    return direction == TransferDirection.inbound ? inboundTransfers : outboundTransfers;
  }

  @override
  PendingTransfer? transferById(String transferId) => transferMap[transferId];

  @override
  List<TransferTimelineState> timelineFor(PendingTransfer transfer) => timelineValue;
}
