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
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('boot routes a new user into onboarding', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      bootRouteValue: AppRoutes.onboardingWelcome,
    );

    await tester.pumpWidget(BitsendApp(appState: state));
    await tester.pumpAndSettle();

    expect(find.text('Set up wallet'), findsOneWidget);
    expect(find.text('Send now. Settle later.'), findsOneWidget);
  });

  testWidgets('boot routes an existing wallet into unlock when device auth is required', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      bootRouteValue: AppRoutes.unlock,
      walletValue: _wallet,
      deviceAuthAvailableValue: true,
      deviceAuthHasBiometricOptionValue: true,
      requiresDeviceUnlockValue: true,
      authenticateDeviceResultValue: false,
    );

    await tester.pumpWidget(BitsendApp(appState: state));
    await tester.pumpAndSettle();

    expect(find.text('Unlock wallet'), findsOneWidget);
    expect(find.text('Unlock now'), findsOneWidget);
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
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
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
    expect(find.text('Refresh'), findsAtLeastNWidgets(1));
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Offline Wallet'), findsAtLeastNWidgets(1));
    expect(
      find.textContaining('Move funds to the offline wallet'),
      findsOneWidget,
    );
    expect(find.byTooltip('Scan receiver QR and send'), findsOneWidget);
  });

  testWidgets('home explains offline balance is reserved instead of asking for top up', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: false,
      hasOfflineFundsValue: false,
      hasOfflineReadyBlockhashValue: false,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        balanceSol: 0.2,
        offlineBalanceSol: 0.8,
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

    expect(find.text('Funds reserved'), findsOneWidget);
    expect(
      find.textContaining('fully reserved by pending transfers'),
      findsOneWidget,
    );
  });

  testWidgets('wallet setup shows backup actions after a wallet exists', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
    );

    await pumpWithState(tester, state: state, child: const WalletSetupScreen());

    expect(find.text('Secure your wallet'), findsOneWidget);
    expect(find.text('Download backup'), findsOneWidget);
    expect(find.text('Continue to funding'), findsOneWidget);
  });

  testWidgets('settings screen shows ENS payment preference controls', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
    );

    await pumpWithState(tester, state: state, child: const SettingsScreen());

    expect(find.text('ENS payment preference'), findsOneWidget);
    expect(find.text('Read ENS'), findsOneWidget);
    expect(find.text('Save to ENS'), findsOneWidget);
  });

  testWidgets('settings hides recovery phrase until reveal is requested', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      deviceAuthAvailableValue: true,
      deviceAuthHasBiometricOptionValue: true,
    );

    await pumpWithState(tester, state: state, child: const SettingsScreen());

    expect(find.text(_wallet.seedPhrase), findsNothing);
    expect(find.text('Reveal phrase'), findsOneWidget);
    expect(
      find.textContaining('fingerprint or phone passcode'),
      findsOneWidget,
    );
  });

  testWidgets('fund screen allows skipping when wallet is not funded', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: false,
    );

    await pumpWithState(tester, state: state, child: const FundWalletScreen());

    expect(find.text('Airdrop 1 SOL'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('offline wallet screen shows loader while top up is running', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      hasEnoughFundingValue: true,
      hasOfflineFundsValue: true,
      hasOfflineReadyBlockhashValue: true,
      workingValue: true,
      statusMessageValue: 'Moving funds into the offline wallet...',
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        balanceSol: 1.2,
        offlineBalanceSol: 0.5,
        offlineAvailableSol: 0.5,
        offlineWalletAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
      ),
    );

    await tester.pumpWidget(
      BitsendStateScope(
        notifier: state,
        child: const MaterialApp(home: PrepareOfflineScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Moving funds into the offline wallet...'),
      findsOneWidget,
    );
    expect(find.text('Moving funds...'), findsOneWidget);
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

  testWidgets('receive screen shows ultrasonic relay details when supported', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      receiveTransportValue: TransportKind.ultrasonic,
      ultrasonicSupportedValue: true,
      ultrasonicListenerRunningValue: true,
      activeUltrasonicSessionValue: const PendingRelaySession(
        relayId: 'relay-session-1',
        sessionToken: '00112233445566778899aabbccddeeff',
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        receiverAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        createdAt: DateTime(2026, 3, 14, 12),
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const ReceiveListenScreen(),
    );

    expect(find.text('Ultrasonic'), findsAtLeastNWidgets(1));
    expect(find.text('Relay ID:'), findsOneWidget);
    expect(find.text('relay-session-1'), findsOneWidget);
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
    expect(find.text('Save receipt online'), findsOneWidget);
    expect(find.text(inbound.transferId), findsOneWidget);
  });

  testWidgets('send success screen shows Fileverse receipt action', (
    WidgetTester tester,
  ) async {
    final PendingTransfer outbound = _transfer(
      transferId: 'outgoing-live',
      direction: TransferDirection.outbound,
      status: TransferStatus.sentOffline,
      senderAddress: _wallet.address,
      receiverAddress: 'Receiver11111111111111111111111111111111',
      amountLamports: 500000000,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      lastSentTransferValue: outbound,
    );

    await pumpWithState(tester, state: state, child: const SendSuccessScreen());

    expect(find.text('Save image'), findsOneWidget);
    expect(find.text('Save receipt online'), findsOneWidget);
    expect(find.text('Open pending'), findsOneWidget);
  });

  testWidgets('transfer detail shows Fileverse link when present', (
    WidgetTester tester,
  ) async {
    final PendingTransfer inbound =
        _transfer(
          transferId: 'with-fileverse',
          direction: TransferDirection.inbound,
          status: TransferStatus.broadcastSubmitted,
          senderAddress: 'Sender1111111111111111111111111111111111',
          receiverAddress: _wallet.address,
          amountLamports: 250000000,
        ).copyWith(
          fileverseReceiptId: 'fv-123',
          fileverseReceiptUrl: 'https://fileverse.example/receipt/123',
          fileverseSavedAt: DateTime(2026, 3, 14, 13, 0),
          fileverseStorageMode: 'fileverse',
          fileverseMessage: 'Receipt details were saved to Fileverse.',
        );
    final _TestBitsendAppState state = _TestBitsendAppState(
      transferMap: <String, PendingTransfer>{inbound.transferId: inbound},
    );

    await pumpWithState(
      tester,
      state: state,
      child: TransferDetailScreen(transferId: inbound.transferId),
    );

    expect(find.text('Saved in Fileverse'), findsOneWidget);
    expect(find.text('Fileverse ID'), findsOneWidget);
    expect(find.text('Fileverse link'), findsOneWidget);
    expect(find.text('Copy Fileverse link'), findsOneWidget);
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

    expect(
      find.text('Start hotspot receive to show the live QR.'),
      findsOneWidget,
    );
    expect(find.text('Copy QR'), findsNothing);
  });

  testWidgets(
    'pending screen switches between inbound and outbound transfers',
    (WidgetTester tester) async {
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

      await pumpWithState(tester, state: state, child: const PendingScreen());

      expect(find.text('Inbound transfer'), findsOneWidget);
      expect(find.text('Outbound transfer'), findsNothing);

      await tester.tap(find.text('Outbound'));
      await tester.pumpAndSettle();

      expect(find.text('Outbound transfer'), findsOneWidget);
    },
  );

  testWidgets('transfer detail renders timeline and status', (
    WidgetTester tester,
  ) async {
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
      bleDiscoveringValue: false,
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

  testWidgets('BitGo send mode skips hotspot endpoint entry', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeWalletEngineValue: WalletEngine.bitgo,
      hasInternetValue: true,
      bitgoWalletValue: const BitGoWalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        walletId: 'demo-sol',
        address: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        displayLabel: 'Demo SOL',
        balanceBaseUnits: 1500000000,
        connectivityStatus: 'connected',
      ),
      bitgoEndpointValue: 'http://192.168.82.10:8788',
      bitgoBackendModeValue: BitGoBackendMode.mock,
      sendDraftValue: const SendDraft(
        walletEngine: WalletEngine.bitgo,
        transport: TransportKind.hotspot,
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const SendTransportScreen(),
    );

    expect(find.text('Endpoint not needed'), findsOneWidget);
    expect(find.text('Receiver endpoint'), findsNothing);
    expect(
      find.textContaining('Send will switch to Local mode automatically'),
      findsOneWidget,
    );
  });

  testWidgets('send transport shows full scanned address instead of short label', (
    WidgetTester tester,
  ) async {
    const String receiverAddress =
        '0x38Ff8bE6A9C12D0f5D3f90E9cD7bE1A24546aBcd';
    final _TestBitsendAppState state = _TestBitsendAppState(
      sendDraftValue: const SendDraft(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        receiverAddress: receiverAddress,
        receiverLabel: '0x38...aBcd',
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const SendTransportScreen(),
    );

    final TextField addressField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(addressField.controller?.text, receiverAddress);
  });

  testWidgets('send amount blocks oversized local transfer before review', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      hasOfflineFundsValue: true,
      hasOfflineReadyBlockhashValue: true,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        balanceSol: 0.2,
        offlineBalanceSol: 9.27,
        offlineAvailableSol: 0.04,
        offlineWalletAddress: '0x1111111111111111111111111111111111111111',
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
      ),
      estimatedSendFeeHeadroomSolValue: 0.001,
      maxSendAmountSolValue: 0.039,
      validateSendAmountHandler: (double amountSol) {
        if (amountSol > 0.039) {
          return 'Amount exceeds the available offline wallet balance after network fees.';
        }
        return null;
      },
    );

    await pumpWithState(
      tester,
      state: state,
      child: const SendAmountScreen(),
    );

    expect(find.text('Spendable now'), findsOneWidget);
    expect(find.text('Reserved by pending'), findsOneWidget);
    expect(find.text('Max send now'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9.23');
    await tester.tap(find.text('Review transfer'));
    await tester.pump();

    expect(
      find.text(
        'Amount exceeds the available offline wallet balance after network fees.',
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('send review disables signing when amount exceeds spendable balance', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      hasOfflineFundsValue: true,
      hasOfflineReadyBlockhashValue: true,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        balanceSol: 0.2,
        offlineBalanceSol: 9.27,
        offlineAvailableSol: 0.04,
        offlineWalletAddress: '0x1111111111111111111111111111111111111111',
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
      ),
      sendDraftValue: const SendDraft(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        transport: TransportKind.hotspot,
        receiverAddress: '0x2222222222222222222222222222222222222222',
        amountSol: 9.23,
      ),
      validateSendAmountHandler: (double amountSol) {
        if (amountSol > 0.039) {
          return 'Amount exceeds the available offline wallet balance after network fees.';
        }
        return null;
      },
    );

    await pumpWithState(
      tester,
      state: state,
      child: const SendReviewScreen(),
    );

    expect(find.text('Amount too high'), findsOneWidget);
    expect(
      find.text(
        'Amount exceeds the available offline wallet balance after network fees.',
      ),
      findsOneWidget,
    );

    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sign and send'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('home explains non-live BitGo backend falls back to Local send', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeWalletEngineValue: WalletEngine.bitgo,
      hasInternetValue: true,
      bitgoBackendModeValue: BitGoBackendMode.mock,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        balanceSol: 1.2,
        offlineBalanceSol: 0,
        offlineAvailableSol: 0,
        offlineWalletAddress: null,
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const HomeDashboardScreen(),
    );

    expect(find.text('Auto-fallback'), findsOneWidget);
    expect(
      find.text(
        'BitGo backend is not live. Send will fall back to Local mode.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('receive screen explains BitGo mode is local-only', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeWalletEngineValue: WalletEngine.bitgo,
      bleListenerRunningValue: false,
    );

    await pumpWithState(
      tester,
      state: state,
      child: const ReceiveListenScreen(),
    );

    expect(
      find.textContaining('BitGo mode does not listen offline'),
      findsOneWidget,
    );
  });
}

const WalletProfile _wallet = WalletProfile(
  chain: ChainKind.solana,
  address: '6g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1R',
  displayAddress: '6g7h...Qk1R',
  seedPhrase:
      'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
  mode: WalletSetupMode.created,
);

const WalletProfile _offlineWallet = WalletProfile(
  chain: ChainKind.solana,
  address: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
  displayAddress: '5g7h...Qk1Z',
  seedPhrase:
      'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
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
    chain: ChainKind.solana,
    network: ChainNetwork.testnet,
    senderAddress: senderAddress,
    receiverAddress: receiverAddress,
    amountLamports: amountLamports,
    signedTransactionBase64: 'ZW5jb2RlZA==',
    transportKind: TransportKind.hotspot,
  );
  return PendingTransfer(
    transferId: transferId,
    chain: ChainKind.solana,
    network: ChainNetwork.testnet,
    walletEngine: WalletEngine.local,
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
    this.activeWalletEngineValue = WalletEngine.local,
    this.hasEnoughFundingValue = false,
    this.hasOfflineFundsValue = false,
    this.hasOfflineReadyBlockhashValue = false,
    this.hasInternetValue = false,
    this.workingValue = false,
    this.statusMessageValue,
    this.walletSummaryValue = const WalletSummary(
      chain: ChainKind.solana,
      network: ChainNetwork.testnet,
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
    this.bitgoWalletValue,
    this.bitgoEndpointValue = defaultBitGoBackendEndpoint,
    this.bitgoBackendModeValue = BitGoBackendMode.live,
    this.hotspotListenerRunningValue = false,
    this.bleListenerRunningValue = false,
    this.ultrasonicSupportedValue = false,
    this.ultrasonicListenerRunningValue = false,
    this.activeUltrasonicSessionValue,
    this.lastSentTransferValue,
    this.lastReceivedTransferIdValue,
    this.announcementMessageValue,
    this.announcementSerialValue = 0,
    this.estimatedSendFeeHeadroomSolValue = 0,
    this.maxSendAmountSolValue = 0,
    this.validateSendAmountHandler,
    this.deviceAuthAvailableValue = false,
    this.deviceAuthHasBiometricOptionValue = false,
    this.requiresDeviceUnlockValue = false,
    this.authenticateDeviceResultValue = true,
  }) : super(clock: () => DateTime(2026, 3, 13, 12));

  final String bootRouteValue;
  final WalletProfile? walletValue;
  final WalletProfile? offlineWalletValue;
  final WalletEngine activeWalletEngineValue;
  final bool hasEnoughFundingValue;
  final bool hasOfflineFundsValue;
  final bool hasOfflineReadyBlockhashValue;
  final bool hasInternetValue;
  final bool workingValue;
  final String? statusMessageValue;
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
  final BitGoWalletSummary? bitgoWalletValue;
  final String bitgoEndpointValue;
  final BitGoBackendMode bitgoBackendModeValue;
  final bool hotspotListenerRunningValue;
  final bool bleListenerRunningValue;
  final bool ultrasonicSupportedValue;
  final bool ultrasonicListenerRunningValue;
  final PendingRelaySession? activeUltrasonicSessionValue;
  final PendingTransfer? lastSentTransferValue;
  final String? lastReceivedTransferIdValue;
  final String? announcementMessageValue;
  final int announcementSerialValue;
  final double estimatedSendFeeHeadroomSolValue;
  final double maxSendAmountSolValue;
  final String? Function(double amountSol)? validateSendAmountHandler;
  final bool deviceAuthAvailableValue;
  final bool deviceAuthHasBiometricOptionValue;
  final bool requiresDeviceUnlockValue;
  final bool authenticateDeviceResultValue;

  @override
  Future<void> initialize() async {}

  @override
  String get bootRoute => bootRouteValue;

  @override
  WalletProfile? get wallet => walletValue;

  @override
  WalletProfile? get offlineWallet => offlineWalletValue;

  @override
  WalletEngine get activeWalletEngine => activeWalletEngineValue;

  @override
  bool get hasWallet => walletValue != null;

  @override
  bool get hasOfflineWallet => offlineWalletValue != null;

  @override
  bool get hasInternet => hasInternetValue;

  @override
  bool get working => workingValue;

  @override
  String? get statusMessage => statusMessageValue;

  @override
  bool get deviceAuthAvailable => deviceAuthAvailableValue;

  @override
  bool get deviceAuthHasBiometricOption =>
      deviceAuthHasBiometricOptionValue;

  @override
  bool get requiresDeviceUnlock => requiresDeviceUnlockValue;

  @override
  String get deviceUnlockMethodLabel => deviceAuthHasBiometricOptionValue
      ? 'fingerprint or phone passcode'
      : 'phone passcode';

  @override
  Future<bool> authenticateDevice({
    String? reason,
    bool forcePrompt = false,
  }) async => authenticateDeviceResultValue;

  @override
  bool get hasEnoughFunding => hasEnoughFundingValue;

  @override
  bool get hasOfflineFunds => hasOfflineFundsValue;

  @override
  bool get hasOfflineReadyBlockhash => hasOfflineReadyBlockhashValue;

  @override
  double get mainBalanceSol => walletSummaryValue.balanceSol;

  @override
  double get offlineBalanceSol => walletSummaryValue.offlineBalanceSol;

  @override
  double get offlineSpendableBalanceSol => walletSummaryValue.offlineAvailableSol;

  @override
  WalletSummary get walletSummary => walletSummaryValue;

  @override
  double get estimatedSendFeeHeadroomSol => estimatedSendFeeHeadroomSolValue;

  @override
  double get maxSendAmountSol => maxSendAmountSolValue;

  @override
  HomeStatus get homeStatus => HomeStatus(
    hasInternet: hasInternetValue,
    hasLocalLink: false,
    hasDevnet: false,
    walletEngine: activeWalletEngineValue,
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
  BitGoWalletSummary? get bitgoWallet => bitgoWalletValue;

  @override
  BitGoBackendMode get bitgoBackendMode => bitgoBackendModeValue;

  @override
  bool get bitgoBackendIsLive => bitgoBackendModeValue.isLive;

  @override
  String get bitgoEndpoint => bitgoEndpointValue;

  @override
  bool get listenerRunning =>
      hotspotListenerRunningValue ||
      bleListenerRunningValue ||
      ultrasonicListenerRunningValue;

  @override
  bool get hotspotListenerRunning => hotspotListenerRunningValue;

  @override
  bool get bleListenerRunning => bleListenerRunningValue;

  @override
  bool get ultrasonicSupported => ultrasonicSupportedValue;

  @override
  bool get ultrasonicListenerRunning => ultrasonicListenerRunningValue;

  @override
  PendingRelaySession? get activeUltrasonicSession =>
      activeUltrasonicSessionValue;

  @override
  String? get lastReceivedTransferId => lastReceivedTransferIdValue;

  @override
  PendingTransfer? get lastSentTransfer => lastSentTransferValue;

  @override
  String? get announcementMessage => announcementMessageValue;

  @override
  int get announcementSerial => announcementSerialValue;

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
    return direction == TransferDirection.inbound
        ? inboundTransfers
        : outboundTransfers;
  }

  @override
  PendingTransfer? transferById(String transferId) => transferMap[transferId];

  @override
  List<TransferTimelineState> timelineFor(PendingTransfer transfer) =>
      timelineValue;

  @override
  String? validateSendAmount(double amountSol) =>
      validateSendAmountHandler?.call(amountSol);
}
