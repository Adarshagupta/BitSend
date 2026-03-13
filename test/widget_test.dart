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
    expect(find.text('Operational constraints'), findsOneWidget);
  });

  testWidgets('home shows send locked banner when not prepared', (WidgetTester tester) async {
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

    expect(find.text('Send is locked'), findsOneWidget);
    expect(find.text('Offline Wallet'), findsAtLeastNWidgets(1));
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
}

const WalletProfile _wallet = WalletProfile(
  address: '6g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1R',
  displayAddress: '6g7h...Qk1R',
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
  }) : super(clock: () => DateTime(2026, 3, 13, 12));

  final String bootRouteValue;
  final WalletProfile? walletValue;
  final bool hasEnoughFundingValue;
  final bool hasOfflineFundsValue;
  final bool hasOfflineReadyBlockhashValue;
  final WalletSummary walletSummaryValue;
  final List<PendingTransfer> inboundTransfers;
  final List<PendingTransfer> outboundTransfers;
  final Map<String, PendingTransfer> transferMap;
  final List<TransferTimelineState> timelineValue;

  @override
  Future<void> initialize() async {}

  @override
  String get bootRoute => bootRouteValue;

  @override
  WalletProfile? get wallet => walletValue;

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
