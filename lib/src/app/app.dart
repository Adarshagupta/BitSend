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
  static const String unlock = '/unlock';
  static const String home = '/home';
  static const String deposit = '/deposit';
  static const String prepare = '/prepare';
  static const String sendTransport = '/send/transport';
  static const String sendAmount = '/send/amount';
  static const String sendReview = '/send/review';
  static const String sendRelay = '/send/relay';
  static const String sendProgress = '/send/progress';
  static const String sendSuccess = '/send/success';
  static const String receiveListen = '/receive/listen';
  static const String receiveResult = '/receive/result';
  static const String pending = '/pending';
  static const String settings = '/settings';

  static String transferDetail(String transferId) => '/transfer/$transferId';
}

class BitsendApp extends StatefulWidget {
  const BitsendApp({super.key, required this.appState});

  final BitsendAppState appState;

  @override
  State<BitsendApp> createState() => _BitsendAppState();
}

class _BitsendAppState extends State<BitsendApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _TrackingNavigatorObserver _navigatorObserver =
      _TrackingNavigatorObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.appState.lockWalletForSession();
      return;
    }
    if (state != AppLifecycleState.resumed) {
      return;
    }
    if (!widget.appState.requiresDeviceUnlock ||
        _navigatorObserver.currentRouteName == AppRoutes.unlock) {
      return;
    }
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamed(AppRoutes.unlock);
  }

  @override
  Widget build(BuildContext context) {
    return BitsendStateScope(
      notifier: widget.appState,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        navigatorObservers: <NavigatorObserver>[_navigatorObserver],
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
      AppRoutes.unlock => _page(settings, const UnlockScreen()),
      AppRoutes.home => _page(settings, const HomeDashboardScreen()),
      AppRoutes.deposit => _page(settings, const DepositScreen()),
      AppRoutes.prepare => _page(settings, const PrepareOfflineScreen()),
      AppRoutes.sendTransport => _page(settings, const SendTransportScreen()),
      AppRoutes.sendAmount => _page(settings, const SendAmountScreen()),
      AppRoutes.sendReview => _page(settings, const SendReviewScreen()),
      AppRoutes.sendRelay => _page(settings, const SendRelayScreen()),
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

class _TrackingNavigatorObserver extends NavigatorObserver {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name;
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRouteName = newRoute?.settings.name;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
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
