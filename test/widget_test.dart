import 'package:bitsend/src/app/app.dart';
import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/screens/screens.dart';
import 'package:bitsend/src/services/swap_service.dart';
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

  testWidgets(
    'boot routes an existing wallet into unlock when device auth is required',
    (WidgetTester tester) async {
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
    },
  );

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

    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byKey(const Key('primary-nav-scan-button')), findsOneWidget);
    expect(find.text('Queue'), findsNothing);
    expect(find.text('Funds'), findsNothing);
    expect(find.text('Move + sync'), findsNothing);
    expect(find.text('Est. chain value'), findsOneWidget);
  });

  testWidgets('home hero follows the selected chain total', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeChainValue: ChainKind.bnb,
      activeNetworkValue: ChainNetwork.mainnet,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.bnb,
        network: ChainNetwork.mainnet,
        balanceSol: 0.02,
        offlineBalanceSol: 0,
        offlineAvailableSol: 0,
        offlineWalletAddress: '0x1234567890abcdef1234567890abcdef12345678',
        readyForOffline: false,
        blockhashAge: null,
        localEndpoint: null,
      ),
      portfolioUsdTotalValue: 999.99,
      activeScopeUsdTotalValue: 1.17,
    );

    await pumpWithState(
      tester,
      state: state,
      child: const HomeDashboardScreen(),
    );

    expect(find.text('Est. chain value'), findsOneWidget);
    expect(find.text('\$1.17'), findsOneWidget);
    expect(find.text('\$999.99'), findsNothing);
    expect(find.text('BNB'), findsWidgets);
  });

  testWidgets('swap screen asks for a 0x key before enabling swaps', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeChainValue: ChainKind.bnb,
      activeNetworkValue: ChainNetwork.mainnet,
      swapSupportedOnActiveScopeValue: true,
      hasSwapApiKeyValue: false,
      portfolioHoldingsValue: const <AssetPortfolioHolding>[
        AssetPortfolioHolding(
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          totalBalance: 1.0,
          mainBalance: 1.0,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId: 'bnb:mainnet:native',
          symbol: 'BNB',
          displayName: 'BNB Chain',
        ),
      ],
      tokenAssetsValue: const <TrackedAssetDefinition>[
        TrackedAssetDefinition(
          id: 'bnb:mainnet:native',
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          symbol: 'BNB',
          displayName: 'BNB Chain',
          decimals: 18,
        ),
      ],
    );

    await pumpWithState(tester, state: state, child: const SwapScreen());

    expect(find.text('Add your 0x API key'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('swap screen renders a live quote after review', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeChainValue: ChainKind.bnb,
      activeNetworkValue: ChainNetwork.mainnet,
      swapSupportedOnActiveScopeValue: true,
      hasSwapApiKeyValue: true,
      swapApiKeyValue: 'test-key',
      swapSlippageBpsValue: 100,
      portfolioHoldingsValue: const <AssetPortfolioHolding>[
        AssetPortfolioHolding(
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          totalBalance: 2.0,
          mainBalance: 2.0,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId: 'bnb:mainnet:native',
          symbol: 'BNB',
          displayName: 'BNB Chain',
        ),
        AssetPortfolioHolding(
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          totalBalance: 12.5,
          mainBalance: 12.5,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId: 'bnb:mainnet:usdt',
          symbol: 'USDT',
          displayName: 'Tether USD',
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
          isNative: false,
        ),
      ],
      tokenAssetsValue: const <TrackedAssetDefinition>[
        TrackedAssetDefinition(
          id: 'bnb:mainnet:native',
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          symbol: 'BNB',
          displayName: 'BNB Chain',
          decimals: 18,
        ),
        TrackedAssetDefinition(
          id: 'bnb:mainnet:usdt',
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          symbol: 'USDT',
          displayName: 'Tether USD',
          decimals: 18,
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
        ),
      ],
      quoteSwapHandler: ({
        required String sellAssetId,
        required String buyAssetId,
        required double sellAmount,
      }) async {
        expect(sellAssetId, 'bnb:mainnet:native');
        expect(buyAssetId, 'bnb:mainnet:usdt');
        expect(sellAmount, 1.0);
        return const SwapQuote(
          sellTokenAddress: SwapService.nativeTokenAddress,
          buyTokenAddress: '0x55d398326f99059fF775485246999027B3197955',
          sellAmountBaseUnits: 1000000000000000000,
          buyAmountBaseUnits: 610000000000000000000,
          minBuyAmountBaseUnits: 600000000000000000000,
          liquidityAvailable: true,
          routeFills: <SwapRouteFill>[
            SwapRouteFill(
              fromTokenAddress: SwapService.nativeTokenAddress,
              toTokenAddress: '0x55d398326f99059fF775485246999027B3197955',
              source: 'PancakeSwap_V2',
              proportionBps: 10000,
            ),
          ],
          isFirmQuote: false,
          totalNetworkFeeBaseUnits: 1000000000000000,
        );
      },
    );

    await pumpWithState(tester, state: state, child: const SwapScreen());

    await tester.enterText(find.byType(TextField).first, '1');
    await tester.tap(find.text('Review swap'));
    await tester.pumpAndSettle();

    expect(find.text('Live quote'), findsOneWidget);
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('PancakeSwap_V2'), findsOneWidget);
    expect(find.text('Swap now'), findsOneWidget);
  });

  testWidgets('home keeps reserved offline state quiet', (
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

    expect(find.text('Funds reserved'), findsNothing);
    expect(
      find.textContaining('fully reserved by pending transfers'),
      findsNothing,
    );
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Move funds to send'), findsOneWidget);
    expect(find.text('Send balance'), findsOneWidget);
    expect(find.text('Can send now'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('offline wallet card shows info explainer', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: true,
      hasOfflineFundsValue: true,
      hasOfflineReadyBlockhashValue: true,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        balanceSol: 1.2,
        offlineBalanceSol: 0.7,
        offlineAvailableSol: 0.55,
        offlineWalletAddress: '0x1234567890abcdef1234567890abcdef12345678',
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

    expect(find.byKey(const Key('offline-wallet-info-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('offline-wallet-info-button')));
    await tester.pumpAndSettle();

    expect(find.text('How the offline wallet works'), findsOneWidget);
    expect(find.text('Top it up from the main wallet'), findsOneWidget);
    expect(find.text('What the card numbers mean'), findsOneWidget);
    expect(find.text('Can send now'), findsOneWidget);
  });

  testWidgets('offline wallet card shows top up and receive actions', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: true,
      hasOfflineFundsValue: true,
      hasOfflineReadyBlockhashValue: true,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        balanceSol: 1.2,
        offlineBalanceSol: 0.4,
        offlineAvailableSol: 0.4,
        offlineWalletAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
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

    expect(find.text('Top up'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Main'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Can send'), findsOneWidget);
  });

  testWidgets('offline wallet receive action opens local receive screen', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      hasEnoughFundingValue: true,
      hasOfflineFundsValue: true,
      hasOfflineReadyBlockhashValue: true,
      ultrasonicSupportedValue: true,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        balanceSol: 1.2,
        offlineBalanceSol: 0.4,
        offlineAvailableSol: 0.4,
        offlineWalletAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
      ),
    );

    await tester.pumpWidget(
      BitsendStateScope(
        notifier: state,
        child: MaterialApp(
          onGenerateRoute: (RouteSettings settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                if (settings.name == AppRoutes.receiveListen) {
                  return const ReceiveListenScreen();
                }
                return const HomeDashboardScreen();
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    expect(
      find.text('Catch a signed handoff over hotspot, BLE, or ultrasonic.'),
      findsOneWidget,
    );
    expect(find.text('Hotspot'), findsOneWidget);
    expect(find.text('BLE'), findsOneWidget);
    expect(find.text('Ultrasonic'), findsOneWidget);
  });

  testWidgets('deposit screen can open on offline wallet tab', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.solana,
        network: ChainNetwork.testnet,
        balanceSol: 1.25,
        offlineBalanceSol: 0.5,
        offlineAvailableSol: 0.35,
        offlineWalletAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const DepositScreen(initialTarget: DepositWalletTarget.offline),
    );

    expect(find.text('Offline wallet'), findsWidgets);
    expect(
      find.text('5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z'),
      findsOneWidget,
    );
  });

  testWidgets('assets screen shows active chain holdings details', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        balanceSol: 1.25,
        offlineBalanceSol: 0.5,
        offlineAvailableSol: 0.35,
        offlineWalletAddress: '0x1234567890abcdef1234567890abcdef12345678',
        readyForOffline: true,
        blockhashAge: null,
        localEndpoint: null,
        primaryAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      ),
      portfolioHoldingsValue: const <AssetPortfolioHolding>[
        AssetPortfolioHolding(
          chain: ChainKind.ethereum,
          network: ChainNetwork.testnet,
          totalBalance: 1.75,
          mainBalance: 1.25,
          protectedBalance: 0.5,
          spendableBalance: 0.35,
          reservedBalance: 0.15,
          mainAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
          protectedAddress: '0x1234567890abcdef1234567890abcdef12345678',
        ),
        AssetPortfolioHolding(
          chain: ChainKind.ethereum,
          network: ChainNetwork.testnet,
          totalBalance: 48.2,
          mainBalance: 48.2,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId: 'ethereum:testnet:usdc',
          symbol: 'USDC',
          displayName: 'USD Coin',
          assetDecimals: 6,
          contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
          isNative: false,
          mainAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        ),
        AssetPortfolioHolding(
          chain: ChainKind.solana,
          network: ChainNetwork.testnet,
          totalBalance: 3.4,
          mainBalance: 3.4,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          mainAddress: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
        ),
      ],
    );

    await pumpWithState(tester, state: state, child: const AssetsScreen());

    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('ETH'), findsWidgets);
    expect(find.text('USDC'), findsWidgets);
    expect(find.text('All assets'), findsOneWidget);
    expect(find.text('SOL'), findsWidgets);
    expect(find.text('Reserved'), findsWidgets);
    expect(find.text('3 assets'), findsOneWidget);
  });

  testWidgets('accounts screen shows derived wallet accounts', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      accountSummariesValue: const <WalletAccountSummary>[
        WalletAccountSummary(
          chain: ChainKind.ethereum,
          slotIndex: 0,
          mainWallet: WalletProfile(
            chain: ChainKind.ethereum,
            address: '0x1111111111111111111111111111111111111111',
            displayAddress: '0x1111...1111',
            seedPhrase: 'alpha beta gamma',
            mode: WalletSetupMode.created,
          ),
          protectedWallet: WalletProfile(
            chain: ChainKind.ethereum,
            address: '0x2222222222222222222222222222222222222222',
            displayAddress: '0x2222...2222',
            seedPhrase: 'alpha beta gamma',
            mode: WalletSetupMode.created,
          ),
          selected: true,
        ),
      ],
    );

    await pumpWithState(tester, state: state, child: const AccountsScreen());

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets('approvals screen shows approval controls for imported tokens', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeChainValue: ChainKind.ethereum,
      tokenAssetsValue: const <TrackedAssetDefinition>[
        TrackedAssetDefinition(
          id: 'ethereum:testnet:usdc',
          chain: ChainKind.ethereum,
          network: ChainNetwork.testnet,
          symbol: 'USDC',
          displayName: 'USD Coin',
          decimals: 6,
          contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
        ),
      ],
    );

    await pumpWithState(tester, state: state, child: const ApprovalsScreen());

    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Refresh allowance'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
  });

  testWidgets('nfts screen renders discovered ERC-721 holdings', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeChainValue: ChainKind.ethereum,
      nftHoldingsValue: const <NftHolding>[
        NftHolding(
          chain: ChainKind.ethereum,
          network: ChainNetwork.testnet,
          contractAddress: '0x9999999999999999999999999999999999999999',
          tokenId: '42',
          ownerAddress: '0x1111111111111111111111111111111111111111',
          updatedAt: DateTime(2026, 3, 20, 12),
          collectionName: 'Demo Collection',
          symbol: 'DEMO',
          tokenUri: 'ipfs://demo/42',
        ),
      ],
    );

    await pumpWithState(tester, state: state, child: const NftsScreen());

    expect(find.text('NFTs'), findsOneWidget);
    expect(find.text('Demo Collection'), findsOneWidget);
    expect(find.text('DEMO #42'), findsOneWidget);
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
    expect(find.textContaining('biometric unlock'), findsOneWidget);
  });

  testWidgets('clear local data exports backup before final confirmation', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
      deviceAuthAvailableValue: true,
      deviceAuthHasBiometricOptionValue: true,
    );

    await tester.pumpWidget(
      BitsendStateScope(
        notifier: state,
        child: MaterialApp(
          home: const SettingsScreen(),
          routes: <String, WidgetBuilder>{
            AppRoutes.onboardingWelcome: (_) =>
                const Scaffold(body: Text('Reset complete')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear local data'));
    await tester.pumpAndSettle();

    expect(state.authenticateDeviceCallCount, 1);
    expect(state.exportWalletBackupCallCount, 1);
    expect(state.clearLocalDataCallCount, 0);
    expect(find.text('Clear local data?'), findsOneWidget);
    expect(
      find.textContaining('A recovery backup was downloaded before reset.'),
      findsOneWidget,
    );
    expect(find.text('/tmp/bitsend-wallet-backup-test.json'), findsOneWidget);
    expect(
      find.textContaining('device-bound and will be deleted permanently'),
      findsOneWidget,
    );

    await tester.tap(find.text('I saved the backup, clear data'));
    await tester.pumpAndSettle();

    expect(state.clearLocalDataCallCount, 1);
    expect(find.text('Reset complete'), findsOneWidget);
  });

  testWidgets(
    'unlock screen blocks wallet access until biometrics are set up',
    (WidgetTester tester) async {
      final _TestBitsendAppState state = _TestBitsendAppState(
        walletValue: _wallet,
        deviceAuthAvailableValue: false,
        deviceAuthHasBiometricOptionValue: false,
        requiresBiometricSetupValue: true,
      );

      await pumpWithState(tester, state: state, child: const UnlockScreen());

      expect(find.text('Set up biometrics'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
    },
  );

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

  testWidgets('offline top up can switch to a token asset', (
    WidgetTester tester,
  ) async {
    const WalletProfile evmWallet = WalletProfile(
      chain: ChainKind.bnb,
      address: '0xfB0000000000000000000000000000000000867A',
      displayAddress: '0xfb...867a',
      seedPhrase:
          'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
      mode: WalletSetupMode.created,
    );
    const WalletProfile evmOfflineWallet = WalletProfile(
      chain: ChainKind.bnb,
      address: '0xD80000000000000000000000000000000000dB1C',
      displayAddress: '0xD8...dB1C',
      seedPhrase:
          'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
      mode: WalletSetupMode.created,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: evmWallet,
      offlineWalletValue: evmOfflineWallet,
      activeChainValue: ChainKind.bnb,
      activeNetworkValue: ChainNetwork.mainnet,
      walletSummaryValue: const WalletSummary(
        chain: ChainKind.bnb,
        network: ChainNetwork.mainnet,
        balanceSol: 0.000009,
        offlineBalanceSol: 0,
        offlineAvailableSol: 0,
        offlineWalletAddress: '0x1234567890abcdef1234567890abcdef12345678',
        readyForOffline: false,
        blockhashAge: null,
        localEndpoint: null,
      ),
      portfolioHoldingsValue: const <AssetPortfolioHolding>[
        AssetPortfolioHolding(
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          totalBalance: 0.000009,
          mainBalance: 0.000009,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId: 'bnb:mainnet:native',
          symbol: 'BNB',
          displayName: 'BNB Chain',
          assetDecimals: 18,
          isNative: true,
          mainAddress: '0xfB0000000000000000000000000000000000867A',
          protectedAddress: '0xD80000000000000000000000000000000000dB1C',
        ),
        AssetPortfolioHolding(
          chain: ChainKind.bnb,
          network: ChainNetwork.mainnet,
          totalBalance: 1.16483,
          mainBalance: 1.16483,
          protectedBalance: 0,
          spendableBalance: 0,
          reservedBalance: 0,
          assetId: 'bnb:mainnet:usdt',
          symbol: 'USDT',
          displayName: 'Tether USD',
          assetDecimals: 18,
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
          isNative: false,
          mainAddress: '0xfB0000000000000000000000000000000000867A',
          protectedAddress: '0xD80000000000000000000000000000000000dB1C',
        ),
      ],
    );

    await tester.pumpWidget(
      BitsendStateScope(
        notifier: state,
        child: const MaterialApp(home: PrepareOfflineScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline-topup-asset')), findsOneWidget);
    expect(find.text('Move BNB from Main to Offline.'), findsOneWidget);
    expect(find.text('Keep some BNB in Main for gas.'), findsNothing);

    await tester.tap(find.byKey(const Key('offline-topup-asset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USDT  ·  1.165 USDT').last);
    await tester.pumpAndSettle();

    expect(find.text('Move USDT into Offline.'), findsOneWidget);
    expect(find.text('Keep some BNB in Main for gas.'), findsOneWidget);
    expect(find.text('1.165 USDT'), findsWidgets);
  });

  testWidgets('offline page opens deposit for the selected wallet target', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      offlineWalletValue: _offlineWallet,
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
        child: MaterialApp(
          onGenerateRoute: (RouteSettings settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                if (settings.name == AppRoutes.deposit) {
                  return DepositScreen(
                    initialTarget: settings.arguments is DepositWalletTarget
                        ? settings.arguments as DepositWalletTarget
                        : null,
                  );
                }
                return const PrepareOfflineScreen();
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline-page-deposit-main')), findsOneWidget);
    expect(
      find.byKey(const Key('offline-page-deposit-offline')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('offline-page-deposit-main')));
    await tester.pumpAndSettle();

    expect(find.text('Deposit SOL'), findsOneWidget);
    expect(
      find.text('6g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1R'),
      findsOneWidget,
    );
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
    expect(find.text('Share QR code'), findsOneWidget);
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
    expect(find.text('Copy QR data'), findsOneWidget);
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

  testWidgets('send success screen uses on-chain copy for direct submits', (
    WidgetTester tester,
  ) async {
    final PendingTransfer outbound = _transfer(
      transferId: 'outgoing-online',
      direction: TransferDirection.outbound,
      status: TransferStatus.broadcastSubmitted,
      senderAddress: _wallet.address,
      receiverAddress: 'Receiver11111111111111111111111111111111',
      amountLamports: 500000000,
      transport: TransportKind.online,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      lastSentTransferValue: outbound,
    );

    await pumpWithState(tester, state: state, child: const SendSuccessScreen());

    expect(find.text('Submitted on-chain'), findsOneWidget);
    expect(find.text('Sent offline'), findsNothing);
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

  testWidgets('receive screen hides hotspot QR code until listener is live', (
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
      find.text('Start hotspot receive to show the live QR code.'),
      findsOneWidget,
    );
    expect(find.text('Copy QR data'), findsNothing);
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

  testWidgets('pending screen hides confirmed transfers', (
    WidgetTester tester,
  ) async {
    final PendingTransfer confirmed = _transfer(
      transferId: 'confirmed-1',
      direction: TransferDirection.inbound,
      status: TransferStatus.confirmed,
      senderAddress: 'Sender1111111111111111111111111111111111',
      receiverAddress: _wallet.address,
      amountLamports: 250000000,
    );
    final PendingTransfer pending = _transfer(
      transferId: 'pending-1',
      direction: TransferDirection.inbound,
      status: TransferStatus.receivedPendingBroadcast,
      senderAddress: 'Sender2222222222222222222222222222222222',
      receiverAddress: _wallet.address,
      amountLamports: 500000000,
    );
    final _TestBitsendAppState state = _TestBitsendAppState(
      inboundTransfers: <PendingTransfer>[confirmed, pending],
    );

    await pumpWithState(tester, state: state, child: const PendingScreen());

    expect(find.text('◎0.5000'), findsOneWidget);
    expect(find.text('◎0.2500'), findsNothing);
  });

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

    expect(find.text('Address only'), findsOneWidget);
    expect(find.text('Endpoint'), findsNothing);
    expect(
      find.textContaining('Send will switch to Local mode automatically'),
      findsOneWidget,
    );
  });

  testWidgets('send transport shows route and recipient sections', (
    WidgetTester tester,
  ) async {
    final _TestBitsendAppState state = _TestBitsendAppState(
      walletValue: _wallet,
      activeWalletEngineValue: WalletEngine.local,
      hasInternetValue: true,
      sendDraftValue: const SendDraft(
        walletEngine: WalletEngine.local,
        transport: TransportKind.online,
      ),
    );

    await pumpWithState(
      tester,
      state: state,
      child: const SendTransportScreen(),
    );

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Online'), findsWidgets);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets(
    'send transport shows full scanned address instead of short label',
    (WidgetTester tester) async {
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
    },
  );

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

    await pumpWithState(tester, state: state, child: const SendAmountScreen());

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

  testWidgets(
    'send review disables signing when amount exceeds spendable balance',
    (WidgetTester tester) async {
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
    },
  );

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
  TransportKind transport = TransportKind.hotspot,
  WalletEngine walletEngine = WalletEngine.local,
  String? transactionSignature,
}) {
  final DateTime now = DateTime(2026, 3, 13, 12);
  final OfflineEnvelope? envelope = transport == TransportKind.online
      ? null
      : OfflineEnvelope.create(
          transferId: transferId,
          createdAt: now,
          chain: ChainKind.solana,
          network: ChainNetwork.testnet,
          senderAddress: senderAddress,
          receiverAddress: receiverAddress,
          amountLamports: amountLamports,
          signedTransactionBase64: 'ZW5jb2RlZA==',
          transportKind: transport,
        );
  return PendingTransfer(
    transferId: transferId,
    chain: ChainKind.solana,
    network: ChainNetwork.testnet,
    walletEngine: walletEngine,
    direction: direction,
    status: status,
    amountLamports: amountLamports,
    senderAddress: senderAddress,
    receiverAddress: receiverAddress,
    transport: transport,
    createdAt: now,
    updatedAt: now,
    envelope: envelope,
    transactionSignature:
        transactionSignature ??
        '5vzWQyrGExdHJ9pQxV7j1U8QGSoK8Vw1w2h4bB2ZvFQq1n3R9Y7',
  );
}

class _TestBitsendAppState extends BitsendAppState {
  _TestBitsendAppState({
    this.bootRouteValue = AppRoutes.home,
    this.walletValue,
    this.offlineWalletValue,
    this.activeChainValue = ChainKind.ethereum,
    this.activeNetworkValue = ChainNetwork.testnet,
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
    this.requiresBiometricSetupValue = false,
    this.requiresDeviceUnlockValue = false,
    this.authenticateDeviceResultValue = true,
    this.exportWalletBackupValue = const WalletBackupExport(
      fileName: 'bitsend-wallet-backup-test.json',
      filePath: '/tmp/bitsend-wallet-backup-test.json',
    ),
    this.exportWalletBackupError,
    this.clearLocalDataError,
    this.portfolioHoldingsValue = const <AssetPortfolioHolding>[],
    this.portfolioUsdTotalValue = 0,
    double? activeScopeUsdTotalValue,
    this.accountSummariesValue = const <WalletAccountSummary>[],
    this.tokenAssetsValue = const <TrackedAssetDefinition>[],
    this.allowanceEntriesValue = const <TokenAllowanceEntry>[],
    this.nftHoldingsValue = const <NftHolding>[],
    this.swapApiKeyValue = '',
    this.hasSwapApiKeyValue = false,
    this.swapSlippageBpsValue,
    this.swapSupportedOnActiveScopeValue = false,
    this.quoteSwapHandler,
    this.executeSwapHandler,
  }) : activeScopeUsdTotalValue =
           activeScopeUsdTotalValue ?? portfolioUsdTotalValue,
       super(clock: () => DateTime(2026, 3, 13, 12));

  final String bootRouteValue;
  final WalletProfile? walletValue;
  final WalletProfile? offlineWalletValue;
  final ChainKind activeChainValue;
  final ChainNetwork activeNetworkValue;
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
  final bool requiresBiometricSetupValue;
  final bool requiresDeviceUnlockValue;
  final bool authenticateDeviceResultValue;
  final WalletBackupExport exportWalletBackupValue;
  final Object? exportWalletBackupError;
  final Object? clearLocalDataError;
  final List<AssetPortfolioHolding> portfolioHoldingsValue;
  final double? portfolioUsdTotalValue;
  final double? activeScopeUsdTotalValue;
  final List<WalletAccountSummary> accountSummariesValue;
  final List<TrackedAssetDefinition> tokenAssetsValue;
  final List<TokenAllowanceEntry> allowanceEntriesValue;
  final List<NftHolding> nftHoldingsValue;
  final String swapApiKeyValue;
  final bool hasSwapApiKeyValue;
  final int? swapSlippageBpsValue;
  final bool swapSupportedOnActiveScopeValue;
  final Future<SwapQuote> Function({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  })? quoteSwapHandler;
  final Future<PendingTransfer> Function({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  })? executeSwapHandler;
  int authenticateDeviceCallCount = 0;
  int exportWalletBackupCallCount = 0;
  int clearLocalDataCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  String get bootRoute => bootRouteValue;

  @override
  WalletProfile? get wallet => walletValue;

  @override
  WalletProfile? get offlineWallet => offlineWalletValue;

  @override
  ChainKind get activeChain => activeChainValue;

  @override
  ChainNetwork get activeNetwork => activeNetworkValue;

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
  bool get deviceAuthHasBiometricOption => deviceAuthHasBiometricOptionValue;

  @override
  bool get requiresBiometricSetup => requiresBiometricSetupValue;

  @override
  bool get requiresDeviceUnlock => requiresDeviceUnlockValue;

  @override
  String get deviceUnlockMethodLabel => 'biometric unlock';

  @override
  Future<bool> authenticateDevice({
    String? reason,
    bool forcePrompt = false,
  }) async {
    authenticateDeviceCallCount += 1;
    return authenticateDeviceResultValue;
  }

  @override
  Future<WalletBackupExport> exportWalletBackup() async {
    exportWalletBackupCallCount += 1;
    if (exportWalletBackupError != null) {
      throw exportWalletBackupError!;
    }
    return exportWalletBackupValue;
  }

  @override
  Future<void> clearLocalData() async {
    clearLocalDataCallCount += 1;
    if (clearLocalDataError != null) {
      throw clearLocalDataError!;
    }
  }

  @override
  Future<bool> openSystemSettings() async => true;

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
  double get offlineSpendableBalanceSol =>
      walletSummaryValue.offlineAvailableSol;

  @override
  WalletSummary get walletSummary => walletSummaryValue;

  @override
  List<AssetPortfolioHolding> get portfolioHoldings => portfolioHoldingsValue;

  @override
  List<TrackedAssetDefinition> get tokenAssetsForActiveScope =>
      tokenAssetsValue;

  @override
  List<TokenAllowanceEntry> get allowanceEntriesForActiveScope =>
      allowanceEntriesValue;

  @override
  List<NftHolding> get nftHoldingsForActiveScope => nftHoldingsValue;

  @override
  double? get portfolioUsdTotal => portfolioUsdTotalValue;

  @override
  double? get activeScopeUsdTotal => activeScopeUsdTotalValue;

  @override
  String get swapApiKey => swapApiKeyValue;

  @override
  bool get hasSwapApiKey => hasSwapApiKeyValue;

  @override
  int? get swapSlippageBps => swapSlippageBpsValue;

  @override
  bool get swapSupportedOnActiveScope => swapSupportedOnActiveScopeValue;

  @override
  Future<void> setSwapApiKey(String value) async {}

  @override
  Future<void> setSwapSlippageBps(int? value) async {}

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
  List<PendingTransfer> get pendingTransfers {
    return <PendingTransfer>[
      ...inboundTransfers,
      ...outboundTransfers,
    ]
        .where((PendingTransfer transfer) => transfer.isVisibleInPendingQueue)
        .toList(growable: false);
  }

  @override
  List<PendingTransfer> recentActivity() {
    final List<PendingTransfer> sorted = <PendingTransfer>[
      ...inboundTransfers,
      ...outboundTransfers,
    ]..sort(
      (PendingTransfer a, PendingTransfer b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );
    return sorted;
  }

  @override
  List<PendingTransfer> transfersFor(TransferDirection direction) {
    final List<PendingTransfer> transfers = direction == TransferDirection.inbound
        ? inboundTransfers
        : outboundTransfers;
    return transfers
        .where((PendingTransfer transfer) => transfer.isVisibleInPendingQueue)
        .toList(growable: false);
  }

  @override
  PendingTransfer? transferById(String transferId) => transferMap[transferId];

  @override
  List<TransferTimelineState> timelineFor(PendingTransfer transfer) =>
      timelineValue;

  @override
  String? validateSendAmount(double amountSol) =>
      validateSendAmountHandler?.call(amountSol);

  @override
  Future<void> refreshPortfolioBalances() async {}

  @override
  Future<SwapQuote> quoteSwap({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  }) async {
    if (quoteSwapHandler == null) {
      throw UnimplementedError('quoteSwapHandler not provided');
    }
    return quoteSwapHandler!(
      sellAssetId: sellAssetId,
      buyAssetId: buyAssetId,
      sellAmount: sellAmount,
    );
  }

  @override
  Future<PendingTransfer> executeSwap({
    required String sellAssetId,
    required String buyAssetId,
    required double sellAmount,
  }) async {
    if (executeSwapHandler == null) {
      throw UnimplementedError('executeSwapHandler not provided');
    }
    return executeSwapHandler!(
      sellAssetId: sellAssetId,
      buyAssetId: buyAssetId,
      sellAmount: sellAmount,
    );
  }

  @override
  Future<List<WalletAccountSummary>>
  loadAccountSummariesForActiveChain() async {
    return accountSummariesValue;
  }

  @override
  Future<void> refreshNftHoldings() async {}
}
