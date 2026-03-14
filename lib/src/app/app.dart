import 'package:flutter/material.dart';

import '../screens/screens.dart';
import '../state/app_state.dart';
import 'theme.dart';

abstract final class AppRoutes {
  static const String boot = '/boot';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingWallet = '/onboarding/wallet';
  static const String onboardingFund = '/onboarding/fund';
  static const String onboardingPrepare = '/onboarding/prepare';
  static const String home = '/home';
  static const String deposit = '/deposit';
  static const String prepare = '/prepare';
  static const String sendTransport = '/send/transport';
  static const String sendAmount = '/send/amount';
  static const String sendReview = '/send/review';
  static const String sendProgress = '/send/progress';
  static const String sendSuccess = '/send/success';
  static const String receiveListen = '/receive/listen';
  static const String receiveResult = '/receive/result';
  static const String pending = '/pending';
  static const String settings = '/settings';

  static String transferDetail(String transferId) => '/transfer/$transferId';
}

class BitsendApp extends StatelessWidget {
  const BitsendApp({super.key, required this.appState});

  final BitsendAppState appState;

  @override
  Widget build(BuildContext context) {
    return BitsendStateScope(
      notifier: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'bitsend',
        theme: buildBitsendTheme(),
        initialRoute: AppRoutes.boot,
        onGenerateRoute: (RouteSettings settings) => _routeFor(settings),
      ),
    );
  }

  Route<dynamic> _routeFor(RouteSettings settings) {
    final String name = settings.name ?? AppRoutes.boot;
    if (name.startsWith('/transfer/')) {
      final String transferId = name.replaceFirst('/transfer/', '');
      return _page(settings, TransferDetailScreen(transferId: transferId));
    }

    return switch (name) {
      AppRoutes.boot => _page(settings, const BootScreen()),
      AppRoutes.onboardingWelcome => _page(settings, const WelcomeScreen()),
      AppRoutes.onboardingWallet => _page(settings, const WalletSetupScreen()),
      AppRoutes.onboardingFund => _page(settings, const FundWalletScreen()),
      AppRoutes.onboardingPrepare => _page(
        settings,
        const OnboardingPrepareScreen(),
      ),
      AppRoutes.home => _page(settings, const HomeDashboardScreen()),
      AppRoutes.deposit => _page(settings, const DepositScreen()),
      AppRoutes.prepare => _page(settings, const PrepareOfflineScreen()),
      AppRoutes.sendTransport => _page(settings, const SendTransportScreen()),
      AppRoutes.sendAmount => _page(settings, const SendAmountScreen()),
      AppRoutes.sendReview => _page(settings, const SendReviewScreen()),
      AppRoutes.sendProgress => _page(settings, const SendProgressScreen()),
      AppRoutes.sendSuccess => _page(settings, const SendSuccessScreen()),
      AppRoutes.receiveListen => _page(settings, const ReceiveListenScreen()),
      AppRoutes.receiveResult => _page(
        settings,
        ReceiveResultScreen(
          transferId: settings.arguments as String?,
        ),
      ),
      AppRoutes.pending => _page(settings, const PendingScreen()),
      AppRoutes.settings => _page(settings, const SettingsScreen()),
      _ => _page(settings, const HomeDashboardScreen()),
    };
  }

  MaterialPageRoute<dynamic> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (BuildContext context) => child,
    );
  }
}

class BitsendStateScope extends InheritedNotifier<BitsendAppState> {
  const BitsendStateScope({
    super.key,
    required BitsendAppState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static BitsendAppState of(BuildContext context) {
    final BitsendStateScope? scope = context
        .dependOnInheritedWidgetOfExactType<BitsendStateScope>();
    assert(scope != null, 'BitsendStateScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
